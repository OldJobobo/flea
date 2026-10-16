//! Lazy JSON-lines worker used only by DesktopIcons.qml, not the listing protocol.
use super::{system_theme, valid_selection, Store};
use crate::json::escape;
use crate::jsondoc::{self, Json};
use std::io::{self, BufRead, Read, Write};

const MAX_LINE: u64 = 65536;

pub fn run() -> i32 {
    let mut store = Store::from_env();
    match serve(io::stdin().lock(), &mut io::stdout().lock(), &mut store) {
        Ok(()) => 0,
        Err(error) => { eprintln!("flea: desktop icon worker: {error}"); 2 }
    }
}

fn serve<R: BufRead, W: Write>(mut input: R, out: &mut W, store: &mut Store) -> io::Result<()> {
    loop {
        let mut line = String::new();
        if Read::take(&mut input, MAX_LINE + 1).read_line(&mut line)? == 0 { return Ok(()); }
        if line.len() > MAX_LINE as usize {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "request exceeds 64 KiB"));
        }
        let reply = jsondoc::parse(&line).ok().and_then(|request| answer(store, &request))
            .unwrap_or_else(|| "{\"error\":\"Invalid desktop icon request\"}".into());
        writeln!(out, "{reply}")?;
        out.flush()?;
    }
}

fn answer(store: &mut Store, request: &Json) -> Option<String> {
    let id = request.get("id")?.as_f64()?;
    if !id.is_finite() || id < 0.0 || id.fract() != 0.0 || id > 1_000_000_000.0 { return None; }
    if request.get("c")?.as_str()? == "catalog" {
        *store = Store::from_env();
        let themes: Vec<_> = store.catalog().into_iter().map(|(name, label)| {
            format!("{{\"id\":\"theme:{}\",\"label\":\"{}\"}}", escape(&name), escape(&label))
        }).collect();
        return Some(format!("{{\"id\":{id},\"c\":\"catalog\",\"system\":\"{}\",\"themes\":[{}]}}", escape(&system_theme()), themes.join(",")));
    }
    if request.get("c")?.as_str()? != "icons" { return None; }
    let selection = request.get("theme")?.as_str()?;
    if !valid_selection(selection) || selection == "builtin" { return None; }
    let theme = if selection == "system" { system_theme() } else { selection.strip_prefix("theme:")?.into() };
    let icons = request.get("icons")?.as_array()?;
    if icons.len() > 256 { return None; }
    let mut results = Vec::new();
    for icon in icons {
        let name = icon.get("name")?.as_str()?;
        let size = icon.get("size")?.as_f64()?;
        if !super::valid_icon(name) || !(1.0..=512.0).contains(&size) || size.fract() != 0.0 { return None; }
        let path = store.resolve(&theme, name, size as u32).and_then(|p| p.into_os_string().into_string().ok()).unwrap_or_default();
        results.push(format!("{{\"name\":\"{}\",\"size\":{size},\"path\":\"{}\"}}", escape(name), escape(&path)));
    }
    Some(format!("{{\"id\":{id},\"c\":\"icons\",\"theme\":\"{}\",\"icons\":[{}]}}", escape(selection), results.join(",")))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn protocol_refuses_malformed_and_oversized_work_without_leaving_the_stream() {
        let mut store = Store::new(vec![]);
        let input = b"bad json\n{\"id\":1,\"c\":\"icons\",\"theme\":\"theme:../bad\",\"icons\":[]}\n{\"id\":2,\"c\":\"icons\",\"theme\":\"theme:Missing\",\"icons\":[]}\n";
        let mut out = Vec::new();
        serve(&input[..], &mut out, &mut store).unwrap();
        let text = String::from_utf8(out).unwrap();
        assert_eq!(text.lines().count(), 3);
        assert_eq!(text.matches("Invalid desktop icon request").count(), 2);
        assert!(text.contains("\"id\":2"));
        assert!(serve(&vec![b'x'; MAX_LINE as usize + 1][..], &mut Vec::new(), &mut store).is_err());
    }
    #[test]
    fn icon_batches_validate_every_name_size_and_batch_bound() {
        let mut store = Store::new(vec![]);
        for icon in [r#"{"name":"../file","size":24}"#, r#"{"name":"folder","size":0}"#, r#"{"name":"folder","size":2.5}"#] {
            let request = jsondoc::parse(&format!(r#"{{"id":1,"c":"icons","theme":"system","icons":[{icon}]}}"#)).unwrap();
            assert!(answer(&mut store, &request).is_none());
        }
        let items = vec![r#"{"name":"folder","size":24}"#; 257].join(",");
        let request = jsondoc::parse(&format!(r#"{{"id":1,"c":"icons","theme":"system","icons":[{items}]}}"#)).unwrap();
        assert!(answer(&mut store, &request).is_none());
    }
}
