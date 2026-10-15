pragma Singleton
import QtQuick

// Tick bundles are updated transactionally by tick-dev, never by the stock package updater.
QtObject {
    id: root
    property var status: ({ state: "idle" })
    readonly property string menuVersion: ""
    property var asker: null
    property bool polling: false
    function say(pane, words) { if (pane) pane.message(words[0], words[1]) }
    function activate(pane) { root.launch(pane) }
    function launch(pane) { root.say(pane, ["Build and promote Tick with personal/tick-dev.", false]) }
    function check() {}
    function checkIfDue() {}
    function startPolling() {}
}
