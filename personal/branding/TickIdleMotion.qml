import QtQuick
import QtQuick.Shapes
import "TickParts.js" as Parts
import "TickMotions.js" as Motions

// Adapted from the supplied TickMascot.qml: exact articulated paths and poses,
// one finite cycle per request, with semantic ink instead of fixed-white images.
Item {
    id: root
    required property var mark
    anchors.fill: parent
    property string motion: "idle"
    property real phase: 0
    readonly property bool reducedMotion: Theme.reducedMotion
    readonly property bool running: clock.running
    readonly property bool settled: !root.running || root.reducedMotion || !root.visible
    readonly property real cycle: root.phase * 2 * Math.PI
    readonly property bool walking: root.motion === "walk"
    readonly property bool happy: root.motion === "happy"
    readonly property bool extra: Object.prototype.hasOwnProperty.call(Motions.CLIPS, root.motion)
    readonly property int duration: root.extra ? Motions.CLIPS[root.motion].duration : root.walking ? 1200 : root.happy ? 2000 : 4000
    readonly property real legAmplitude: root.settled || root.extra ? 0 : root.walking ? 15 : root.happy ? 9 : 1.5
    readonly property real antennaAmplitude: root.settled || root.extra ? 0 : root.walking ? 3.5 : root.happy ? 5 : 2.5
    readonly property var pose: root.settled || !root.extra ? [0,0,0,1,1,0,0,0] : root.extraPose(root.phase)
    readonly property var hop: root.hopPose(root.phase)
    readonly property real poseX: root.extra ? root.pose[0] : 0
    readonly property real poseY: root.settled ? 0 : root.extra ? root.pose[1] : root.happy ? root.hop[0] : root.walking ? -.18 + .18 * Math.cos(2 * root.cycle) : -.22 * Math.sin(root.cycle)
    readonly property real poseAngle: root.settled ? 0 : root.extra ? root.pose[2] : root.happy ? root.hop[3] : (root.walking ? 1.7 : .8) * Math.sin(root.cycle)
    readonly property real poseScaleX: root.settled || root.walking ? 1 : root.extra ? root.pose[3] : root.happy ? root.hop[1] : 1 + .012 * Math.sin(root.cycle)
    readonly property real poseScaleY: root.settled || root.walking ? 1 : root.extra ? root.pose[4] : root.happy ? root.hop[2] : 1 - .012 * Math.sin(root.cycle)
    readonly property var legs: [
        {name:"front-left",hx:7.7,hy:11.8,kx:5.7,ky:11.8,offset:0},
        {name:"front-right",hx:16.3,hy:11.8,kx:18.4,ky:11.8,offset:Math.PI},
        {name:"middle-left",hx:6.8,hy:15.3,kx:4.7,ky:15.3,offset:Math.PI},
        {name:"middle-right",hx:17.2,hy:15.3,kx:19.3,ky:15.3,offset:2*Math.PI},
        {name:"back-left",hx:6.5,hy:18.5,kx:4.9,ky:19.2,offset:0},
        {name:"back-right",hx:17.5,hy:18.5,kx:19.1,ky:19.2,offset:Math.PI}
    ]
    readonly property var antennae: [{name:"left",x:10.4,side:-1},{name:"right",x:13.6,side:1}]
    signal finished()

    function stop() { clock.stop(); root.phase = 0 }
    function play(gesture) {
        root.stop()
        root.motion = gesture === "happy-hop" ? "happy"
            : (["idle", "walk", "happy"].indexOf(gesture) >= 0 || Object.prototype.hasOwnProperty.call(Motions.CLIPS, gesture) ? gesture : "idle")
        if (root.visible && !root.reducedMotion) clock.restart()
    }
    function hopPose(t) {
        const keys = [[0,0,1,1,0],[.12,.25,1.06,.94,0],
            [.23,-1.6,.96,1.04,-5],[.40,-2.5,1,1,4],
            [.57,0,1.07,.93,0],[.70,0,.99,1.01,0],[1,0,1,1,0]]
        for (let i = 0; i < keys.length - 1; i++) {
            const a = keys[i], b = keys[i + 1]
            if (t >= a[0] && t <= b[0]) {
                const u = (1 - Math.cos(Math.PI * (t - a[0]) / (b[0] - a[0]))) / 2
                return [a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u,
                    a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u]
            }
        }
        return [0,1,1,0]
    }
    function extraPose(t) {
        const keys = Motions.CLIPS[root.motion].keys
        for (let i = 0; i < keys.length - 1; i++) {
            const a = keys[i], b = keys[i + 1]
            if (t >= a[0] && t <= b[0]) {
                const u = (1 - Math.cos(Math.PI * (t - a[0]) / (b[0] - a[0]))) / 2
                const result = []
                for (let j = 1; j < a.length; j++) result.push(a[j] + (b[j] - a[j]) * u)
                return result
            }
        }
        return [0,0,0,1,1,0,0,0]
    }
    function antennaAngle(side) {
        return root.settled ? 0 : root.extra ? root.pose[side < 0 ? 5 : 6]
            : side * root.antennaAmplitude * Math.sin(root.cycle)
    }
    NumberAnimation {
        id: clock
        target: root; property: "phase"; from: 0; to: 1
        duration: root.duration
        onFinished: { root.phase = 0; root.finished() }
    }
    onVisibleChanged: if (!root.visible) root.stop()
    onReducedMotionChanged: if (root.reducedMotion) root.stop()

    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: root.mark.markScale
        Item {
            width: 24; height: 24
            x: root.poseX
            y: root.poseY
            transform: [
                Rotation { origin.x: 12; origin.y: 15; angle: root.poseAngle },
                Scale { origin.x: 12; origin.y: 15; xScale: root.poseScaleX; yScale: root.poseScaleY }
            ]
            Repeater {
                model: root.legs.length
                delegate: Item {
                    id: leg
                    required property int index
                    readonly property var spec: root.legs[index]
                    readonly property real spread: root.extra ? root.pose[7] * (leg.spec.hx < 12 ? -1 : 1) : 0
                    width: 24; height: 24
                    transform: Rotation { origin.x: leg.spec.hx; origin.y: leg.spec.hy; angle: leg.spread + root.legAmplitude * Math.sin(root.cycle + leg.spec.offset) }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"; fillColor: root.mark.color; fillRule: ShapePath.WindingFill
                            PathSvg { path: Parts.PATHS[leg.spec.name + "-upper"] }
                        }
                    }
                    Item {
                        anchors.fill: parent
                        transform: Rotation { origin.x: leg.spec.kx; origin.y: leg.spec.ky; angle: leg.spread * .5 + root.legAmplitude * .5 * Math.sin(root.cycle + leg.spec.offset + .5) }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: "transparent"; fillColor: root.mark.color; fillRule: ShapePath.WindingFill
                                PathSvg { path: Parts.PATHS[leg.spec.name + "-lower"] }
                            }
                        }
                    }
                }
            }
            Repeater {
                model: root.antennae.length
                delegate: Item {
                    id: antenna
                    required property int index
                    readonly property var spec: root.antennae[index]
                    width: 24; height: 24
                    transform: Rotation { origin.x: antenna.spec.x; origin.y: 6.2; angle: root.antennaAngle(antenna.spec.side) }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"; fillColor: root.mark.color; fillRule: ShapePath.WindingFill
                            PathSvg { path: Parts.PATHS["antenna-" + antenna.spec.name] }
                        }
                    }
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"; fillColor: root.mark.color; fillRule: ShapePath.WindingFill
                    PathSvg { path: Parts.PATHS.body }
                }
            }
        }
    }
}
