import QtQuick
import Quickshell
import "flea" as Flea

ShellRoot {
    id: root
    property int checks: 0
    property int failures: 0
    property int step: 0
    property int changes: 0
    property int restedChanges: 0
    property double anchor: Date.now()
    property bool extraTesting: false
    property int extraIndex: 0
    property bool sampled: false
    property double clipStarted: 0
    property double extraStarted: 0
    property bool queueBeatChecked: false
    property bool queueRestChecked: false
    readonly property var extras: ["thinking", "searching", "sleepy", "waving", "surprised", "error"]
    readonly property var extraDurations: [4000, 4000, 6000, 3000, 3000, 3000]
    readonly property var neutral: [0,0,0,1,1,0,0,0]
    function check(label, ok) {
        checks++
        if (!ok) { failures++; console.log("MASCOT FAIL " + label) }
    }
    function capture(name, item) {
        var directory = Quickshell.env("TICK_MASCOT_CAPTURE")
        if (directory) (item || host).grabToImage(function(result) { result.saveToFile(directory + "/" + name + ".png") })
    }
    function allPartsUseInk(start, ink) {
        var seen = [], total = 0, matched = 0
        function walk(object) {
            if (!object || seen.indexOf(object) >= 0) return
            seen.push(object)
            if (object.fillColor !== undefined && object.fillRule !== undefined) {
                total++
                if (String(object.fillColor) === String(ink)) matched++
            }
            var groups = [object.children, object.data, object.resources]
            for (var g = 0; g < groups.length; g++) {
                if (!groups[g]) continue
                for (var i = 0; i < groups[g].length; i++) walk(groups[g][i])
            }
        }
        walk(start)
        return total === 15 && matched === 15
    }
    function startExtra() {
        probe.visible = true
        probe.settle()
        probe.motion().play(root.extras[root.extraIndex])
        root.clipStarted = Date.now()
        root.sampled = false
        root.check("native duration for " + root.extras[root.extraIndex], probe.choreography.duration === root.extraDurations[root.extraIndex])
    }
    function pollExtra() {
        var queueElapsed = Date.now() - root.extraStarted
        if (!root.queueBeatChecked && queueElapsed >= 8450) {
            queuedProbe.replay()
            root.check("third beat does not truncate a long sequence", queuedProbe.lastGesture === "surprised" && !queuedProbe.settled && queuedProbe.pending.join(",") === "error")
            root.queueBeatChecked = true
        }
        if (!root.queueRestChecked && queueElapsed >= 12300) {
            root.check("all queued long clips finish before rest", queuedProbe.lastGesture === "error" && queuedProbe.settled && queuedProbe.pending.length === 0)
            queuedProbe.visible = false
            root.queueRestChecked = true
        }
        var rig = probe.choreography
        var duration = root.extraDurations[root.extraIndex]
        var elapsed = Date.now() - root.clipStarted
        var name = root.extras[root.extraIndex]
        if (!root.sampled && elapsed >= duration * .35) {
            root.check(name + " animates its supplied pose", rig.running && rig.extra && rig.pose.some(function(v, i) { return Math.abs(v - root.neutral[i]) > .001 }))
            root.capture(name, probe)
            root.sampled = true
        }
        if (elapsed >= duration + 180) {
            root.check(name + " ends at exact neutral", rig.settled && rig.phase === 0 && rig.pose.every(function(v, i) { return v === root.neutral[i] }))
            root.extraIndex++
            if (root.extraIndex < root.extras.length) root.startExtra()
            else {
                rig.play("happy-hop")
                root.check("happy-hop alias uses the supplied happy clip", rig.motion === "happy" && rig.duration === 2000)
                rig.play("toString")
                root.check("unknown motion falls back to idle", rig.motion === "idle" && rig.duration === 4000)
                rig.stop()
                probe.visible = false
                root.finish()
            }
        }
    }
    function finish() {
        timer.stop()
        console.log("MASCOT DONE checks=" + checks + " failed=" + failures)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
    FloatingWindow {
        implicitWidth: 460
        implicitHeight: 340
        color: Flea.Theme.color.background
        Item {
            id: host
            anchors.fill: parent
            visible: false
            Rectangle { anchors.fill: parent; color: Flea.Theme.color.background }
            Flea.EmptyState { id: empty; anchors.fill: parent }
        }
        Flea.FleaMark { id: plain; width: 24; height: 24 }
        Flea.FleaMark { id: small; width: 48; height: 49.6; idleGestures: true; visible: false; clip: true }
        Flea.FleaMark { id: queuedProbe; width: 96; height: 99.2; idleGestures: true; visible: false }
        Flea.FleaMark { id: probe; width: 120; height: 124; anchors.centerIn: parent; color: Flea.Theme.color.foreground; idleGestures: true; visible: false; clip: true }
        Flea.EmptyState { id: fixed; anchors.fill: parent; caption: "No matches"; mark: "search"; visible: false }
    }
    Connections {
        target: empty.markItem.choreography
        function onPhaseChanged() { root.changes++ }
    }
    readonly property var plan: [
        [200, function() {
            root.check("hidden mark allocates no rig", empty.markItem.choreography === null)
            plain.replay()
            root.check("other marks stay static", plain.settled && plain.choreography === null)
            Flea.Theme.reducedMotion = false
            host.visible = true
            root.anchor = Date.now()
        }],
        [1000, function() {
            var rig = empty.markItem.choreography
            root.check("arrival plays supplied idle", empty.markItem.lastGesture === "idle" && rig.running && rig.duration === 4000)
            root.check("idle articulates antennae and legs", rig.antennaAmplitude === 2.5 && rig.legAmplitude === 1.5 && rig.phase > 0)
            root.check("idle breathes rather than rotating the whole icon", rig.poseScaleX !== 1 && empty.markItem.rotation === 0)
            root.check("empty-state artwork is larger and uses theme foreground", empty.markItem.width > Flea.Theme.heroMarkSize && empty.markItem.color === Flea.Theme.color.foreground)
            empty.markItem.color = "#336699"
            root.check("all fifteen parts recolor together", root.allPartsUseInk(rig, "#336699"))
            empty.markItem.color = Qt.binding(function() { return Flea.Theme.color.foreground })
            root.capture("idle")
        }],
        [3000, function() {
            root.check("caption beat queues walk without truncating idle", empty.markItem.lastGesture === "idle" && empty.markItem.pending.join(",") === "walk")
        }],
        [4400, function() {
            var rig = empty.markItem.choreography
            root.check("queued walk starts after full idle cycle", empty.markItem.lastGesture === "walk" && rig.running && rig.duration === 1200)
            root.check("walk uses the supplied tripod stride", rig.legAmplitude === 15 && rig.antennaAmplitude === 3.5)
            root.capture("walk")
        }],
        [5350, function() { root.check("walk finishes before the next caption beat", empty.markItem.settled) }],
        [6350, function() {
            var rig = empty.markItem.choreography
            root.check("next beat plays supplied happy hop", empty.markItem.lastGesture === "happy" && rig.running && rig.duration === 2000)
            root.check("hop has articulated legs, lift and tilt", rig.legAmplitude === 9 && rig.poseY < -1 && rig.poseAngle !== 0)
            root.capture("happy")
            small.visible = true
            small.settle()
            small.motion().play("happy")
        }],
        [7050, function() {
            root.check("48px mascot keeps the supplied hop padding", small.choreography.running && small.choreography.poseY < 0 && Math.abs(small.markScale - 1.6) < .001)
            root.capture("small-happy", small)
        }],
        [8000, function() {
            small.visible = false
            var rig = empty.markItem.choreography
            root.check("happy lands at neutral", empty.markItem.settled && rig.phase === 0 && rig.poseY === 0 && rig.poseScaleX === 1)
        }],
        [9300, function() {
            root.check("three caption beats leave mascot at rest", empty.beats === 3 && empty.atRest && empty.markItem.settled)
            root.restedChanges = root.changes
            root.capture("rest")
        }],
        [12300, function() {
            root.check("no perpetual idle loop", root.changes === root.restedChanges && empty.beats === 3)
            host.visible = false
            root.check("hide releases the articulated rig", empty.markItem.choreography === null)
            host.visible = true
            root.check("next appearance advances to the second group", empty.markItem.nextGesture === 1 && empty.markItem.lastGesture === "thinking")
            empty.markItem.replay()
            root.check("searching waits behind thinking", empty.markItem.pending.join(",") === "searching")
            Flea.Theme.reducedMotion = true
            root.check("reduced motion cancels both clip and queue", empty.markItem.settled && empty.markItem.pending.length === 0)
            empty.markItem.replay()
            root.check("reduced motion refuses replay", empty.markItem.settled && !empty.markItem.choreography.running)
            host.visible = false
            host.visible = true
            root.check("reduced-motion appearance allocates no rig", empty.markItem.choreography === null && empty.markItem.settled)
            fixed.visible = true
            root.check("fixed-caption states keep their glyph", fixed.markItem.choreography === null)
            fixed.visible = false
            host.visible = false
            Flea.Theme.reducedMotion = false
            host.visible = true
            root.check("third appearance uses the final group", empty.markItem.lastGesture === "sleepy")
            host.visible = false
            host.visible = true
            root.check("group rotation wraps after all nine", empty.markItem.lastGesture === "idle")
            host.visible = false
            queuedProbe.nextSequence = 6
            queuedProbe.visible = true
            queuedProbe.replay()
            queuedProbe.replay()
            root.extraStarted = Date.now()
            root.extraTesting = true
            root.startExtra()
        }]
    ]
    Timer {
        id: timer
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (root.extraTesting) { root.pollExtra(); return }
            if (root.step < root.plan.length && Date.now() - root.anchor >= root.plan[root.step][0]) {
                root.plan[root.step][1]()
                root.step++
            }
        }
    }
    Timer { interval: 45000; running: true; onTriggered: { root.check("suite completes", false); root.finish() } }
}
