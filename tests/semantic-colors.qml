//@ pragma ShellId flea-semantic-colors-test
import QtQuick
import Quickshell
import "flea" as Flea
import "flea/js/Contrast.js" as Contrast
import "flea/js/Material.js" as Material
import "palettes.js" as Palettes

ShellRoot {
    id: test
    property int checks: 0
    property int failed: 0
    function check(label, actual, expected) {
        test.checks++
        if (String(actual) !== String(expected)) {
            test.failed++
            console.log("SEMANTIC FAIL " + label + ": " + actual + " != " + expected)
        }
    }
    function same(label, actual, expected) { test.check(label, String(actual).toLowerCase(), String(expected).toLowerCase()) }
    function enabled(value) { Flea.ViewState.state = {langMarks: false, display: {semanticColors: value}} }
    function run() {
        var body = 'background="#111820"\ndark_background="#0d1218"\nforeground="#dedede"\naccent="#78b9d8"\nblue="#9cbbff"\ngreen="#a7d99b"\nyellow="#e6cd83"\nmagenta="#d7aceb"\ncyan="#8fd8d2"'
        Flea.Theme.applyColors(body)
        test.enabled(false)
        test.same("off list folder", list.nameItem().color, Flea.Theme.color.foreground)
        test.same("off column folder", column.nameItem().color, Flea.Theme.color.foreground)
        test.same("off grid folder", grid.captionItem.color, Flea.Theme.color.foreground)
        test.check("off avoids semantic material derivation", Object.keys(Flea.Theme.color.semantic.text).length, 0)
        test.enabled(true)
        var cases = [
            {n: "Projects", d: true, p: 16877}, {n: "notes.txt", p: 33188},
            {n: "photo.png", p: 33188}, {n: "backup.zip", p: 33188},
            {n: "source.rs", p: 33188}, {n: "link", p: 41471},
            {n: "program", p: 33261}, {n: "modeless", p: 33261, x: false},
            {n: "unknown", p: 33188}
        ]
        for (var i = 0; i < cases.length; i++) {
            list.row = Object.assign({s: 1024, m: 1758835200, k: 0}, cases[i]); column.row = list.row; grid.row = list.row
            var ink = Flea.Theme.color.fileInk(cases[i], false, Flea.Theme.color.foreground)
            test.same("list family " + i, list.nameItem().color, ink)
            test.same("column family " + i, column.nameItem().color, ink)
            test.same("grid family " + i, grid.captionItem.color, ink)
            list.cursor = true; column.cursor = true; grid.cursor = true
            test.same("list cursor " + i, list.nameItem().color, Flea.Theme.color.foreground)
            test.same("column cursor " + i, column.nameItem().color, Flea.Theme.color.accent)
            test.same("grid cursor " + i, grid.captionItem.color, Flea.Theme.color.foreground)
            list.cursor = false; column.cursor = false; grid.cursor = false
        }
        for (var state of ["hovered", "selected", "dropTarget"]) {
            list[state] = true; column[state] = true; grid[state] = true
            test.same("list interaction " + state, list.nameItem().color, Flea.Theme.color.foreground)
            test.same("column interaction " + state, column.nameItem().color, Flea.Theme.color.foreground)
            test.same("grid interaction " + state, grid.captionItem.color, Flea.Theme.color.foreground)
            list[state] = false; column[state] = false; grid[state] = false
        }
        list.row = {n: "notes.txt", p: 33188, s: 1024, m: 1758835200, k: 0}; column.row = list.row; grid.row = list.row
        list.clipMark = "scissors"; column.clipMark = "scissors"; grid.clipMark = "scissors"
        test.check("cut list still dims", list.nameItem().color.a < 1, true)
        test.check("cut column still dims", column.nameItem().color.a < 1, true)
        test.check("cut grid still dims", grid.captionItem.opacity < 1, true)
        list.clipMark = ""; column.clipMark = ""; grid.clipMark = ""
        for (var role in Flea.Theme.color.semantic.text) {
            var textInk = Flea.Theme.color.semantic.text[role], frameInk = Flea.Theme.color.semantic.frame[role]
            for (var ground of [Flea.Theme.color.background, Flea.Theme.color.surface]) {
                test.check("text contrast " + role + ground, Contrast.ratio(textInk, String(ground)) >= 4.5, true)
                test.check("mark contrast " + role + ground, Contrast.ratio(frameInk, String(ground)) >= 3, true)
            }
        }
        for (var palette of Palettes.PALETTES) {
            Flea.Theme.applyColors(palette.body)
            Flea.Glass.clear = true
            for (var mode of ["opaque", "transparent", "glassy"]) {
                Flea.Glass.mode = mode
                var c = Flea.Theme.color.modePalette
                var alpha = Flea.Glass.on && Flea.Glass.usesDefault ? Math.round(Flea.Glass.alpha * 255) : 255
                for (var semanticRole in Flea.Theme.color.semantic.text) {
                    test.check(palette.name + " " + mode + " text " + semanticRole,
                        Material.worst(Flea.Theme.color.semantic.text[semanticRole], c, alpha) >= 4.5, true)
                    test.check(palette.name + " " + mode + " mark " + semanticRole,
                        Material.worst(Flea.Theme.color.semantic.frame[semanticRole], c, alpha) >= 3, true)
                }
            }
        }
        Flea.Glass.mode = "opaque"
        Flea.Theme.applyColors('background="#111111"\nforeground="#eeeeee"\naccent="#bbbbbb"\nblue="#ff0000"')
        test.same("live neutral palette", list.nameItem().color, Flea.Theme.color.foreground)
        Flea.Theme.applyColors(body)
        test.same("live palette restored", list.nameItem().color, Flea.Theme.color.semantic.text.document)
        bar.say("Complete", false, "", "success")
        test.same("typed success reaches status ink", bar.centreColor(), Flea.Theme.color.semantic.text.success)
        bar.say("Failed", true)
        test.same("pending error wins over completion", bar.centreColor(), Flea.Theme.color.errorOnSurface)
        bar.dismiss()
        test.same("completion survives acknowledgement", bar.centreColor(), Flea.Theme.color.semantic.text.success)
        bar.say("Neutral message", false)
        test.same("untyped message cannot inherit success", bar.centreColor(), Flea.Theme.color.foreground)
        bar.classifyNotice("Old message", "warning")
        test.same("stale classification ignored", bar.centreColor(), Flea.Theme.color.foreground)
        bar.classifyNotice("Neutral message", "warning")
        test.same("audited caution reaches status ink", bar.centreColor(), Flea.Theme.color.semantic.text.warning)
        test.enabled(false)
        test.same("off status preserves existing appearance", bar.centreColor(), Flea.Theme.color.foreground)
        test.same("toggle off restores neutral filename", list.nameItem().color, Flea.Theme.color.foreground)
        test.enabled(true)
        proof.grabToImage(function (image) {
            test.check("Qt proof image saved", image.saveToFile(Quickshell.env("SEMANTIC_ROOT") + "/proof.png"), true)
            console.log("SEMANTIC DONE checks=" + test.checks + " failed=" + test.failed)
            Qt.exit(test.failed > 0 ? 1 : 0)
        })
    }
    FloatingWindow {
        id: window
        implicitWidth: 900
        implicitHeight: 560
        color: Flea.Theme.color.background
        Item {
            id: proof
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Flea.Theme.color.background }
            Column {
                width: 900
                Text { text: "Tick · Full semantic colours"; color: Flea.Theme.color.foreground; font.pixelSize: 20; height: 40 }
                Flea.Row { id: list; width: 900; row: ({n: "Projects", d: true, p: 16877, s: 0, m: 1758835200, k: 0}); hiddenCols: []; height: 36 }
                Flea.ColumnRow { id: column; width: 500; row: ({n: "Projects", d: true, p: 16877}); height: 36 }
                Flea.GridTile { id: grid; width: 160; height: 140; row: ({n: "Projects", d: true, p: 16877}) }
                Row {
                    Repeater {
                        model: [{n: "Projects", d: true, i: "folder", p: 16877}, {n: "Notes.pdf", i: "application-pdf"}, {n: "Photo.png", i: "image-x-generic"}, {n: "Source.rs", i: "text-x-source"}, {n: "Backup.zip", i: "application-x-archive"}]
                        Flea.GridTile { required property var modelData; row: modelData; width: 160; height: 160 }
                    }
                }
                Flea.StatusBar { id: bar; width: 900 }
                Row {
                    spacing: 30
                    Text { text: "Completed"; color: Flea.Theme.color.semanticInk("success", Flea.Theme.color.foreground); font.pixelSize: 16 }
                    Text { text: "Review collisions"; color: Flea.Theme.color.semanticInk("warning", Flea.Theme.color.foreground); font.pixelSize: 16 }
                    Text { text: "Copying"; color: Flea.Theme.color.semanticInk("info", Flea.Theme.color.foreground); font.pixelSize: 16 }
                }
            }
        }
    }
    Timer { interval: 200; running: true; onTriggered: test.run() }
}
