import QtQuick
import "js/MouseHints.js" as Hints
import "js/Keymap.js" as Keymap

// One delayed, focus-neutral tooltip lane per window. No per-file objects or reads.
Item {
    id: root
    required property Item surface
    property var target: null
    property var bubble: null
    property bool held: false
    property point lastPosition: Qt.point(-1, -1)
    property bool over: false
    property real inputStamp: 0
    onInputStampChanged: root.dismiss()
    readonly property bool shown: root.bubble !== null && root.bubble.visible

    function hide() {
        delay.stop()
        if (root.bubble) root.bubble.visible = false
    }
    function dismiss() { root.hide(); root.target = null }
    // Hit testing waits for dwell, rather than walking UI children on every mouse move.
    function moved() {
        var point = pointer.point.position
        if (point.x === root.lastPosition.x && point.y === root.lastPosition.y && pointer.hovered === root.over) return
        root.lastPosition = point
        root.over = pointer.hovered
        root.dismiss()
        if (pointer.hovered && !root.held) delay.restart()
    }
    function updateTarget() {
        var next = pointer.hovered && !root.held
                 ? Hints.at(root.surface, pointer.point.position.x, pointer.point.position.y) : null
        if (next === root.target) return
        root.hide()
        root.target = next
        if (next) delay.restart()
    }
    function show() {
        root.updateTarget()
        if (!root.target || root.held || !pointer.hovered) { root.hide(); return }
        if (!root.bubble)
            root.bubble = Qt.createComponent("MouseHintBubble.qml").createObject(root.surface, { z: 1000 })
        root.bubble.text = Hints.text(root.target.mouseHint,
            root.target.hintAction ? Keymap.hintFor(root.target.hintAction) : "")
        root.bubble.width = Math.min(root.surface.width, root.bubble.implicitWidth)
        var at = Hints.position(pointer.point.position.x, pointer.point.position.y,
                                root.bubble.width, root.bubble.height, root.surface.width, root.surface.height, Theme.space(12))
        root.bubble.x = at.x
        root.bubble.y = at.y
        root.bubble.visible = true
    }

    Connections {
        target: root.surface.Window.window
        function onActiveChanged() { if (!root.surface.Window.window.active) root.dismiss() }
        function onActiveFocusItemChanged() { root.dismiss() }
    }

    HoverHandler {
        id: pointer
        parent: root.surface
        onPointChanged: root.moved()
        onHoveredChanged: root.moved()
    }
    PointHandler {
        parent: root.surface
        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            root.held = active
            root.hide()
            root.target = null
        }
    }
    Timer {
        id: delay
        interval: root.shown ? 120 : 650
        repeat: true
        onTriggered: {
            if (root.shown) {
                const previous = root.target
                root.updateTarget()
                if (root.target === previous && root.target) {
                    const text = Hints.text(root.target.mouseHint,
                        root.target.hintAction ? Keymap.hintFor(root.target.hintAction) : "")
                    if (text !== root.bubble.text) { root.hide(); root.target = null; root.updateTarget() }
                }
            } else root.show()
        }
    }
    Component.onDestruction: if (root.bubble) root.bubble.destroy()
}
