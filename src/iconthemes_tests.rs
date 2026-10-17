use super::*;
use crate::backend::testdir::TestDir;

fn put(d: &TestDir, path: &str, body: &str) -> PathBuf {
    let path = d.join(path);
    d.assert_contains(&path);
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    std::fs::write(&path, body).unwrap();
    path
}

const HEADER: &str = "[Icon Theme]\nName=Test icons\nDirectories=24/places,48/places,scalable/mimetypes\n[24/places]\nSize=24\nType=Fixed\n[48/places]\nSize=48\nType=Fixed\n[scalable/mimetypes]\nSize=48\nMinSize=16\nMaxSize=512\nType=Scalable\n";

#[test]
fn names_and_settings_cannot_be_paths_or_control_sequences() {
    for name in ["Papirus-Dark", "My Icons", "Yaru", "日本語"] { assert!(valid_name(name)); }
    for name in ["", ".", "..", "../icons", "/icons", "a\\b", "a\0b", " x", "x\n"] { assert!(!valid_name(name)); }
    for selection in ["builtin", "adaptive", "system", "theme:Papirus", "theme:My Icons"] { assert!(valid_selection(selection)); }
    for selection in ["Papirus", "theme:", "theme:../../x", "invalid"] { assert!(!valid_selection(selection)); }
    assert!(valid_icon("application-vnd.oasis.opendocument.text"));
    assert!(!valid_icon("folder.svg/../../x"));
}

#[test]
fn resolution_chooses_nearest_size_and_only_requested_assets() {
    let d = TestDir::new("desktopicons-size");
    put(&d, "icons/Test/index.theme", HEADER);
    let small = put(&d, "icons/Test/24/places/folder.png", "small");
    let large = put(&d, "icons/Test/48/places/folder.svg", "large");
    let svg = put(&d, "icons/Test/scalable/mimetypes/text-x-generic.svg", "scalable");
    let mut store = Store::new(vec![d.join("icons")]);
    assert_eq!(store.resolve("Test", "folder", 23), Some(small));
    assert_eq!(store.resolve("Test", "folder", 64), Some(large));
    assert_eq!(store.resolve("Test", "text-x-generic", 160), Some(svg));
    assert_eq!(store.resolve("Test", "absent", 24), None);
    assert_eq!(store.cache.len(), 4, "distinct names/sizes, never entries in the viewed directory");
}

#[test]
fn user_roots_override_system_art_but_can_share_its_index() {
    let d = TestDir::new("desktopicons-roots");
    put(&d, "system/Test/index.theme", HEADER);
    put(&d, "system/Test/24/places/folder.png", "system");
    let user = put(&d, "user/Test/24/places/folder.png", "user");
    let mut store = Store::new(vec![d.join("user"), d.join("system"), d.join("user")]);
    assert_eq!(store.roots.len(), 2);
    assert_eq!(store.resolve("Test", "folder", 24), Some(user));
}

#[test]
fn inheritance_uses_child_before_parent_and_handles_cycles() {
    let d = TestDir::new("desktopicons-inherit");
    put(&d, "icons/Child/index.theme", &HEADER.replace("Name=Test icons", "Name=Child\nInherits=Parent"));
    put(&d, "icons/Parent/index.theme", &HEADER.replace("Name=Test icons", "Name=Parent\nInherits=Child"));
    let child = put(&d, "icons/Child/48/places/folder.svg", "child");
    put(&d, "icons/Parent/24/places/folder.png", "parent");
    let parent = put(&d, "icons/Parent/scalable/mimetypes/image-x-generic.svg", "parent image");
    let mut store = Store::new(vec![d.join("icons")]);
    assert_eq!(store.resolve("Child", "folder", 24), Some(child));
    assert_eq!(store.resolve("Child", "image-x-generic", 24), Some(parent));
    assert_eq!(store.resolve("Child", "absent", 24), None);
    assert!(store.indexes.len() <= 3);
}

#[test]
fn hicolor_is_an_implicit_fallback_and_hidden_themes_are_not_choices() {
    let d = TestDir::new("desktopicons-hicolor");
    put(&d, "icons/hicolor/index.theme", &HEADER.replace("Name=Test icons", "Name=Fallback\nHidden=true"));
    put(&d, "icons/Shown/index.theme", HEADER);
    let fallback = put(&d, "icons/hicolor/24/places/folder.png", "fallback");
    let mut store = Store::new(vec![d.join("icons")]);
    assert_eq!(store.catalog(), vec![("Shown".into(), "Test icons".into())]);
    assert_eq!(store.resolve("Missing", "folder", 24), Some(fallback));
}

