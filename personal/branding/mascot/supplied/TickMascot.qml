import QtQuick 2.15

// Exact source vectors; animation is native Qt Quick, not SVG SMIL.
Item {
    id: root
    implicitWidth: 240
    implicitHeight: 248
    // idle, walk, happy (or happy-hop), thinking, searching, sleepy, waving, surprised, error.
    // All modes loop; settle() restores the exact resting vector pose.
    property string motion: "idle"
    property bool running: true
    property bool reducedMotion: false
    property color backgroundColor: "#202326" // "transparent" for an overlay
    property real phase: 0
    readonly property bool settled: !running || reducedMotion
    function replay() { phaseAnimation.stop(); phase = 0; running = true;
        if (!reducedMotion && visible) phaseAnimation.restart(); }
    function settle() { running = false; phase = 0; }
    onRunningChanged: { if (!running) phase = 0; }
    onReducedMotionChanged: { if (reducedMotion) phase = 0; }
    readonly property real tau: 2 * Math.PI
    readonly property real cycle: phase * tau
    readonly property bool walking: motion === "walk"
    readonly property bool happy: motion === "happy" || motion === "happy-hop"
    readonly property var hop: hopPose(phase)
    function hopPose(t) {
        const keys = [[0,0,1,1,0],[.12,.25,1.06,.94,0],
                      [.23,-1.6,.96,1.04,-5],[.40,-2.5,1,1,4],
                      [.57,0,1.07,.93,0],[.70,0,.99,1.01,0],[1,0,1,1,0]];
        for (let i=0; i<keys.length-1; ++i) {
            const a=keys[i], b=keys[i+1];
            if (t >= a[0] && t <= b[0]) {
                const u=(1-Math.cos(Math.PI*(t-a[0])/(b[0]-a[0])))/2;
                return [a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u,
                        a[3]+(b[3]-a[3])*u,a[4]+(b[4]-a[4])*u];
            }
        }
        return [0,1,1,0];
    }
    readonly property var extraKeys: ({"thinking": [[0, 0, 0, 0, 1, 1, 0, 0, 0], [0.18, 0, 0, -7, 1, 1, -9, -2, 0], [0.34, 0, 0, -7, 1, 1, -3, 3, 0], [0.48, 0, 0, -7, 1, 1, -10, -2, 0], [0.65, 0, 0, -4, 1, 1, -5, 2, 0], [0.84, 0, 0, 2, 1, 1, 2, -2, 0], [1, 0, 0, 0, 1, 1, 0, 0, 0]], "searching": [[0, 0, 0, 0, 1, 1, 0, 0, 0], [0.17, -0.45, 0, -6, 1, 1, -12, -6, 0], [0.32, -0.45, 0, -6, 1, 1, -16, -2, 0], [0.55, 0.45, 0, 6, 1, 1, 6, 12, 0], [0.7, 0.45, 0, 6, 1, 1, 2, 16, 0], [0.9, 0, 0, 0, 1, 1, 0, 0, 0], [1, 0, 0, 0, 1, 1, 0, 0, 0]], "sleepy": [[0, 0, 0, 0, 1, 1, 0, 0, 0], [0.16, 0, 0.3, 2, 1.015, 0.98, -7, 7, 2], [0.35, 0, 0.65, 5, 1.035, 0.945, -17, 17, 4], [0.5, 0, 0.5, 5, 1.02, 0.965, -15, 15, 3], [0.67, 0, 0.65, 5, 1.035, 0.945, -17, 17, 4], [0.84, 0, 0.35, 3, 1.015, 0.98, -8, 8, 2], [1, 0, 0, 0, 1, 1, 0, 0, 0]], "waving": [[0, 0, 0, 0, 1, 1, 0, 0, 0], [0.15, 0, 0, -3, 1, 1, -2, 18, 0], [0.25, 0, 0, -3, 1, 1, -2, -15, 0], [0.36, 0, 0, -3, 1, 1, -2, 22, 0], [0.47, 0, 0, -3, 1, 1, -2, -15, 0], [0.58, 0, 0, -3, 1, 1, -2, 22, 0], [0.72, 0, 0, -2, 1, 1, 0, 8, 0], [0.88, 0, 0, 0, 1, 1, 0, 0, 0], [1, 0, 0, 0, 1, 1, 0, 0, 0]], "surprised": [[0, 0, 0, 0, 1, 1, 0, 0, 0], [0.13, 0, 0, 0, 1, 1, 0, 0, 0], [0.2, 0, -0.9, 0, 0.94, 1.07, 12, -12, -9], [0.34, 0, -0.65, 0, 0.96, 1.04, 9, -9, -6], [0.52, 0, 0.1, 0, 1.035, 0.965, -5, 5, 3], [0.7, 0, 0, 0, 1, 1, 0, 0, 0], [1, 0, 0, 0, 1, 1, 0, 0, 0]], "error": [[0, 0, 0, 0, 1, 1, 0, 0, 0], [0.16, -0.25, 0, -6, 1, 1, 5, 5, 0], [0.27, 0.25, 0, 6, 1, 1, -5, -5, 0], [0.38, -0.22, 0, -5, 1, 1, 4, 4, 0], [0.49, 0.18, 0, 4, 1, 1, -3, -3, 0], [0.6, -0.1, 0, -2, 1, 1, 2, 2, 0], [0.74, 0, 0, 0, 1, 1, 0, 0, 0], [1, 0, 0, 0, 1, 1, 0, 0, 0]]})
    readonly property var extraDurations: ({"thinking": 4000, "searching": 4000, "sleepy": 6000, "waving": 3000, "surprised": 3000, "error": 3000})
    readonly property bool extra: extraKeys[motion] !== undefined
    readonly property var pose: settled || !extra ? [0,0,0,1,1,0,0,0] : extraPose(phase)
    function extraPose(t) {
        const keys = extraKeys[motion];
        for (let i=0; i<keys.length-1; ++i) {
            const a=keys[i], b=keys[i+1];
            if (t >= a[0] && t <= b[0]) {
                const u=(1-Math.cos(Math.PI*(t-a[0])/(b[0]-a[0])))/2;
                let result=[];
                for (let j=1; j<a.length; ++j) result.push(a[j]+(b[j]-a[j])*u);
                return result;
            }
        }
        return [0,0,0,1,1,0,0,0];
    }
    onMotionChanged: {
        phase = 0;
        if (running && !reducedMotion && visible) phaseAnimation.restart();
    }
    NumberAnimation on phase {
        id: phaseAnimation
        from: 0; to: 1
        duration: root.extra ? root.extraDurations[root.motion] : root.walking ? 1200 : root.happy ? 2000 : 4000
        loops: Animation.Infinite
        running: root.running && !root.reducedMotion && root.visible
    }
    Rectangle { anchors.fill: parent; radius: Math.min(width,height)*.13; color: root.backgroundColor }
    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width / 30, root.height / 31)
        Item {
            width: 24; height: 24
            x: root.extra ? root.pose[0] : 0
            y: root.settled ? 0 : root.extra ? root.pose[1] : root.happy ? root.hop[0] : root.walking ? -.18+.18*Math.cos(2*root.cycle) : -.22*Math.sin(root.cycle)
            transform: [
                Rotation { origin.x: 12; origin.y: 15; angle: root.settled ? 0 : root.extra ? root.pose[2] : root.happy ? root.hop[3] : (root.walking ? 1.7 : .8)*Math.sin(root.cycle) },
                Scale { origin.x: 12; origin.y: 15
                    xScale: root.settled || root.walking ? 1 : root.extra ? root.pose[3] : root.happy ? root.hop[1] : 1+.012*Math.sin(root.cycle)
                    yScale: root.settled || root.walking ? 1 : root.extra ? root.pose[4] : root.happy ? root.hop[2] : 1-.012*Math.sin(root.cycle)
                }
            ]
            Repeater {
                model: [
                    {name:"front-left", hx:7.7, hy:11.8, kx:5.7, ky:11.8, offset:0},
                    {name:"front-right",hx:16.3,hy:11.8,kx:18.4,ky:11.8,offset:Math.PI},
                    {name:"middle-left",hx:6.8,hy:15.3,kx:4.7,ky:15.3,offset:Math.PI},
                    {name:"middle-right",hx:17.2,hy:15.3,kx:19.3,ky:15.3,offset:2*Math.PI},
                    {name:"back-left",hx:6.5,hy:18.5,kx:4.9,ky:19.2,offset:0},
                    {name:"back-right",hx:17.5,hy:18.5,kx:19.1,ky:19.2,offset:Math.PI}
                ]
                delegate: Item {
                    id: leg
                    width: 24; height: 24
                    property var spec: modelData
                    property real spread: root.extra ? root.pose[7]*(spec.hx < 12 ? -1 : 1) : 0
                    property real amplitude: root.settled || root.extra ? 0 : root.walking ? 15 : root.happy ? 9 : 1.5
                    transform: Rotation { origin.x: leg.spec.hx; origin.y: leg.spec.hy; angle: leg.spread + leg.amplitude*Math.sin(root.cycle+leg.spec.offset) }
                    Image { anchors.fill: parent; source: "assets/"+leg.spec.name+"-upper.svg"; sourceSize.width: Math.max(48, root.width * 2); sourceSize.height: Math.max(48, root.width * 2); smooth: true }
                    Item {
                        anchors.fill: parent
                        transform: Rotation { origin.x: leg.spec.kx; origin.y: leg.spec.ky; angle: leg.spread*.5 + leg.amplitude*.5*Math.sin(root.cycle+leg.spec.offset+.5) }
                        Image { anchors.fill: parent; source: "assets/"+leg.spec.name+"-lower.svg"; sourceSize.width: Math.max(48, root.width * 2); sourceSize.height: Math.max(48, root.width * 2); smooth: true }
                    }
                }
            }
            Repeater {
                model: [{name:"left",x:10.4,side:-1},{name:"right",x:13.6,side:1}]
                delegate: Item {
                    id: antenna
                    width: 24; height: 24
                    property var spec: modelData
                    transform: Rotation { origin.x: antenna.spec.x; origin.y: 6.2; angle: root.settled ? 0 : root.extra ? root.pose[antenna.spec.side < 0 ? 5 : 6] : antenna.spec.side*(root.walking ? 3.5 : root.happy ? 5 : 2.5)*Math.sin(root.cycle) }
                    Image { anchors.fill: parent; source:"assets/antenna-"+antenna.spec.name+".svg"; sourceSize.width: Math.max(48, root.width * 2); sourceSize.height: Math.max(48, root.width * 2); smooth:true }
                }
            }
            Image { anchors.fill:parent; source:"assets/body.svg"; sourceSize.width: Math.max(48, root.width * 2); sourceSize.height: Math.max(48, root.width * 2); smooth:true }
        }
    }
}
