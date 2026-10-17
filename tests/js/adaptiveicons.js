.import "../../ui/js/IconColors.js" as Colors
.import "../../ui/js/AdaptiveMarks.js" as Marks
.import "../../ui/js/AdaptiveArtwork.js" as Artwork
.import "iconpalettes.js" as Fixtures

function run(check) {
    var kinds = Object.keys(Marks.names)
    Fixtures.palettes.forEach(function(input) {
        var palette = Colors.derive(input, input.background, input.foreground, input.accent)
        check(input.name + " deterministic", JSON.stringify(palette), JSON.stringify(Colors.derive(input, input.background, input.foreground, input.accent)))
        Object.keys(palette).forEach(function(kind) {
            if (typeof palette[kind] !== "object") return
            var p = palette[kind]
            Object.keys(p).forEach(function(role) {
                check(input.name + " " + kind + " valid " + role, /^#[0-9a-f]{6}$/.test(p[role]), true)
            })
            check(input.name + " " + kind + " emblem contrast", Colors.ratio(p.ink, p.face) >= 4.5, true)
            check(input.name + " " + kind + " fold separation", Colors.lab(p.face)[0] > Colors.lab(p.back)[0], true)
            check(input.name + " " + kind + " silhouette contrast", Colors.ratio(p.face, input.background) >= 3, true)
            check(input.name + " " + kind + " flat roles only", Object.keys(p).sort().join(","), "back,face,ink")
            if (input.name === "Monochrome") {
                var rgb = Colors.rgb(p.face)
                check("neutral stays neutral " + kind, Math.max.apply(Math, rgb) - Math.min.apply(Math, rgb) < 0.001, true)
            }
        })
        kinds.forEach(function(name) {
            var icon = Marks.resolve({i:name})
            ;[true, false].forEach(function(small) {
                var svg = Artwork.svg(icon, palette, small)
                check(input.name + " " + name + " " + small + " valid SVG", svg.indexOf('<svg ') === 0 && !/undefined|NaN|<image|<filter|<script|href=/.test(svg), true)
                check("bounded SVG", svg.length < 6000, true)
                check("flat artwork has no gradients or effects", !/<(?:defs|linearGradient|radialGradient|filter)|url\(/.test(svg), true)
                check("filled silhouettes have no border strokes", !/<path[^>]*fill="(?!none)[^"]*"[^>]*stroke=/.test(svg), true)
                var material = palette[icon.kind]
                var paints = svg.match(/(?:fill|stroke)="[^"]+"/g) || []
                check("every paint is a theme material", paints.every(function(paint) {
                    var color = paint.split('"')[1]
                    return color === "none" || [material.face,material.back,material.ink].indexOf(color)>=0
                }), true)
                check("no unrequested white or black paint", !/="#(?:000000|ffffff)"/i.test(svg), true)
            })
        })
    })
    check("unknown brands are not recoloured", Marks.resolve({i:"firefox"}), null)
    check("unloaded rows stay idle", Marks.resolve(null), null)
    check("prototype is not artwork", Marks.resolve({i:"__proto__"}), null)
    check("Object methods are not artwork", Marks.resolve({i:"toString"}), null)
    check("filenames cannot inject markup", Marks.resolve({i:"folder", n:'<svg onload="bad"/>'}).mark, "")
    check("Documents emblem uses known name", Marks.resolve({d:true, n:"Documents"}).mark, "documents")
    check("explicit folder icon beats basename", Marks.resolve({i:"folder-download", n:"Documents"}).mark, "downloads")
    var fallback = Colors.derive({accent:"bad", blue:"url(evil)"}, "bad", null, "bad")
    check("malformed palette has a safe face", /^#[0-9a-f]{6}$/.test(fallback.folder.face), true)
    check("black white contrast", Math.round(Colors.ratio("#000000", "#ffffff")), 21)
    var red = Colors.lab("#ff0000")
    check("OKLab red reference", Math.abs(red[0] - 0.627955) < 0.00001, true)
    check("out of gamut stays sRGB", /^#[0-9a-f]{6}$/.test(Colors.lch(0.7, 0.8, 2)), true)
    var dark = Colors.derive({}, "#171b22", "#eeeeee", "#85a9e8")
    var light = Colors.derive({}, "#f4f1eb", "#292d34", "#85a9e8")
    check("light and dark need different materials", dark.folder.face !== light.folder.face, true)
    var folder = Marks.resolve({i:"folder"})
    var large = Artwork.svg(folder, dark, false, 128)
    check("SVG canvas matches requested size", large.indexOf('width="128" height="128"')>=0, true)
    check("geometry stays on the design grid", large.indexOf('viewBox="0 0 64 64"')>=0, true)
    check("size change invalidates the image URL", Artwork.source(folder,dark,false,64)!==Artwork.source(folder,dark,false,128), true)
    check("pixel bounds", Artwork.pixelsFor(2000), 512)
    check("pixel floor", Artwork.pixelsFor(-1), 1)
    check("fractional size rounds up", Artwork.pixelsFor(23.5), 24)
    check("invalid size cannot enter SVG markup", Artwork.pixelsFor('64" onload="bad'), 64)
    check("safe theme accent is used exactly", dark.folder.face, "#85a9e8")
    check("ink uses the theme foreground when it contrasts", Colors.ink("#152c3c","#f4f1eb","#85a9e8"), "#152c3c")
    check("ink follows changed theme foreground", Colors.ink("#422332","#f4f1eb","#85a9e8"), "#422332")
    check("ink can use the theme background", Colors.ink("#dce3ed","#171b22","#85a9e8"), "#171b22")
    check("explicit black theme ink is honoured", Colors.ink("#000000","#f4f1eb","#85a9e8"), "#000000")
}
