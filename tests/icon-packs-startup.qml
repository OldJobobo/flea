import QtQuick
import Quickshell
import "flea" as Flea

// The next process must draw the persisted non-default pack, not wait for a settings visit.
Window {
    id: root
    readonly property string expected: Quickshell.env("ICON_PACK_STARTUP") || "tabler"
    width: 120
    height: 80
    visible: true
    Flea.Glyph { id: mark; name: "folder"; width: 24; height: 24 }
    Component.onCompleted: {
        var theme = Flea.ViewState.iconTheme
        var ok = theme.selection === root.expected && theme.pack !== null && theme.error === ""
            && mark.iconPath === theme.pack.icons.folder.path && mark.rounded
            && mark.solidOnly === (root.expected === "phosphor")
        console.log("ICONPACKS STARTUP ok=" + ok)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
}
