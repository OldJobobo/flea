.pragma library

// Personal bundle facts and routes; package/default actions deliberately stay outside Tick.
function rows(state) {
    var facts = state.about || {}
    return [
        { kind: "hero", label: "Tick", value: "A personal Flea fork for Omarchy" },
        { kind: "fact", label: "Flea engine", value: facts.version || "Not reported" },
        { kind: "fact", label: "Build", value: "@COMMIT@" },
        { kind: "fact", label: "Installed from", value: "Tick personal bundle" },
        { kind: "fact", label: "License", value: "MIT; Flea © 2026 GM" },
        { kind: "group", label: "Updates" },
        { kind: "hint", label: "Build and promote Tick with personal/tick-dev. Packaged Flea is updated separately." },
        { kind: "group", label: "This computer" },
        { kind: "fact", label: "File manager", glyph: "folder", elide: "head", value: facts.handler || "Not reported" },
        { kind: "hint", label: "Desktop routing is managed by personal/tick-dev desktop, not the stock Flea default switch." },
        { kind: "action", id: "keyboardSheet", label: "Keyboard sheet", glyph: "keyboard", value: "?" },
        { kind: "action", id: "reportIssue", label: "Tick source", value: "GitHub", url: "https://github.com/OldJobobo/tick" },
        { kind: "action", id: "support", label: "Support Flea upstream", value: "GitHub Sponsors", url: "https://github.com/sponsors/thisisgm" }
    ]
}

// Kept for the settings module's existing interface; no package updater is exposed.
function updateRows(update, data) { return [] }
function autoCheck(data) { return false }
