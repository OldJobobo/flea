//@ pragma ShellId flea-semantic-state-test
import QtQuick
import Quickshell
import "flea" as Flea

// Two real ViewState instances share a guarded ui.json, not in-memory test state.
ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 400) { console.log("SEMANTIC_STATE FAIL timeout phase=" + test.phase); Qt.exit(1); return }
            if (test.phase === 0) {
                if (!Flea.ViewState.initialReadComplete) return
                if (Flea.ViewState.semanticColors) { console.log("SEMANTIC_STATE FAIL expected initial off"); Qt.exit(1); return }
                console.log("SEMANTIC_STATE READY")
                test.phase = 1
                if (Quickshell.env("SEMANTIC_WRITER") === "1") Flea.ViewState.changeLeaf("display", {semanticColors: true})
            } else if (test.phase === 1 && Flea.ViewState.semanticColors) {
                console.log("SEMANTIC_STATE ON")
                test.phase = 2
            } else if (test.phase === 2 && !Flea.ViewState.semanticColors) {
                console.log("SEMANTIC_STATE OFF DONE")
                Qt.exit(0)
            }
        }
    }
}
