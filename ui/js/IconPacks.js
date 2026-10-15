.pragma library
.import "Icons.js" as Icons

// Packs are data, never QML, JavaScript, SVG documents or external image URLs.
var IDS = ["flea", "tabler", "lucide", "iconoir", "heroicons", "phosphor", "feather", "custom"]
var LABELS = ["Flea", "Tabler Outline", "Lucide", "Iconoir", "Heroicons Outline", "Phosphor Regular", "Feather", "Custom"]
var MAX_BYTES = 524288
var MAX_ICONS = 128
var MAX_PATH = 16384

function selected(value) { return IDS.indexOf(value) >= 0 ? value : "flea" }
function own(object, key) { return Object.prototype.hasOwnProperty.call(object, key) }
function object(value) { return value !== null && typeof value === "object" && !Array.isArray(value) }

// Only bounded path geometry crosses into PathSvg. Reject markup, URLs, non-finite or
// extreme coordinates, incomplete commands and invalid arc flags before Qt sees them.
function pathValid(path) {
    if (typeof path !== "string" || path.length === 0 || path.length > MAX_PATH
            || !/^[Mm]/.test(path) || /[^MmLlHhVvCcSsQqTtAaZz0-9eE+.,\s-]/.test(path)) return false
    var tokens = path.match(/[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?/g) || []
    // Ensure the tokenizer consumed everything except separators.
    if (path.replace(/[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?/g, "").replace(/[\s,]/g, "") !== "") return false
    var counts = { M: 2, L: 2, H: 1, V: 1, C: 6, S: 4, Q: 4, T: 2, A: 7 }
    var command = "", used = 0
    for (var i = 0; i < tokens.length; i++) {
        var token = tokens[i]
        if (/^[A-Za-z]$/.test(token)) {
            if (command && (used === 0 || used % counts[command] !== 0)) return false
            command = token.toUpperCase()
            used = 0
            if (command === "Z") command = ""
        } else {
            var number = Number(token)
            if (!command || !isFinite(number) || Math.abs(number) > 1024) return false
            if (command === "A") {
                var slot = used % 7
                if ((slot < 2 && number < 0) || ((slot === 3 || slot === 4) && number !== 0 && number !== 1)) return false
            }
            used++
        }
    }
    return !command || (used > 0 && used % counts[command] === 0)
}

function parse(text) {
    var bad = { pack: null, error: "Icon pack is invalid. Using Flea icons." }
    if (typeof text !== "string" || text.length > MAX_BYTES) return bad
    var data
    try { data = JSON.parse(text) } catch (_) { return bad }
    if (!object(data) || data.version !== 1 || data.grid !== 24
            || ["round", "square"].indexOf(data.style) < 0 || !object(data.icons)
            || (data.paint !== undefined && ["stroke", "fill"].indexOf(data.paint) < 0)) return bad
    var names = Object.keys(data.icons)
    if (names.length === 0 || names.length > MAX_ICONS) return bad
    var icons = Object.create(null)
    for (var i = 0; i < names.length; i++) {
        var name = names[i], icon = data.icons[name]
        // Only existing semantic names are replaceable; brand marks never enter this table.
        if (name === "shelf" || name === "markdown" || !own(Icons.PATHS, name) || !object(icon) || !pathValid(icon.path)
                || (icon.filled !== undefined && icon.filled !== "" && !pathValid(icon.filled))) return bad
        icons[name] = { path: icon.path, filled: icon.filled || "" }
    }
    return { pack: { style: data.style, paint: data.paint || "stroke", icons: icons }, error: "" }
}

function has(pack, name) { return pack !== null && own(pack.icons, name) }
function solidOnly(pack, name) { return has(pack, name) && pack.paint === "fill" }
function pathFor(pack, name) { return has(pack, name) ? pack.icons[name].path : Icons.pathFor(name) }
function filledFor(pack, name) { return has(pack, name) ? pack.icons[name].filled : Icons.filledPathFor(name) }
function rounded(pack, name, fleaRound) { return has(pack, name) ? pack.style === "round" : fleaRound }
