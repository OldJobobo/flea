use crate::jsondoc::{self, Json};
use crate::uistate;

fn selected(value: &Json) -> Option<bool> {
    value.get("display").and_then(|d| d.get("semanticColors")).and_then(Json::as_bool)
}

#[test]
fn semantic_colors_default_off_validate_and_preserve_siblings() {
    let current = uistate::from_file(r#"{"display":{"iconSet":"feather","textSize":{"mode":16}}}"#);
    assert_eq!(selected(&current), Some(false));
    for enabled in [true, false] {
        let text = format!(r#"{{"display":{{"semanticColors":{enabled}}}}}"#);
        let patch = jsondoc::parse(&text).unwrap();
        let next = uistate::patched(&current, &patch).unwrap();
        assert_eq!(selected(&next), Some(enabled));
        let display = next.get("display").unwrap();
        assert_eq!(display.get("iconSet").and_then(Json::as_str), Some("feather"));
        assert_eq!(display.get("textSize"), current.get("display").unwrap().get("textSize"));
        assert_eq!(selected(&uistate::from_file(&jsondoc::render(&next))), Some(enabled));
    }
    for bad in ["null", "1", "[]", "{}", r#""true""#] {
        let text = format!(r#"{{"display":{{"semanticColors":{bad}}}}}"#);
        let patch = jsondoc::parse(&text).unwrap();
        assert!(uistate::patched(&current, &patch).unwrap_err().contains("display.semanticColors"));
        assert_eq!(selected(&uistate::from_file(&text)), Some(false));
    }
}
