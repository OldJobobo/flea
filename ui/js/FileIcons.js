.pragma library

function selection(value) {
    if (value === "system" || value === "adaptive") return value
    if (typeof value !== "string" || value.indexOf("theme:") !== 0) return "builtin"
    var name = value.slice(6)
    var bytes
    try { bytes = encodeURIComponent(name).replace(/%[0-9a-f]{2}/gi, "_").length } catch (_) { return "builtin" }
    return bytes > 0 && bytes <= 128 && name.trim() === name && name !== "." && name !== ".." && !/[\x00-\x1f\x7f-\x9f/\\]/.test(name) ? value : "builtin"
}

function request(row, size) {
    if (!row) return null
    var name = row.i || (row.d ? "folder" : "text-x-generic")
    if (typeof name !== "string" || !/^[a-zA-Z0-9_.-]{1,128}$/.test(name) || name === "." || name === "..") return null
    return { name: name, size: Math.max(1, Math.min(512, Math.ceil(size) || 24)) }
}

function key(icon) { return icon.size + ":" + icon.name }

function choices(themes, current) {
    var ids = ["builtin", "adaptive", "system"], labels = ["Interface icons", "Adaptive / theme palette", "System / Omarchy"]
    for (var i = 0; i < (themes || []).length; i++) {
        var theme = themes[i]
        if (selection(theme.id) !== theme.id || ids.indexOf(theme.id) >= 0) continue
        ids.push(theme.id); labels.push(theme.label || theme.id.slice(6))
    }
    var selected = selection(current)
    if (ids.indexOf(selected) < 0) {
        ids.push(selected); labels.push(selected.slice(6) + " (not listed)")
    }
    return { ids: ids, labels: labels, selected: selected }
}
