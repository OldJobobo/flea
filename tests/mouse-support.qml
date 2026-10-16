import QtQuick
import QtTest
import Quickshell
import "flea" as Flea

Window {
    id: root
    width: 640; height: 420; visible: true
    property int checks: 0
    property int failures: 0
    property int presses: 0
    property int forwards: 0
    property var tabPane: ({ enabled: true, path: "/one", home: "/", searchMode: "", recentMode: "",
        listInFlight: false, dropPath: "", backend: null, statusBar: statusStub,
        tabs: { index: 0, items: [{ tabIdentity: 1, path: "/one" }, { tabIdentity: 2, path: "/two" }] },
        contextMenu: function() { return menu } })
    function check(label, ok) {
        checks++
        if (!ok) { failures++; console.log("MOUSE FAIL " + label) }
    }
    QtObject { id: statusStub; property var activities: [] }
    Item {
        id: surface
        anchors.fill: parent
        focus: true
        Flea.ChromeButton { id: back; x: 30; y: 30; glyph: "arrow-left"; onActivated: root.presses++ }
        Flea.ChromeButton { id: close; x: 580; y: 365; glyph: "x" }
        Item {
            id: file
            x: 100; y: 120; width: 200; height: 40
            property string mouseHint: "<b>a very long filename.txt</b>"
        }
        Flea.ChromeBar { id: nav; y: 240; width: 600; height: 40; onForwardRequested: root.forwards++ }
        Flea.TabBar { id: strip; y: 300; width: 600; height: 40; pane: root.tabPane }
        Rectangle { id: shield; anchors.fill: parent; visible: false; z: 10; color: "transparent" }
    }
    Flea.MouseHints { id: hints; surface: surface }
    Flea.ContextMenu { id: menu; anchors.fill: surface; focusOwner: surface }
    TestEvent { id: driver }
    property int step: 0
    property var actions: [
        function() {
            surface.forceActiveFocus()
            driver.mouseMove(back, back.width / 2, back.height / 2, -1, Qt.NoButton, Qt.NoModifier)
        }, function() {
            root.check("hover shows a delayed tooltip", hints.shown)
            root.check("chrome tooltip has a readable label", hints.bubble && hints.bubble.text.indexOf("Back") === 0)
            root.check("tooltip preserves keyboard focus", surface.activeFocus)
            driver.mouseClick(back, back.width / 2, back.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
            root.check("tooltip never consumes a button click", root.presses === 1)
            root.check("press dismisses the tooltip", !hints.shown)
            driver.mouseMove(file, 20, 20, -1, Qt.NoButton, Qt.NoModifier)
        }, function() {
            root.check("file names remain literal text", hints.shown && hints.bubble.text === file.mouseHint)
            file.mouseHint = "replacement.txt"
            timer.interval = 160
        }, function() {
            root.check("reused delegate dismisses stale text", !hints.shown)
            timer.interval = 850
        }, function() {
            root.check("replacement name can be shown", hints.shown && hints.bubble.text === file.mouseHint)
            shield.visible = true
            timer.interval = 160
        }, function() {
            root.check("overlay hides covered hints", !hints.shown)
            timer.interval = 850
            shield.visible = false
            driver.mouseMove(close, close.width / 2, close.height / 2, -1, Qt.NoButton, Qt.NoModifier)
        }, function() {
            root.check("edge tooltip is visible", hints.shown)
            root.check("tooltip stays within window", hints.bubble && hints.bubble.x >= 0 && hints.bubble.y >= 0
                && hints.bubble.x + hints.bubble.width <= surface.width && hints.bubble.y + hints.bubble.height <= surface.height)
            hints.inputStamp++
            root.check("keyboard input dismisses the hint", !hints.shown)
            nav.canGoForward = true
            var forward = nav.buttonFor("arrow-right")
            driver.mouseClick(forward, forward.width / 2, forward.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
            root.check("forward control dispatches once", root.forwards === 1)
            nav.canGoForward = false
            driver.mouseClick(forward, forward.width / 2, forward.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
            root.check("disabled forward does not dispatch", root.forwards === 1)
            driver.mouseClick(strip, 30, 20, Qt.RightButton, Qt.NoModifier, -1)
        }, function() {
            root.check("right click on a tab opens the shared menu", menu.opened && menu.forTab)
            root.check("tab menu offers three commands", menu.entries.filter(function(e) { return !e.separator }).length === 3)
            root.check("menu takes keyboard focus only while open", menu.keyboardFocused)
            driver.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)
        }, function() {
            root.check("Escape closes tab menu", !menu.opened)
            root.check("Escape restores previous keyboard focus", surface.activeFocus)
            menu.openForTab(root.tabPane, 0, Qt.point(30, 320))
            menu.openForHeader(Qt.point(40, 40))
            root.check("header menu clears the tab context", !menu.forTab && menu.forHeader)
            menu.openBackground(Qt.point(40, 40))
            root.check("background menu clears alternate contexts", !menu.forTab && !menu.forHeader && !menu.hasRow)
            root.check("background offers new tab and refresh", menu.entries.some(function(e) { return e.action === "tabNew" })
                && menu.entries.some(function(e) { return e.action === "reload" }))
            menu.close()
            console.log("MOUSE DONE checks=" + root.checks + " failed=" + root.failures)
            timer.stop()
            Quickshell.execDetached(["kill", String(Quickshell.processId)])
        }
    ]
    Timer { id: timer; interval: 850; repeat: true; running: true; onTriggered: root.actions[root.step++]() }
}
