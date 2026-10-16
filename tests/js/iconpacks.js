.import "../../ui/js/IconPacks.js" as Packs
.import "../../ui/js/Icons.js" as Icons

function run(check) {
    check("absent selection keeps the original appearance", Packs.selected(undefined), "flea")
    check("unknown selection heals to Flea", Packs.selected("remote"), "flea")
    check("pack IDs stay stable", Packs.IDS.join(","), "flea,tabler,lucide,iconoir,heroicons,phosphor,feather,custom")
    check("every pack has a selector label", Packs.LABELS.length, Packs.IDS.length)
    function pack(icons) { return JSON.stringify({ version: 1, grid: 24, style: "round", icons: icons }) }
    var valid = pack({ folder: { path: "M2 3h20v18H2z" } })
    var parsed = Packs.parse(valid)
    check("a partial pack loads", parsed.error, "")
    check("the selected geometry replaces only its own mark", Packs.pathFor(parsed.pack, "folder"), "M2 3h20v18H2z")
    check("missing geometry stays semantic, not a generic file", Packs.pathFor(parsed.pack, "music"), Icons.pathFor("music"))
    check("missing fill retains the original solid half", Packs.filledFor(parsed.pack, "contrast"), Icons.filledPathFor("contrast"))
    check("overridden outlines do not inherit Flea fills", Packs.filledFor(Packs.parse(pack({ contrast: { path: "M2 2h20v20z" } })).pack, "contrast"), "")
    check("round pack ignores Flea's edge preference", Packs.rounded(parsed.pack, "folder", false), true)
    check("fallback marks retain their own edge preference", Packs.rounded(parsed.pack, "music", false), false)
    check("default geometry is byte-for-byte unchanged", Packs.pathFor(null, "folder"), Icons.pathFor("folder"))
    check("unknown semantic name follows the existing fallback", Packs.pathFor(parsed.pack, "unknown"), Icons.pathFor("file"))
    check("an unknown prototype key is never pack geometry", Packs.has(parsed.pack, "constructor"), false)
    check("old packs default to strokes", parsed.pack.paint, "stroke")
    var filled = Packs.parse(valid.replace('"style":"round"', '"style":"round","paint":"fill"')).pack
    check("expanded outlines use the existing shape", Packs.solidOnly(filled, "folder"), true)
    check("missing marks keep their stroke recipe", Packs.solidOnly(filled, "music"), false)
    check("Flea keeps its stroke recipe", Packs.solidOnly(null, "folder"), false)
    var bad = ["", "null", "[]", "not JSON", valid.replace('"version":1', '"version":2'),
               valid.replace('"grid":24', '"grid":16'), valid.replace('"round"', '"soft"'),
               valid.replace('"style":"round"', '"style":"round","paint":"remote"'),
               pack({}), pack({ tailscale: { path: "M2 2h2" } }), pack({ folder: "M2 2h2" }),
               pack({ shelf: { path: "M2 2h2" } }), pack({ markdown: { path: "M2 2h2" } }),
               pack({ folder: { path: "M2 2h2", filled: 5 } }), pack({ folder: { path: "M2 2h2", filled: "<svg/>" } }),
               new Array(Packs.MAX_BYTES + 2).join(" ")]
    for (var i = 0; i < bad.length; i++) {
        check("invalid pack fails atomically " + i, Packs.parse(bad[i]).pack, null)
        check("invalid pack explains fallback " + i, Packs.parse(bad[i]).error.length > 0, true)
    }
    var paths = ["", "L1 2", "M1", "M1 2L", "M1 2L4", "M1 2 NaN", "M1 2hInfinity",
                 "M1 2h1e999", "M1 2h1025", "M1 2A-1 2 0 0 1 3 4", "M1 2A1 2 0 2 1 3 4",
                 "M1 2<script>", "M1 2https://example.com", "M1 2e", "M1 2Z4", "M1 2" + new Array(Packs.MAX_PATH).join(" ")]
    for (var p = 0; p < paths.length; p++)
        check("unsafe/incomplete geometry refused " + p, Packs.pathValid(paths[p]), false)
    for (var path of ["M1 2h2z", "m1 2 3 4", "M1 2A3 4 0 1 0 5 6", "M.1 -.2l1e-2 3", "M1 2Q3 4 5 6T7 8"])
        check("SVG path accepted " + path, Packs.pathValid(path), true)

    for (var id of Packs.IDS.slice(1, -1)) {
        var request = new XMLHttpRequest()
        request.open("GET", Qt.resolvedUrl("../../ui/icons/" + id + ".json"), false)
        request.send()
        var answer = Packs.parse(request.responseText)
        check(id + " bundled pack validates", answer.error, "")
        if (!answer.pack) continue
        check(id + " carries every non-brand mark", Object.keys(answer.pack.icons).length, Object.keys(Icons.PATHS).length - 2)
        check(id + " reserves the Flea brand", Packs.pathFor(answer.pack, "shelf"), Icons.pathFor("shelf"))
        check(id + " reserves the Markdown brand", Packs.pathFor(answer.pack, "markdown"), Icons.pathFor("markdown"))
        for (var name in Icons.PATHS) {
            if (name === "shelf" || name === "markdown") continue
            check(id + " supplies " + name, Packs.has(answer.pack, name), true)
            check(id + " uses its own fill " + name, Packs.filledFor(answer.pack, name), answer.pack.icons[name].filled)
            check(id + " paint recipe " + name, Packs.solidOnly(answer.pack, name), id === "phosphor")
        }
    }
}
