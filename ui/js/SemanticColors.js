.pragma library
.import "Contrast.js" as Contrast
.import "Format.js" as Format
.import "Material.js" as Material

// Tick-local aliases, then the theme's ANSI names. No literal fallback palette.
var SOURCES = {
    success: ["success", "green", "color2"], warning: ["warning", "yellow", "color3"],
    info: ["info", "blue", "color4"], directory: ["accent"],
    document: ["blue", "color4"], media: ["magenta", "color5"],
    archive: ["yellow", "color3"], code: ["cyan", "color6"]
}
var ICONS = {
    "text-x-generic": "document", "application-pdf": "document",
    "x-office-document": "document", "x-office-spreadsheet": "document",
    "x-office-presentation": "document", "text-html": "code",
    "text-x-script": "code", "text-x-source": "code",
    "application-x-compressed-tar": "archive", "application-x-archive": "archive",
    "package-x-generic": "archive"
}
var EXTENSIONS = {
    document: ["txt", "md", "rst", "pdf", "doc", "docx", "odt", "rtf", "csv", "tsv", "xls", "xlsx", "ods", "ppt", "pptx", "odp"],
    media: ["png", "jpg", "jpeg", "webp", "gif", "svg", "avif", "heic", "mp3", "flac", "wav", "ogg", "m4a", "mp4", "mkv", "webm", "mov"],
    archive: ["zip", "tar", "gz", "xz", "bz2", "zst", "7z", "rar"],
    code: ["rs", "js", "mjs", "cjs", "ts", "tsx", "jsx", "py", "c", "h", "cpp", "hpp", "go", "sh", "qml", "json", "toml", "yaml", "yml", "xml", "html", "css", "lua"]
}

function pick(found, names, fallback) {
    for (var i = 0; i < names.length; i++) {
        var value = found[names[i]]
        if (/^#[0-9a-f]{6}$/i.test(String(value))) return value
    }
    return String(fallback)
}

function hued(ink) {
    var c = Contrast.parse(String(ink)), hi = Math.max.apply(null, c), lo = Math.min.apply(null, c)
    return hi > 0 && (hi - lo) / hi > 0.2
}

function sources(found, accent, foreground) {
    var out = {}, neutral = !hued(accent)
    for (var role in SOURCES)
        out[role] = neutral ? String(foreground) : pick(found, SOURCES[role], accent)
    return out
}

// Compute once per palette/material change, never once per file or frame.
function inks(found, accent, c, alpha, need) {
    var raw = sources(found, accent, c.foreground), text = {}, frame = {}
    for (var role in raw) {
        text[role] = Material.liftInk(raw[role], c, alpha, need)
        frame[role] = Material.liftInk(raw[role], c, alpha, 3)
    }
    return { text: text, frame: frame }
}

// Only the backend's existing permission/trust facts can make a file executable.
function fileRole(row) {
    if (!row) return "unknown"
    if (Format.isSymlink(row.p)) return "symlink"
    if (row.d) return "directory"
    if (row.x !== false && Format.isExecutable(row.p)) return "executable"
    var name = String(row.n || "").toLowerCase(), dot = name.lastIndexOf(".")
    var ext = dot > 0 ? name.substring(dot + 1) : ""
    for (var family in EXTENSIONS)
        if (EXTENSIONS[family].indexOf(ext) >= 0) return family
    var icon = String(row.i || "")
    if (/^(image|audio|video)-/.test(icon)) return "media"
    return Object.prototype.hasOwnProperty.call(ICONS, icon) ? ICONS[icon] : "unknown"
}

// A notice without an audited producer remains neutral; cancellation is never success.
function noticeRole(slot) {
    if (slot.transient && slot.transientIsError) return "error"
    if (slot.armLive) return "warning"
    if (slot.stickyHere || slot.searching) return "info"
    if (slot.transient) return ["success", "warning", "info"].indexOf(slot.noticeKind) >= 0 ? slot.noticeKind : "foreground"
    return "foreground"
}
