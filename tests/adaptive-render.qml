import QtQuick
import Quickshell
import "flea/js/IconColors.js" as Colors
import "flea/js/AdaptiveMarks.js" as Marks
import "flea/js/AdaptiveArtwork.js" as Artwork
import "testjs/iconpalettes.js" as Fixtures

// Every alias, palette and geometry tier goes through Qt's SVG decoder, not a string check.
Window {
    id: root
    width: 1100; height: 740; visible:true
    property int readyImages: 0
    property int failedImages: 0
    property int ticks: 0
    readonly property int expected: Fixtures.palettes.length * Object.keys(Marks.names).length * 2
    Column {
        Repeater {
            model:Fixtures.palettes
            Rectangle {
                id: strip
                required property var modelData
                width:1100; height:120; color:modelData.background
                readonly property var palette: Colors.derive(modelData, modelData.background, modelData.foreground, modelData.accent)
                Row {
                    Repeater {
                        model:Object.keys(Marks.names)
                        Column {
                            required property string modelData
                            width:36; spacing:8
                            Image {
                                width:20; height:20; sourceSize.width:20; sourceSize.height:20
                                source:Artwork.source(Marks.resolve({i:parent.modelData}),strip.palette,true)
                                onStatusChanged: {
                                    if (status===Image.Ready) root.readyImages++
                                    if (status===Image.Error) root.failedImages++
                                }
                            }
                            Image {
                                width:32; height:32; sourceSize.width:64; sourceSize.height:64
                                source:Artwork.source(Marks.resolve({i:parent.modelData}),strip.palette,false)
                                onStatusChanged: {
                                    if (status===Image.Ready) root.readyImages++
                                    if (status===Image.Error) root.failedImages++
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Timer {
        interval:50; repeat:true; running:true
        onTriggered: {
            root.ticks++
            if (root.readyImages!==root.expected && root.ticks<200) return
            var failed=root.failedImages+(root.expected-root.readyImages)
            console.log("ADAPTIVEICONS DONE checks="+root.readyImages+" failed="+failed)
            stop()
            Quickshell.execDetached(["kill",String(Quickshell.processId)])
        }
    }
}
