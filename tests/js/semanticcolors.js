.import "../../ui/js/SemanticColors.js" as Semantic
.import "../../ui/js/Contrast.js" as Contrast
.import "../../ui/js/Palette.js" as Palette
.import "../../ui/js/Settings.js" as Settings

function run(check) {
    var palette = Palette.parse('green="#5dad77"\ncolor2="#72bb88"\nsuccess="#93cc99"\nblue="#529aca"\ncolor5="#bc85bb"')
    var raw = Semantic.sources(palette, "#5b9bbb", "#dedede")
    check("explicit success precedes green and ANSI", raw.success, "#93cc99")
    check("blue supplies info and documents", raw.info + raw.document, "#529aca#529aca")
    check("ANSI supplies missing named family", raw.media, "#bc85bb")
    check("missing roles inherit accent", raw.warning, "#5b9bbb")
    check("invalid explicit alias tries next valid input", Semantic.sources({success: "bad", green: "#99bb77"}, "#5b9bbb", "#dedede").success, "#99bb77")
    check("empty replacement cannot retain previous colours", Semantic.sources({}, "#aa88cc", "#ffffff").success, "#aa88cc")
    check("neutral accent suppresses foreign family hues", Semantic.sources(palette, "#aaaaaa", "#dddddd").success, "#dddddd")
    var grounds = [
        {background: "#171d21", surface: "#111719", foreground: "#dedede"},
        {background: "#faf9f7", surface: "#e8e7e2", foreground: "#222222"},
        {background: "#111111", surface: "#181818", foreground: "#eeeeee"}
    ]
    for (var i = 0; i < grounds.length; i++) {
        var c = grounds[i], inks = Semantic.inks(palette, "#5599bb", c, 255, 4.5)
        for (var role in inks.text) {
            check("text " + i + " " + role + " passes both planes", Math.min(Contrast.ratio(inks.text[role], c.background), Contrast.ratio(inks.text[role], c.surface)) >= 4.5, true)
            check("mark " + i + " " + role + " passes both planes", Math.min(Contrast.ratio(inks.frame[role], c.background), Contrast.ratio(inks.frame[role], c.surface)) >= 3, true)
        }
    }
    var cases = [
        [null, "unknown"], [{n: "unknown.weird"}, "unknown"], [{n: ".json"}, "unknown"],
        [{n: "unknown", i: "constructor"}, "unknown"],
        [{n: "photo.JPG"}, "media"], [{n: "sound", i: "audio-x-generic"}, "media"],
        [{n: "paper.pdf"}, "document"], [{n: "source.rs", i: "text-x-generic"}, "code"],
        [{n: "backup.tar.gz"}, "archive"], [{n: "source.rs", d: true, p: 16877}, "directory"],
        [{n: "source.rs", d: true, p: 41471}, "symlink"],
        [{n: "program", p: 33261}, "executable"], [{n: "program", p: 33261, x: false}, "unknown"],
        [{n: "script.sh", p: 33188}, "code"], [{n: "script.sh", p: 33261, x: false}, "code"]
    ]
    for (var n = 0; n < cases.length; n++) check("family precedence " + n, Semantic.fileRole(cases[n][0]), cases[n][1])
    for (var value of [undefined, false, true, "true", 1]) {
        var rows = Settings.rows("display", { data: { display: { semanticColors: value } } })
        var row = rows.filter(function (r) { return r.id === "display.semanticColors" })[0]
        check("Display strictly reflects " + value, row.on, value === true)
        check("Display control remains focusable", Settings.focusable(row), true)
    }
}
