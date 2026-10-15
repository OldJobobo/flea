import QtQuick
import Quickshell.Io
import "js/IconPacks.js" as Packs

// Created only for a selected external pack; data errors replace the whole pack, never half of it.
FileView {
    id: root
    property var answer: ({ pack: null, error: "Loading icon pack. Using Flea icons." })
    blockLoading: true
    printErrors: false
    watchChanges: true
    onLoaded: root.answer = Packs.parse(root.text())
    onLoadFailed: root.answer = ({ pack: null, error: "Could not read icon pack. Using Flea icons." })
    onFileChanged: root.reload()
    Component.onCompleted: {
        var text = root.text()
        if (text.length > 0) root.answer = Packs.parse(text)
    }
}
