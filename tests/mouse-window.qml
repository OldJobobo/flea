//@ pragma ShellId tick-mouse-window-test
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: root
    property int phase: 0
    property int checks: 0
    property int failures: 0
    property double started: Date.now()
    property var hints: null
    function check(label, ok) {
        checks++
        if (!ok) { failures++; console.log("MOUSEWINDOW FAIL " + label) }
    }
    function finish() {
        console.log("MOUSEWINDOW DONE checks=" + checks + " failed=" + failures)
        timer.stop()
        if (body.item) body.item.quitBackends()
        retire.start()
    }
    FloatingWindow {
        id: window
        implicitWidth: 1000
        implicitHeight: 600
        Loader {
            id: body
            anchors.fill: parent
            source: "file://" + Quickshell.env("MOUSE_WINDOW_UI") + "/WindowBody.qml"
            onLoaded: item.host = window
            onStatusChanged: if (status === Loader.Error) { root.check("WindowBody loads", false); root.finish() }
        }
    }
    TestEvent { id: driver }
    Timer {
        id: timer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (Date.now() - root.started > 15000) { root.check("test completes", false); root.finish(); return }
            if (!body.item) return
            var pane = body.item.currentPane
            if (pane.listInFlight || pane.listingState !== "ready" || pane.total !== 3) return
            if (root.phase === 0) {
                for (var i = 0; i < body.item.children.length; i++) {
                    var child = body.item.children[i]
                    if (String(child).indexOf("MouseHints_") === 0) root.hints = child
                }
                root.check("real window has its shared hint lane", root.hints !== null)
                if (!root.hints) { root.finish(); return }
                pane.listArea.forceActiveFocus()
                var search = pane.chromeBar.buttonFor("search")
                driver.mouseMove(search, search.width / 2, search.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                root.phase = 1
                timer.interval = 850
            } else if (root.phase === 1) {
                root.check("real chrome tooltip survives inactive overlay loaders", root.hints.shown && root.hints.bubble.text.indexOf("Search") === 0)
                var row = pane.visibleItemFor(0)
                driver.mouseMove(row, row.width / 2, row.height / 2, -1, Qt.NoButton, Qt.NoModifier)
                root.phase = 2
            } else if (root.phase === 2) {
                var row = pane.visibleItemFor(0)
                root.check("real listing tooltip survives empty share-browser layer", root.hints.shown && root.hints.bubble.text === row.row.n)
                root.check("hover never steals listing keyboard focus", pane.listArea.activeFocus)
                driver.mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton, Qt.NoModifier, -1)
                root.phase = 3
            } else {
                root.check("real context menu blocks covered file hints", pane.contextMenu().opened && !root.hints.shown)
                driver.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)
                root.check("menu still returns keyboard focus", !pane.contextMenu().opened && pane.listArea.activeFocus)
                root.finish()
            }
        }
    }
    Timer { id: retire; interval: 100; onTriggered: Quickshell.execDetached(["kill", String(Quickshell.processId)]) }
}
