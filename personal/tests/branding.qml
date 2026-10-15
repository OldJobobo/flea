import QtQuick
import Quickshell
import "flea" as Flea
import "flea/js/Icons.js" as Icons
import "flea/js/IconPacks.js" as Packs

Window {
    id: root
    width: 900; height: 680; visible: true
    color: Flea.Theme.color.background
    property int checks: 0
    property int failures: 0
    property int phase: 0
    property int packIndex: 0
    property double started: Date.now()
    property bool capturing: false
    property bool captured: false
    function check(label, ok) {
        root.checks++
        if (!ok) { root.failures++; console.log("TICK FAIL " + label) }
    }
    function done() {
        console.log("TICK DONE checks=" + root.checks + " failed=" + root.failures)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
    Component.onCompleted: Flea.Theme.applyColors('background = "#202326"\nforeground = "#f4f4f4"\naccent = "#a5bacb"')
    function capture(label) {
        var directory = Quickshell.env("TICK_CAPTURE_DIR")
        if (!directory || root.captured) return true
        if (!root.capturing) {
            root.capturing = true
            root.contentItem.grabToImage(function (image) {
                root.check("About capture", image.saveToFile(directory + "/" + label + ".png"))
                root.captured = true
            })
        }
        return false
    }
    Flea.Glyph { id: shelf; x: 24; y: 24; width: 48; height: 48; maxSize: 48; name: "shelf"; color: Flea.Theme.color.foreground }
    Flea.Glyph { id: folder; x: 84; y: 24; width: 48; height: 48; maxSize: 48; name: "folder"; color: Flea.Theme.color.foreground }
    Flea.Glyph { id: markdown; x: 144; y: 24; width: 48; height: 48; maxSize: 48; name: "markdown"; color: Flea.Theme.color.foreground }
    Flea.SettingsPanel { id: settings; anchors.fill: parent; section: "about" }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (Date.now() - root.started > 10000) {
                root.check("phase " + root.phase + " completes", false)
                stop(); root.done(); return
            }
            if (root.phase === 0) {
                if (!Flea.ViewState.initialReadComplete || !Flea.Theme.ready) return
                var rows = settings.rows
                root.check("About is Tick", rows[0].label === "Tick")
                root.check("About records source", rows.some(function (row) { return row.label === "Build" && row.value === Quickshell.env("TICK_BUILD") }))
                root.check("About credits upstream", rows.some(function (row) { return row.label === "License" && row.value.indexOf("GM") >= 0 }))
                root.check("About has no stock update/default action", !rows.some(function (row) { return row.id === "makeDefault" || row.id === "updateFlea" || row.id === "updates.autoCheck" }))
                Flea.UpdateCheck.check(); Flea.UpdateCheck.startPolling(); Flea.DefaultClaim.toggle()
                root.check("stock updater cannot poll", !Flea.UpdateCheck.polling && Flea.UpdateCheck.menuVersion === "")
                root.check("file geometry unchanged", Icons.pathFor("folder") === "M2 20V3h6l2 3h12v14H2z")
                root.check("Markdown artwork unchanged", Icons.pathFor("markdown") === "M2 5h20v14H2z M5.5 15V9l3 3.5 3-3.5v6 M17 9v6 M14.5 12.5 17 15l2.5-2.5")
                settings.open(null)
                root.started = Date.now(); root.phase = 1; return
            }
            if (root.phase === 1) {
                if (Date.now() - root.started < 700 || !root.capture("tick-about")) return
                settings.close()
                root.phase = 2; root.started = Date.now(); return
            }
            if (root.phase === 3) {
                if (Date.now() - root.started < 700 || !root.capture("tick-about-light")) return
                root.check("light theme recolors the Tick mark", shelf.color === Flea.Theme.color.foreground && String(shelf.color) !== "#f4f4f4")
                stop(); root.done(); return
            }
            var expected = Packs.IDS[root.packIndex]
            if (Flea.ViewState.iconTheme.selection !== expected) return
            if (expected !== "flea" && !Flea.ViewState.iconTheme.pack) return
            if (Flea.ViewState.saveStatus !== "Saved") return
            root.check(expected + " retains Tick brand", shelf.solidOnly && shelf.iconPath.length > 1000 && shelf.filledPath === "")
            root.check(expected + " retains Markdown paint", !markdown.solidOnly)
            root.check(expected + " file paint recipe", folder.solidOnly === (expected === "phosphor"))
            root.check(expected + " no extra folder shape", folder.solid === null)
            root.check(expected + " loads without error", Flea.ViewState.iconTheme.error === "")
            root.packIndex++
            if (Packs.IDS[root.packIndex] === "custom") {
                Flea.Theme.applyColors('background = "#f4f4f4"\nforeground = "#202326"\naccent = "#3b6483"')
                settings.open(null)
                root.captured = false; root.capturing = false
                root.phase = 3; root.started = Date.now(); return
            }
            Flea.ViewState.changeSetting("display.iconSet", Packs.IDS[root.packIndex])
            root.started = Date.now()
        }
    }
}
