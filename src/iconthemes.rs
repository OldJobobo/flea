//! Installed desktop icon themes, independent of Qt's process-wide application icon theme.
#[path = "icontheme_index.rs"]
mod index;
#[path = "icontheme_cli.rs"]
pub mod cli;

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

pub fn valid_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 128 && name != "." && name != ".."
        && name.trim() == name && !name.chars().any(|c| c.is_control() || c == '/' || c == '\\')
}

pub fn valid_selection(value: &str) -> bool {
    matches!(value, "builtin" | "adaptive" | "system") || value.strip_prefix("theme:").is_some_and(valid_name)
}

pub fn valid_icon(name: &str) -> bool {
    valid_name(name) && name.bytes().all(|c| c.is_ascii_alphanumeric() || b"-_.".contains(&c))
}

pub struct Store {
    roots: Vec<PathBuf>,
    indexes: HashMap<String, Option<index::Index>>,
    cache: HashMap<(String, u32), Option<PathBuf>>,
    selected: String,
}

impl Store {
    pub fn from_env() -> Self {
        let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        let data = std::env::var_os("XDG_DATA_HOME").filter(|p| Path::new(p).is_absolute()).map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/share"));
        let mut roots = vec![home.join(".icons"), data.join("icons")];
        let system = std::env::var_os("XDG_DATA_DIRS").filter(|p| !p.is_empty())
            .unwrap_or_else(|| "/usr/local/share:/usr/share".into());
        roots.extend(std::env::split_paths(&system).take(16).map(|p| p.join("icons")));
        Self::new(roots)
    }

    pub fn new(roots: Vec<PathBuf>) -> Self {
        let mut unique = Vec::new();
        for root in roots.into_iter().filter(|p| p.is_absolute()).take(18) {
            if !unique.contains(&root) { unique.push(root); }
        }
        Self { roots: unique, indexes: HashMap::new(), cache: HashMap::new(), selected: String::new() }
    }

    // Only theme roots and index.theme metadata are listed; never a user's files or icon assets.
    pub fn catalog(&self) -> Vec<(String, String)> {
        let mut names = HashSet::new();
        for root in &self.roots {
            if let Ok(entries) = std::fs::read_dir(root) {
                for entry in entries.take(4096).flatten() {
                    if names.len() >= 1024 { break; }
                    if let Some(name) = entry.file_name().to_str().filter(|s| valid_name(s)) {
                        names.insert(name.to_owned());
                    }
                }
            }
        }
        let mut names: Vec<_> = names.into_iter().collect();
        names.sort();
        names.into_iter().filter_map(|name| {
            let data = self.load(&name)?;
            (!data.hidden && !data.dirs.is_empty()).then(|| {
                let label = if data.label.is_empty() { name.clone() } else { data.label };
                (name, label)
            })
        }).take(256).collect()
    }

    fn load(&self, name: &str) -> Option<index::Index> {
        self.roots.iter().find_map(|root| index::Index::load(&root.join(name).join("index.theme")))
    }

    fn chain(&mut self, name: &str, visited: &mut Vec<String>) {
        if visited.len() >= 32 || visited.iter().any(|n| n == name) || !valid_name(name) { return; }
        visited.push(name.to_owned());
        if !self.indexes.contains_key(name) {
            self.indexes.insert(name.to_owned(), self.load(name));
        }
        let parents = self.indexes.get(name).and_then(|i| i.as_ref()).map(|i| i.inherits.clone()).unwrap_or_default();
        for parent in parents { self.chain(&parent, visited); }
    }

    pub fn resolve(&mut self, theme: &str, name: &str, size: u32) -> Option<PathBuf> {
        if !valid_name(theme) || !valid_icon(name) || !(1..=512).contains(&size) { return None; }
        if self.selected != theme {
            self.selected = theme.to_owned(); self.indexes.clear(); self.cache.clear();
        }
        let key = (name.to_owned(), size);
        if let Some(answer) = self.cache.get(&key) { return answer.clone(); }
        let mut chain = Vec::new();
        self.chain(theme, &mut chain);
        // hicolor is the specification's final implicit parent, even for an incomplete theme.
        self.chain("hicolor", &mut chain);
        let result = chain.iter().find_map(|theme| self.in_theme(theme, name, size));
        if self.cache.len() >= 512 { self.cache.clear(); }
        self.cache.insert(key, result.clone());
        result
    }

    fn in_theme(&self, theme: &str, name: &str, size: u32) -> Option<PathBuf> {
        let data = self.indexes.get(theme)?.as_ref()?;
        let mut dirs: Vec<_> = data.dirs.iter().collect();
        dirs.sort_by_key(|d| d.distance(size));
        for dir in dirs {
            for root in &self.roots {
                for ext in ["png", "svg", "xpm"] {
                    let file = root.join(theme).join(&dir.path).join(format!("{name}.{ext}"));
                    if file.is_file() { return Some(file); }
                }
            }
        }
        None
    }
}

pub fn system_theme() -> String {
    let exported = std::env::var_os("QS_ICON_THEME").and_then(|v| v.into_string().ok()).filter(|s| valid_name(s));
    let path = Path::new(&std::env::var_os("HOME").unwrap_or_default()).join(".local/state/omarchy/current/theme/icons.theme");
    let omarchy = index::read(&path).map(|s| s.trim().to_owned()).filter(|s| valid_name(s));
    // A launcher-generated QS_ICON_THEME is a startup snapshot, not an operator override.
    let generated = std::env::var_os(crate::gui::THEME_MARKER).as_deref() == Some(std::ffi::OsStr::new("gtk3"));
    (if generated { omarchy.or(exported) } else { exported.or(omarchy) }).unwrap_or_else(|| "hicolor".into())
}

#[cfg(test)]
#[path = "iconthemes_tests.rs"]
mod tests;
