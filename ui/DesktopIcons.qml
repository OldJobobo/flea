import QtQuick
import Quickshell
import Quickshell.Io
import "js/FileIcons.js" as FileIcons
import "js/Format.js" as Format

// Created once on demand, never per row. A cold builtin view creates none of this tree.
QtObject {
    id: root
    property string selection: "builtin"
    property var themes: []
    property string systemName: ""
    property string error: ""
    property bool ready: false
    property var cache: ({})
    property var queue: []
    property var requests: ({})
    property int nextId: 0
    property int generation: 0
    property int catalogId: -1
    property bool catalogPending: false
    readonly property bool busy: batch.running || Object.keys(root.requests).length > 0

    function watchDeadline() {
        if (worker.running && (!root.ready || root.catalogPending || root.busy)) deadline.restart()
        else deadline.stop()
    }
    onBusyChanged: root.watchDeadline()
    onCatalogPendingChanged: root.watchDeadline()
    onReadyChanged: root.watchDeadline()

    function reset() {
        root.generation++
        root.queue = []; root.requests = ({}); root.cache = ({})
    }
    function refresh() {
        root.error = ""
        root.reset()
        if (!worker.running) worker.running = true
        else if (root.ready) root.discover()
    }
    function discover() {
        root.catalogId = ++root.nextId
        root.catalogPending = true
        worker.write(JSON.stringify({c: "catalog", id: root.catalogId}) + "\n")
    }
    function source(row, size) {
        if (root.selection === "builtin" || root.error) return ""
        var icon = FileIcons.request(row, size)
        if (!icon) return ""
        var key = FileIcons.key(icon), answer = root.cache[key]
        if (answer !== undefined) return answer || ""
        var selected = root.selection
        Qt.callLater(function() { root.enqueue(icon, selected) })
        return ""
    }
    function enqueue(icon, selection) {
        var key = FileIcons.key(icon)
        if (selection !== root.selection || root.selection === "builtin" || root.cache[key] !== undefined) return
        if (root.queue.length < 256) {
            root.cache[key] = null
            root.queue.push(icon)
            if (root.ready && !batch.running) batch.start()
        }
    }
    function flush() {
        if (!root.ready || root.selection === "builtin" || root.queue.length === 0) return
        var icons = root.queue
        root.queue = []
        var id = ++root.nextId
        var pending = Object.assign({}, root.requests)
        pending[id] = root.selection
        root.requests = pending
        worker.write(JSON.stringify({c: "icons", id: id, theme: root.selection, icons: icons}) + "\n")
    }
    function receive(line) {
        var answer
        try { answer = JSON.parse(line) } catch (_) { root.fail(); return }
        if (answer.error) { root.fail(); return }
        root.watchDeadline()
        if (answer.c === "catalog" && answer.id === root.catalogId) {
            root.catalogPending = false
            root.themes = answer.themes || []; root.systemName = answer.system || ""
            return
        }
        if (answer.c !== "icons" || root.requests[answer.id] !== root.selection || answer.theme !== root.selection) return
        var pending = Object.assign({}, root.requests)
        delete pending[answer.id]
        root.requests = pending
        var next = Object.assign({}, root.cache)
        for (var i = 0; i < answer.icons.length; i++) {
            var icon = answer.icons[i]
            next[FileIcons.key(icon)] = icon.path ? Format.fileUri(icon.path) + "?v=" + root.generation : ""
        }
        var keys = Object.keys(next)
        if (keys.length > 512) {
            for (var k = 0; k < keys.length - 256; k++) delete next[keys[k]]
        }
        root.cache = next
        if (root.queue.length && !batch.running) batch.start()
    }
    function fail() {
        root.error = "Desktop icon themes unavailable. Using interface icons."
        root.catalogPending = false
        root.reset()
    }
    onSelectionChanged: root.reset()

    property Timer deadlineTimer: Timer {
        id: deadline
        interval: 5000
        onTriggered: { worker.running = false; root.fail() }
    }
    property Timer batchTimer: Timer { id: batch; interval: 16; onTriggered: root.flush() }
    property Process child: Process {
        id: worker
        command: [Quickshell.env("FLEA_BIN") || "flea", "--desktop-icons"]
        stdinEnabled: true
        running: true
        onRunningChanged: root.watchDeadline()
        onStarted: {
            root.ready = true
            root.discover()
            if (root.queue.length) batch.start()
        }
        onExited: { root.ready = false; root.fail() }
        stdout: SplitParser { onRead: line => root.receive(line) }
        stderr: StdioCollector { }
    }
    property FileView themeFile: FileView {
        path: root.selection === "system" ? Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/icons.theme" : ""
        watchChanges: root.selection === "system"
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refresh()
    }
}
