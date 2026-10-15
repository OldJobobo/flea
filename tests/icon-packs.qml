import QtQuick
import Quickshell
import Quickshell.Io
import "flea" as Flea
import "flea/js/Icons.js" as Icons

Window {
    id: root
    width: 680
    height: 180
    visible: true
    color: Flea.Theme.color.background
    property var captures: ({})
    property bool capturing: false
    // Optional evidence export stays outside the disposable test fixture, in a caller-owned directory.
    function captured(label) {
        var directory = Quickshell.env("ICON_PACK_CAPTURE_DIR")
        if (!directory || root.captures[label]) return true
        if (!root.capturing) {
            root.capturing = true
            root.contentItem.grabToImage(function (image) {
                if (!image.saveToFile(directory + "/" + label + ".png")) root.check("capture " + label, false)
                root.captures[label] = true
                root.capturing = false
            })
        }
        return false
    }
    property int phase: 0
    property int checks: 0
    property int failures: 0
    property double started: Date.now()
    property string customPath: "M1 1h22v22H1z"
    property string customText: JSON.stringify({ version: 1, grid: 24, style: "square",
        icons: { folder: { path: root.customPath }, contrast: { path: "M2 2h20v20H2z", filled: "M4 4h4v4H4z" } } })

    function check(label, ok) {
        root.checks++
        if (!ok) { root.failures++; console.log("ICONPACKS FAIL " + label) }
    }
    Flea.SettingsPanel { id: settings; section: "display" }
    function choose(name) {
        for (var i = 0; i < settings.rows.length; i++) {
            if (settings.rows[i].id !== "display.iconSet") continue
            settings.stepRowValue(i, 1)
            root.check("settings selector chooses " + name, Flea.ViewState.iconTheme.selection === name)
            break
        }
        root.started = Date.now()
    }
    function done() {
        console.log("ICONPACKS DONE checks=" + root.checks + " failed=" + root.failures)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 14; text: Flea.ViewState.iconTheme.selection; color: Flea.Theme.color.foreground; font.pixelSize: 18 }
    Row {
        anchors.centerIn: parent
        spacing: 14
        Repeater {
            id: marks
            model: ["folder", "file-text", "music", "drive", "folder-plus", "contrast", "shelf", "markdown"]
            Flea.Glyph {
                required property string modelData
                width: 56; height: 56; maxSize: 40; name: modelData; color: Flea.Theme.color.foreground
                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; text: parent.modelData; color: Flea.Theme.color.foreground; font.pixelSize: 10 }
            }
        }
    }
    FileView {
        id: custom
        path: Quickshell.env("XDG_CONFIG_HOME") + "/flea/icons/custom.json"
        printErrors: false
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (Date.now() - root.started > 10000) {
                console.log("ICONPACKS STATE selection=" + Flea.ViewState.iconTheme.selection + " error=" + Flea.ViewState.iconTheme.error + " save=" + Flea.ViewState.saveStatus)
                root.check("phase " + root.phase + " completes", false)
                stop(); root.done(); return
            }
            var folder = marks.itemAt(0), contrast = marks.itemAt(5)
            if (root.phase === 0) {
                if (!Flea.ViewState.initialReadComplete || !folder || !contrast) return
                if (!root.captured("flea")) return
                root.check("default creates no reader", Flea.ViewState.iconTheme.reader === null)
                root.check("default path unchanged", folder.iconPath === Icons.pathFor("folder"))
                root.check("default solid half unchanged", contrast.filledPath === Icons.filledPathFor("contrast"))
                root.choose("tabler"); root.phase++; return
            }
            if (root.phase === 1) {
                if (!Flea.ViewState.iconTheme.pack || Flea.ViewState.saveStatus !== "Saved") return
                if (!root.captured("tabler")) return
                root.check("Tabler changes existing delegates", folder.iconPath !== Icons.pathFor("folder"))
                root.check("Tabler owns round caps", folder.rounded)
                root.check("Tabler removes old solid half", contrast.filledPath === "")
                root.check("the existing solid renderer clears too", contrast.solid && contrast.solid.glyph.filledPath === "")
                root.check("Flea brand remains", marks.itemAt(6).iconPath === Icons.pathFor("shelf"))
                root.check("Markdown brand remains", marks.itemAt(7).iconPath === Icons.pathFor("markdown"))
                root.choose("custom"); root.phase++; return
            }
            if (root.phase === 2) {
                if (!Flea.ViewState.iconTheme.error || Flea.ViewState.saveStatus !== "Saved") return
                root.check("missing custom pack falls back", folder.iconPath === Icons.pathFor("folder"))
                custom.setText(root.customText)
                root.started = Date.now(); root.phase++; return
            }
            if (root.phase === 3) {
                if (folder.iconPath !== root.customPath) return
                if (!root.captured("custom")) return
                root.check("new custom file reloads live", Flea.ViewState.iconTheme.error === "")
                root.check("custom owns square caps", !folder.rounded)
                root.check("missing custom mark retains semantic fallback", marks.itemAt(2).iconPath === Icons.pathFor("music"))
                root.check("custom filled path drawn", contrast.filledPath === "M4 4h4v4H4z")
                custom.setText("{broken")
                root.started = Date.now(); root.phase++; return
            }
            if (root.phase === 4) {
                if (!Flea.ViewState.iconTheme.error) return
                root.check("invalid edit drops the entire pack", folder.iconPath === Icons.pathFor("folder"))
                root.check("invalid edit restores default fill", contrast.filledPath === Icons.filledPathFor("contrast"))
                custom.setText(root.customText)
                root.started = Date.now(); root.phase++; return
            }
            if (root.phase === 5) {
                if (folder.iconPath !== root.customPath) return
                root.check("corrected pack recovers without restart", Flea.ViewState.iconTheme.error === "")
                root.choose("flea"); root.phase++; return
            }
            if (root.phase === 6) {
                if (Flea.ViewState.saveStatus !== "Saved") return
                root.check("return to Flea releases reader", Flea.ViewState.iconTheme.reader === null)
                root.check("return restores geometry", folder.iconPath === Icons.pathFor("folder"))
                root.check("return clears load error", Flea.ViewState.iconTheme.error === "")
                stop(); root.done()
            }
        }
    }
}
