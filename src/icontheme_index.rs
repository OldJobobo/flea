//! Bounded freedesktop index.theme metadata; no icon-directory enumeration.
use crate::backend::regfile::open_regular;
use std::collections::HashMap;
use std::io::Read;
use std::path::{Component, Path};

const MAX_INDEX: u64 = 1024 * 1024;

pub fn read(path: &Path) -> Option<String> {
    let mut text = String::new();
    open_regular(path)?.take(MAX_INDEX + 1).read_to_string(&mut text).ok()?;
    (text.len() <= MAX_INDEX as usize).then_some(text)
}

#[derive(Clone)]
pub struct Directory {
    pub path: String,
    low: u32,
    high: u32,
}

impl Directory {
    pub fn distance(&self, size: u32) -> u32 {
        if size < self.low { self.low - size } else { size.saturating_sub(self.high) }
    }
}

#[derive(Clone)]
pub struct Index {
    pub label: String,
    pub hidden: bool,
    pub inherits: Vec<String>,
    pub dirs: Vec<Directory>,
}

pub fn relative(path: &str) -> bool {
    !path.is_empty() && path.len() <= 256 && !path.contains('\\')
        && Path::new(path).components().all(|c| matches!(c, Component::Normal(_)))
}

impl Index {
    pub fn load(path: &Path) -> Option<Self> {
        Self::parse(&read(path)?)
    }

    pub fn parse(text: &str) -> Option<Self> {
        let mut sections: HashMap<&str, HashMap<&str, &str>> = HashMap::new();
        let mut section = "";
        for line in text.lines() {
            let line = line.trim();
            if line.starts_with('#') || line.starts_with(';') { continue; }
            if let Some(name) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
                section = name;
            } else if let Some((key, value)) = line.split_once('=') {
                sections.entry(section).or_default().insert(key.trim(), value.trim());
            }
        }
        let header = sections.get("Icon Theme")?;
        let label = header.get("Name").copied().unwrap_or("").chars().take(128).collect();
        let inherits = header.get("Inherits").unwrap_or(&"").split(',').map(str::trim)
            .filter(|s| super::valid_name(s)).take(32).map(str::to_owned).collect();
        let mut dirs = Vec::new();
        for name in ["Directories", "ScaledDirectories"].iter()
            .flat_map(|key| header.get(key).unwrap_or(&"").split(','))
            .map(str::trim).filter(|s| relative(s)).take(512)
        {
            let Some(values) = sections.get(name) else { continue };
            let number = |key, fallback| values.get(key).and_then(|s| s.parse::<u32>().ok())
                .filter(|v| (1..=4096).contains(v)).unwrap_or(fallback);
            let size = number("Size", 0);
            if size == 0 { continue; }
            let scale = number("Scale", 1).min(8);
            let (low, high) = match values.get("Type").copied().unwrap_or("Threshold") {
                "Scalable" => (number("MinSize", size), number("MaxSize", size)),
                "Fixed" => (size, size),
                "Threshold" => {
                    let threshold = values.get("Threshold").and_then(|v| v.parse::<u32>().ok()).unwrap_or(2).min(4096);
                    (size.saturating_sub(threshold), size + threshold)
                }
                _ => continue,
            };
            if low > high { continue; }
            if !dirs.iter().any(|d: &Directory| d.path == name) {
                dirs.push(Directory { path: name.to_owned(), low: low * scale, high: high * scale });
            }
        }
        Some(Self { label, hidden: header.get("Hidden").is_some_and(|v| *v == "true"), inherits, dirs })
    }
}
