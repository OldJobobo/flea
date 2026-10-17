import QtQuick
import QtQuick.Shapes

// The caller owns the three-beat cadence. Choreography exists only once this mark is shown.
Item {
    id: root
    property color color: Theme.color.mutedFrame
    readonly property real grid: 24
    readonly property real markScale: Math.min(root.width, root.height) / root.grid
    property bool idleGestures: false
    property real bob: 0
    property int nextGesture: 0
    property string lastGesture: ""
    property var choreography: null
    property bool ready: false
    readonly property bool settled: (!root.choreography || !root.choreography.running)
        && root.opacity === 1 && root.rotation === 0 && root.scale === 1 && root.bob === 0

    transformOrigin: Item.Bottom
    transform: Translate { y: root.bob }

    function motion() {
        if (!root.choreography) {
            var component = Qt.createComponent("TickIdleMotion.qml")
            if (component.status !== Component.Ready) throw new Error(component.errorString())
            root.choreography = component.createObject(root, { mark: root })
        }
        return root.choreography
    }
    function settle() {
        if (root.choreography) root.choreography.stop()
        root.opacity = 1
        root.rotation = 0
        root.scale = 1
        root.bob = 0
    }
    function replay() {
        root.settle()
        if (!root.idleGestures || !root.visible || Theme.reducedMotion) return
        var gesture = ["curious", "hop", "wiggle"][root.nextGesture]
        root.nextGesture = (root.nextGesture + 1) % 3
        root.lastGesture = gesture
        root.motion().play(gesture)
    }
    function appear() {
        root.settle()
        root.nextGesture = 0
        root.lastGesture = root.idleGestures ? "arrival" : ""
        if (root.idleGestures && !Theme.reducedMotion) root.motion().play("arrival")
    }

    Shape {
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
