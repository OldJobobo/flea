import QtQuick
import QtQuick.Shapes
import "js/Motion.js" as Motion

// Tick's supplied artwork, cleaned and traced; the caller still owns the three-beat cadence.
Item {
    id: root
    property color color: Theme.color.mutedFrame
    readonly property real grid: 24
    readonly property real markScale: Math.min(root.width, root.height) / root.grid
    readonly property bool settled: !arrival.running && root.opacity === 1

    function replay() {
        if (Theme.reducedMotion) root.settle()
        else arrival.restart()
    }
    function settle() { arrival.stop(); root.opacity = 1 }

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
    NumberAnimation {
        id: arrival
        target: root; property: "opacity"; from: 0; to: 1
        duration: Motion.durMs.open
        easing.type: Easing.OutCubic
    }
    onVisibleChanged: if (root.visible) root.replay(); else arrival.stop()
    Component.onCompleted: if (root.visible) root.replay()
    Connections {
        target: Theme
        function onReducedMotionChanged() { if (Theme.reducedMotion) root.settle() }
    }
}
