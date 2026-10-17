.pragma library
.import "AdaptiveMarks.js" as Marks

// Original flat artwork: solid theme-keyed faces, folds and symbols only.
// No perimeter strokes, gradients, shadows, filters, fonts or external resources.
function shape(d, fill) { return '<path d="' + d + '" fill="' + fill + '"/>' }
function symbol(d, ink, width) {
    return '<path d="' + d + '" fill="none" stroke="' + ink +
        '" stroke-width="' + width + '" stroke-linejoin="round" stroke-linecap="round"/>'
}
function pixelsFor(size) { return Math.max(1, Math.min(512, Math.ceil(Number(size)) || 64)) }
function svg(icon, palette, small, pixels) {
    if (!icon || !palette[icon.kind]) return ""
    var p = palette[icon.kind], kind = icon.kind, body = ""
    var folder = "M7 14Q7 10 11 10H24L30 16H53Q57 16 57 20V49Q57 54 52 54H12Q7 54 7 49Z"
    var face = "M7 25Q7 21 11 21H53Q57 21 57 25V49Q57 54 52 54H12Q7 54 7 49Z"
    var sheet = "M17 7H37L49 19V53Q49 57 45 57H17Q13 57 13 53V11Q13 7 17 7Z"
    var app = "M17 9H47Q55 9 55 17V47Q55 55 47 55H17Q9 55 9 47V17Q9 9 17 9Z"
    if (kind === "folder") {
        body = shape(folder, p.back) + shape(face, p.face)
    } else if (kind === "app") {
        body = shape(app, p.face)
    } else {
        body = shape(sheet, p.face) + shape("M37 7V19H49Z", p.back)
    }
    if (icon.mark && Marks.paths[icon.mark]) {
        var mark = symbol(Marks.paths[icon.mark], p.ink, small ? 2.6 : 2)
        body += kind === "app" ? '<g transform="translate(0 -8)">' + mark + '</g>' : mark
    }
    // Qt's data-URL SVG loader can retain intrinsic dimensions despite Image.sourceSize.
    var canvas = pixelsFor(pixels)
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + canvas + '" height="' + canvas + '" viewBox="0 0 64 64">' + body + '</svg>'
}
function source(icon, palette, small, pixels) {
    var body = svg(icon, palette, small, pixels)
    return body ? "data:image/svg+xml," + encodeURIComponent(body) : ""
}
