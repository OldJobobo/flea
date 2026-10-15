import QtQuick
import Quickshell
import "flea" as Flea
import "flea/js/Icons.js" as Icons

// The next process must draw the persisted non-default pack, not wait for a settings visit.
Window {
    width: 120
    height: 80
    visible: true
    Flea.Glyph { id: mark; name: "folder"; width: 24; height: 24 }
    Component.onCompleted: {
        var ok = Flea.ViewState.iconTheme.selection === "tabler" && Flea.ViewState.iconTheme.pack !== null
            && Flea.ViewState.iconTheme.error === "" && mark.iconPath !== Icons.pathFor("folder") && mark.rounded
        console.log("ICONPACKS STARTUP ok=" + ok)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
}