#[test]
fn theme_switch_drops_positive_and_negative_results() {
    let d = TestDir::new("desktopicons-switch");
    for name in ["Red", "Blue"] { put(&d, &format!("icons/{name}/index.theme"), HEADER); }
    let red = put(&d, "icons/Red/24/places/folder.svg", "red");
    let blue = put(&d, "icons/Blue/24/places/folder.svg", "blue");
    let mut store = Store::new(vec![d.join("icons")]);
    assert_eq!(store.resolve("Red", "folder", 24), Some(red.clone()));
    assert_eq!(store.resolve("Blue", "folder", 24), Some(blue));
    assert_eq!(store.resolve("Red", "folder", 24), Some(red));
    assert_eq!(store.cache.len(), 1);
}

#[test]
fn scaled_and_threshold_directories_have_their_real_pixel_bounds() {
    let data = index::Index::parse("[Icon Theme]\nDirectories=scaled,threshold\n[scaled]\nSize=24\nScale=2\nType=Fixed\n[threshold]\nSize=24\nThreshold=3\n").unwrap();
    assert_eq!(data.dirs[0].distance(48), 0);
    assert_eq!(data.dirs[0].distance(24), 24);
    assert_eq!(data.dirs[1].distance(21), 0);
    assert_eq!(data.dirs[1].distance(28), 1);
}

#[test]
fn malformed_directories_and_inheritance_are_never_followed() {
    let text = "[Icon Theme]\nInherits=../escape,Good,/absolute\nDirectories=../escape,/absolute,ok\n[../escape]\nSize=24\n[/absolute]\nSize=24\n[ok]\nSize=0\n";
    let data = index::Index::parse(text).unwrap();
    assert!(data.dirs.is_empty());
    assert_eq!(data.inherits, ["Good"]);
}

#[test]
fn regular_file_reader_refuses_directories_invalid_utf8_and_large_metadata() {
    let d = TestDir::new("desktopicons-metadata");
    assert!(index::Index::load(d.path()).is_none());
    let path = put(&d, "invalid", "");
    std::fs::write(&path, [255u8]).unwrap();
    assert!(index::Index::load(&path).is_none());
    std::fs::write(&path, vec![b'x'; 1024 * 1024 + 1]).unwrap();
    assert!(index::Index::load(&path).is_none());
}

#[test]
fn file_icon_selection_persists_without_overwriting_interface_icons() {
    use crate::jsondoc::{parse, Json};
    let current = crate::uistate::from_file(r#"{"display":{"iconSet":"lucide"}}"#);
    for value in ["builtin", "adaptive", "system", "theme:Papirus-Dark", "theme:My Icons"] {
        let patch = parse(&format!(r#"{{"display":{{"fileIconTheme":"{value}"}}}}"#)).unwrap();
        let next = crate::uistate::patched(&current, &patch).unwrap();
        let display = next.get("display").unwrap();
        assert_eq!(display.get("fileIconTheme").and_then(Json::as_str), Some(value));
        assert_eq!(display.get("iconSet").and_then(Json::as_str), Some("lucide"));
    }
    for value in [r#""theme:../escape""#, r#""unknown""#, "null", "true", "12"] {
        let text = format!(r#"{{"display":{{"fileIconTheme":{value}}}}}"#);
        assert!(crate::uistate::patched(&current, &parse(&text).unwrap()).is_err());
        let repaired = crate::uistate::from_file(&text);
        assert_eq!(repaired.get("display").unwrap().get("fileIconTheme").and_then(Json::as_str), Some("builtin"));
    }
}

#[test]
fn cache_has_a_fixed_bound_and_discovery_does_not_expand_it() {
    let mut store = Store::new(vec![]);
    for n in 0..600 { assert!(store.resolve("Missing", &format!("type-{n}"), 24).is_none()); }
    assert!(store.cache.len() <= 512);
    let before = store.cache.len();
    assert!(store.catalog().is_empty());
    assert_eq!(store.cache.len(), before);
}
