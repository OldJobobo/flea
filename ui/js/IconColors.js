.pragma library

// Original adaptive-icon materials. OKLab matrices: Björn Ottosson (MIT/public domain).
// Recipes are shared by every theme; only palette inputs vary.
function clamp(n, lo, hi) { return Math.max(lo, Math.min(hi, n)) }
function hex(value, fallback) { return /^#[0-9a-f]{6}$/i.test(String(value)) ? String(value) : fallback }
function pick(p, names, fallback) {
    for (var i = 0; i < names.length; i++) {
        var value = hex(p[names[i]], "")
        if (value) return value
    }
    return fallback
}
function linear(n) { return n <= 0.04045 ? n / 12.92 : Math.pow((n + 0.055) / 1.055, 2.4) }
function rgb(value) {
    return [linear(parseInt(value.slice(1, 3), 16) / 255),
            linear(parseInt(value.slice(3, 5), 16) / 255), linear(parseInt(value.slice(5, 7), 16) / 255)]
}
function lab(value) {
    var c = rgb(value), r = c[0], g = c[1], b = c[2]
    var l = Math.cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b)
    var m = Math.cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b)
    var s = Math.cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b)
    return [0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            0.0259040371*l + 0.7827717662*m - 0.8086757660*s]
}
function fromLab(L, a, b) {
    var l = Math.pow(L + 0.3963377774*a + 0.2158037573*b, 3)
    var m = Math.pow(L - 0.1055613458*a - 0.0638541728*b, 3)
    var s = Math.pow(L - 0.0894841775*a - 1.2914855480*b, 3)
    return [4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
            -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
            -0.0041960863*l - 0.7034186147*m + 1.7076147010*s]
}
function encode(c) {
    return "#" + c.map(function(n) {
        var v = n <= 0.0031308 ? 12.92*n : 1.055*Math.pow(n, 1/2.4) - 0.055
        return ("0" + Math.round(clamp(v, 0, 1)*255).toString(16)).slice(-2)
    }).join("")
}
function lch(L, C, h) {
    // Reduce chroma into sRGB rather than clipping individual channels and shifting hue.
    var lo = 0, hi = C, result = fromLab(L, 0, 0)
    for (var i = 0; i < 16; i++) {
        var chroma = (lo + hi) / 2
        var c = fromLab(L, chroma*Math.cos(h), chroma*Math.sin(h))
        if (c.every(function(n) { return n >= 0 && n <= 1 })) { lo = chroma; result = c }
        else hi = chroma
    }
    return encode(result)
}
function luminance(c) { var v = rgb(c); return 0.2126*v[0] + 0.7152*v[1] + 0.0722*v[2] }
function ratio(a, b) {
    var x = luminance(a), y = luminance(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}
function ink(ground) { return ratio("#000000", ground) > ratio("#ffffff", ground) ? "#000000" : "#ffffff" }
function boundary(bg, selected) {
    // Maximise the weaker contrast. The second keyline handles incompatible grounds.
    var best = "#000000", score = 0
    for (var i = 0; i <= 100; i++) {
        var c = lch(i/100, 0, 0), next = Math.min(ratio(c, bg), ratio(c, selected))
        if (next > score) { score = next; best = c }
    }
    return best
}
function material(seed, bg, edge, neutral) {
    var v = lab(seed), C = Math.sqrt(v[1]*v[1] + v[2]*v[2])
    var h = Math.atan2(v[2], v[1]), dark = lab(bg)[0] < 0.6
    var L = dark ? 0.73 : 0.56
    C = neutral ? 0 : Math.min(C, 0.16)
    var face = lch(L, C, h), emblem = ink(face), light = face
    // White emblems on light-theme materials must survive the bright end too.
    var lo = 0, hi = 1
    for (var i = 0; i < 12; i++) {
        var t = (lo + hi) / 2, candidate = lch(L + 0.055*t, C*(1 - 0.2*t), h)
        if (ratio(emblem, candidate) >= 4.5) { lo = t; light = candidate }
        else hi = t
    }
    return { face: face, back: lch(L - 0.14, C*0.85, h), light: light, edge: edge,
             ink: emblem, keyline: ink(edge), paper: lch(dark ? 0.87 : 0.94, C*0.12, h) }
}
function derive(p, background, foreground, accent) {
    p = p || {}
    var bg = hex(background, "#101315"), fg = hex(foreground, "#ffffff")
    var seed = pick(p, ["accent"], hex(accent, fg))
    var selected = pick(p, ["selection_background", "selection"], bg)
    var edge = boundary(bg, selected), v = lab(seed)
    // A neutral accent is deliberate: never invent rainbow icons for monochrome themes.
    var neutral = Math.sqrt(v[1]*v[1] + v[2]*v[2]) < 0.025
    var out = { background: bg, selection: selected, foreground: fg }
    var sources = { folder: seed, document: pick(p, ["blue", "color4"], seed),
        image: pick(p, ["magenta", "color5"], seed), audio: pick(p, ["cyan", "color6"], seed),
        video: pick(p, ["magenta", "color5"], seed), archive: pick(p, ["yellow", "color3"], seed),
        code: pick(p, ["green", "color2"], seed), app: seed }
    Object.keys(sources).forEach(function(key) { out[key] = material(sources[key], bg, edge, neutral) })
    return out
}
