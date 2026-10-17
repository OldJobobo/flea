import QtQuick
import "js/Motion.js" as Motion

// Short character beats, never a timer or an infinite animation. Destroyed when the mark hides.
Item {
    id: root
    required property var mark
    readonly property bool running: arrival.running || curious.running || hop.running || wiggle.running

    function stop() { arrival.stop(); curious.stop(); hop.stop(); wiggle.stop() }
    function play(gesture) {
        root.stop()
        if (!root.mark.visible || Theme.reducedMotion) return
        if (gesture === "arrival") arrival.restart()
        else if (gesture === "curious") curious.restart()
        else if (gesture === "hop") hop.restart()
        else if (gesture === "wiggle") wiggle.restart()
    }

    ParallelAnimation {
        id: arrival
        NumberAnimation { target: root.mark; property: "opacity"; from: 0; to: 1; duration: Motion.durMs.open; easing.type: Easing.OutCubic }
        NumberAnimation { target: root.mark; property: "scale"; from: 0.9; to: 1; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: root.mark; property: "bob"; from: root.mark.height * 0.04; to: 0; duration: 300; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: curious
        NumberAnimation { target: root.mark; property: "rotation"; to: -7; duration: 180; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 90 }
        NumberAnimation { target: root.mark; property: "rotation"; to: 5; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: root.mark; property: "rotation"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: hop
        NumberAnimation { target: root.mark; property: "scale"; to: 0.94; duration: 90; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root.mark; property: "bob"; to: -root.mark.height * 0.12; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: root.mark; property: "scale"; to: 1.03; duration: 140; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root.mark; property: "bob"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root.mark; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: wiggle
        NumberAnimation { target: root.mark; property: "rotation"; to: -4; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: root.mark; property: "rotation"; to: 4; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: root.mark; property: "rotation"; to: -2; duration: 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: root.mark; property: "rotation"; to: 0; duration: 140; easing.type: Easing.OutCubic }
    }
}
