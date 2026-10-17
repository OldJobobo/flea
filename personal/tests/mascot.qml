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
    function check(label, ok) {
        checks++
        if (!ok) { failures++; console.log("MASCOT FAIL " + label) }
    }
    function capture(name) {
        var directory = Quickshell.env("TICK_MASCOT_CAPTURE")
        if (directory) host.grabToImage(function(result) { result.saveToFile(directory + "/" + name + ".png") })
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
            Flea.EmptyState { id: empty; anchors.fill: parent }
        }
        Flea.FleaMark { id: plain; width: 24; height: 24 }
        Flea.EmptyState { id: fixed; anchors.fill: parent; caption: "No matches"; mark: "search"; visible: false }
    }
    Connections {
        target: empty.markItem
        function onRotationChanged() { root.changes++ }
        function onScaleChanged() { root.changes++ }
        function onBobChanged() { root.changes++ }
        function onOpacityChanged() { root.changes++ }
    }
    readonly property var plan: [
        [200, function() {
            root.check("hidden mark allocates no choreography", empty.markItem.choreography === null)
            plain.replay()
            root.check("non-empty-state marks remain static and allocation-free", plain.settled && plain.choreography === null)
            Flea.Theme.reducedMotion = false
            host.visible = true
            root.anchor = Date.now()
        }],
        [100, function() { root.check("arrival has a soft pop", empty.markItem.lastGesture === "arrival" && !empty.markItem.settled) }],
        [650, function() { root.check("arrival settles", empty.markItem.settled); root.capture("rest") }],
        [2920, function() { root.check("first caption beat gives a curious tilt", empty.markItem.lastGesture === "curious" && empty.markItem.rotation < 0); root.capture("curious") }],
        [3700, function() { root.check("curious tilt returns to neutral", empty.markItem.settled) }],
        [5770, function() { root.check("second caption beat gives a little hop", empty.markItem.lastGesture === "hop" && empty.markItem.bob < 0); root.capture("hop") }],
        [6400, function() { root.check("hop lands at neutral", empty.markItem.settled) }],
        [8530, function() { root.check("third caption beat gives a wiggle", empty.markItem.lastGesture === "wiggle" && empty.markItem.rotation !== 0); root.capture("wiggle") }],
        [9300, function() {
            root.check("three beats leave the empty state at rest", empty.beats === 3 && empty.atRest && empty.markItem.settled)
            root.restedChanges = root.changes
        }],
        [12300, function() {
            root.check("no perpetual motion after the third beat", root.changes === root.restedChanges && empty.beats === 3)
            empty.markItem.replay()
            Flea.Theme.reducedMotion = true
            root.check("reduced motion interrupts to neutral", empty.markItem.settled)
            empty.markItem.replay()
            root.check("reduced motion refuses replay", empty.markItem.settled && !empty.markItem.choreography.running)
            host.visible = false
            root.check("hide releases choreography", empty.markItem.choreography === null)
            Flea.Theme.reducedMotion = false
            host.visible = true
            root.check("new appearance resets gesture order", empty.markItem.nextGesture === 0 && empty.markItem.lastGesture === "arrival")
            root.anchor = Date.now()
        }],
        [100, function() {
            host.visible = false
            root.check("mid-arrival hide cancels and resets", empty.markItem.choreography === null && empty.markItem.settled)
            Flea.Theme.reducedMotion = true
            host.visible = true
            root.check("reduced-motion appearance stays allocation-free", empty.markItem.choreography === null && empty.markItem.settled)
            fixed.visible = true
            root.check("fixed-caption states never animate the mascot", fixed.markItem.choreography === null)
            root.finish()
        }]
    ]
    Timer {
        id: timer
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (root.step < root.plan.length && Date.now() - root.anchor >= root.plan[root.step][0]) {
                root.plan[root.step][1]()
                root.step++
            }
        }
    }
    Timer { interval: 20000; running: true; onTriggered: { root.check("suite completes", false); root.finish() } }
}
