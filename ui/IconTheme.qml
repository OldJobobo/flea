import QtQuick
import Quickshell
import "js/IconPacks.js" as Packs

// One pack per process, shared by existing viewport delegates. The default creates no reader.
QtObject {
    id: root
    property string requested: "flea"
    readonly property string selection: Packs.selected(root.requested)
    property var reader: null
    property bool initialized: false
    property string loadError: ""
    readonly property var pack: root.reader ? root.reader.answer.pack : null
    readonly property string error: root.reader ? root.reader.answer.error : root.loadError

    function pathFor(name) { return Packs.pathFor(root.pack, name) }
    function filledFor(name) { return Packs.filledFor(root.pack, name) }
    function solidOnly(name) { return Packs.solidOnly(root.pack, name) }
    function rounded(name, fallback) { return Packs.rounded(root.pack, name, fallback) }

    function load() {
        var previous = root.reader
        root.reader = null
        if (previous) previous.destroy()
        root.loadError = ""
        if (root.selection === "flea") return
        var path = root.selection !== "custom" ? Qt.resolvedUrl("icons/" + root.selection + ".json").toString()
            : (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/flea/icons/custom.json"
        var component = Qt.createComponent("IconPackFile.qml")
        if (component.status !== Component.Ready) {
            console.warn("Icon pack reader: " + component.errorString())
            root.loadError = "Could not load icon pack. Using Flea icons."
            return
        }
        root.reader = component.createObject(root, { path: path })
        if (!root.reader) root.loadError = "Could not load icon pack. Using Flea icons."
    }
    onSelectionChanged: if (root.initialized) root.load()
    Component.onCompleted: { root.initialized = true; root.load() }
}
