.pragma library
.import "AdaptiveMarks.js" as Marks

// Original folded-tab folders and cut-corner documents. SVG 1.2 Tiny-compatible:
// explicit sRGB fills, two restrained gradient stops, no filters/fonts/external resources.
function path(d, fill, stroke, width) {
    return '<path d="' + d + '" fill="' + fill + '" stroke="' + stroke +
        '" stroke-width="' + width + '" stroke-linejoin="round" stroke-linecap="round"/>'
}
function outline(d, fill, p) {
    return path(d, fill, p.keyline, 2.4) + path(d, fill, p.edge, 1.2)
}
function pixelsFor(size) { return Math.max(1, Math.min(512, Math.ceil(Number(size)) || 64)) }
function svg(icon, palette, small, pixels) {
    if (!icon || !palette[icon.kind]) return ""
    var p = palette[icon.kind], kind = icon.kind, body = ""
    var folder = "M7 14Q7 10 11 10H24L30 16H53Q57 16 57 20V49Q57 54 52 54H12Q7 54 7 49Z"
    var face = "M7 25Q7 21 11 21H53Q57 21 57 25V49Q57 54 52 54H12Q7 54 7 49Z"
    var sheet = "M17 7H37L49 19V53Q49 57 45 57H17Q13 57 13 53V11Q13 7 17 7Z"
    var app = "M17 9H47Q55 9 55 17V47Q55 55 47 55H17Q9 55 9 47V17Q9 9 17 9Z"
    var defs = '<defs><linearGradient id="face" x1="0" y1="0" x2="0" y2="1">' +
        '<stop offset="0" stop-color="' + p.light + '"/><stop offset="1" stop-color="' + p.face + '"/>' +
        '</linearGradient></defs>'
    if (kind === "folder") {
        body = outline(folder, p.back, p) + outline(face, small ? p.face : "url(#face)", p)
        if (!small) body += path("M12 24H52", "none", p.light, 1)
    } else if (kind === "app") {
        body = outline(app, small ? p.face : "url(#face)", p)
        if (!small) body += path("M16 13H48", "none", p.light, 1)
    } else {
        body = outline(sheet, p.paper, p)
        body += path("M37 7V19H49", p.back, p.edge, 1.2)
        body += path("M14 28H48V53Q48 56 45 56H17Q14 56 14 53Z", small ? p.face : "url(#face)", "none", 0)
    }
    if (icon.mark && Marks.paths[icon.mark]) {
        // Small plain folders keep their open face; emblems have stronger strokes at list size.
        var mark = path(Marks.paths[icon.mark], "none", p.ink, small ? 2.6 : 2)
        body += kind === "app" ? '<g transform="translate(0 -8)">' + mark + '</g>' : mark
    }
    // Qt's data-URL SVG loader can retain intrinsic dimensions despite Image.sourceSize.
    var canvas = pixelsFor(pixels)
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + canvas + '" height="' + canvas + '" viewBox="0 0 64 64">' + defs + body + '</svg>'
}
function source(icon, palette, small, pixels) {
    var body = svg(icon, palette, small, pixels)
    return body ? "data:image/svg+xml," + encodeURIComponent(body) : ""
}
