import QtQuick
import QtQuick.Shapes

// Static elsewhere; EmptyState opts into the nine supplied articulated moods.
Item {
    id: root
    property color color: Theme.color.mutedFrame
    readonly property real grid: 24
    readonly property real markScale: root.idleGestures ? Math.min(root.width / 30, root.height / 31)
        : Math.min(root.width, root.height) / root.grid
    property bool idleGestures: false
    readonly property var clips: ["idle", "walk", "happy", "thinking", "searching", "waving", "sleepy", "surprised", "error"]
    property int nextSequence: 0
    property int groupOffset: 0
    property int nextGesture: 0
    property string lastGesture: ""
    property var pending: []
    property var choreography: null
    property bool ready: false
    readonly property bool settled: (!root.choreography || !root.choreography.running)
        && root.pending.length === 0 && root.opacity === 1

    function motion() {
        if (!root.choreography) {
            var component = Qt.createComponent("TickIdleMotion.qml")
            if (component.status !== Component.Ready) throw new Error(component.errorString())
            root.choreography = component.createObject(root, { mark: root })
            root.choreography.finished.connect(function() { root.startNext() })
        }
        return root.choreography
    }
    function settle() {
        root.pending = []
        if (root.choreography) root.choreography.stop()
        root.opacity = 1
    }
    function startNext() {
        if (!root.visible || Theme.reducedMotion) { root.settle(); return }
        if (!root.pending.length) return
        var next = root.pending[0]
        root.pending = root.pending.slice(1)
        root.lastGesture = next
        root.motion().play(next)
    }
    function replay() {
        if (!root.idleGestures || !root.visible || Theme.reducedMotion) { root.settle(); return }
        // Three full clips per appearance; caption beats queue rather than truncate.
        if (root.nextGesture >= 3) return
        root.pending = root.pending.concat([root.clips[(root.groupOffset + root.nextGesture) % root.clips.length]])
        root.nextGesture++
        if (!root.choreography || !root.choreography.running) root.startNext()
    }
    function appear() {
        root.settle()
        root.nextGesture = 0
        root.lastGesture = ""
        if (root.idleGestures && !Theme.reducedMotion) {
            root.groupOffset = root.nextSequence
            root.nextSequence = (root.nextSequence + 3) % root.clips.length
            root.replay()
        }
    }

    Shape {
        visible: root.choreography === null
        width: root.grid; height: root.grid
        x: (root.width - root.grid * root.markScale) / 2
        y: (root.height - root.grid * root.markScale) / 2
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: root.markScale; yScale: root.markScale }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color
            fillRule: ShapePath.WindingFill
            PathSvg { path: @PATH@ }
        }
    }
    onVisibleChanged: {
        if (!root.ready) return
        if (root.visible) root.appear()
        else {
            root.settle()
            if (root.choreography) root.choreography.destroy()
            root.choreography = null
            root.nextGesture = 0
        }
    }
    Component.onCompleted: { root.ready = true; if (root.visible) root.appear() }
    Connections {
        target: Theme
        function onReducedMotionChanged() { if (Theme.reducedMotion) root.settle() }
    }
}
