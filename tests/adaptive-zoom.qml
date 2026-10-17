import QtQuick
import Quickshell
import "flea" as Flea
import "flea/js/Density.js" as Density

// The same persisted thumbnail stops Ctrl+wheel sets, measured on real rendered Images.
Window {
    id: root
    width:1300; height:440; visible:true
    color:Flea.Theme.color.background
    property var stops:["small","medium","large","xlarge","huge","largest","huge","xlarge","large","medium","small"]
    property int index:0
    property string selection:"adaptive"
    property bool changing:false
    property double started:Date.now()
    property int checks:0
    property int failures:0
    readonly property int pixels:Flea.ViewState.thumbnailPixels
    function check(name,ok) {
        root.checks++
        if (!ok) { root.failures++; console.log("ADAPTIVEICONS FAIL "+name) }
    }
    function done() {
        console.log("ADAPTIVEICONS DONE checks="+root.checks+" failed="+root.failures)
        Quickshell.execDetached(["kill",String(Quickshell.processId)])
    }
    Row {
        spacing:16
        Flea.GridTile { id:folder; width:root.pixels+24; height:root.pixels+80; row:({n:"Folder",i:"folder",d:true}) }
        Flea.GridTile { id:file; width:root.pixels+24; height:root.pixels+80; row:({n:"Text",i:"text-x-generic",d:false}) }
        Flea.GridTile { id:brand; width:root.pixels+24; height:root.pixels+80; row:({n:"App",i:"keep-brand",d:false}) }
        Flea.GridTile { id:photo; width:root.pixels+24; height:root.pixels+80; row:({n:"Photo",i:"image-x-generic",d:false}); thumb:Quickshell.env("ADAPTIVE_ICON_THUMB") }
    }
    Timer {
        interval:50; repeat:true; running:true
        onTriggered: {
            if (Date.now()-root.started>12000) { root.check("zoom stop settles",false);stop();root.done();return }
            if (!Flea.ViewState.initialReadComplete || Flea.ViewState.saveStatus!=="Saved") return
            if (!root.changing) {
                Flea.ViewState.changeSetting("display.fileIconTheme",root.selection)
                Flea.ViewState.changeSetting("preview.thumbSize",root.stops[root.index])
                root.changing=true;root.started=Date.now();return
            }
            if (Date.now()-root.started<150 || !brand.desktopDrawn || !photo.thumbDrawn) return
            if (root.selection==="adaptive" && (!folder.desktopDrawn || !file.desktopDrawn)) return
            var cap=root.selection==="adaptive" ? root.pixels : Density.glyphCap(root.pixels)
            var tiles=root.selection==="adaptive" ? [folder,file,brand] : [brand]
            tiles.forEach(function(tile) {
                var image=tile.thumbItem
                console.log("ZOOM "+root.selection+" "+root.stops[root.index]+" "+tile.row.n+" painted="+image.paintedWidth+" decode="+image.sourceSize.width)
                root.check(root.stops[root.index]+" "+tile.row.n+" drawn width follows zoom",Math.abs(image.paintedWidth-cap)<1)
                root.check(root.stops[root.index]+" "+tile.row.n+" decode matches mode size",image.sourceSize.width===cap)
                root.check(root.stops[root.index]+" "+tile.row.n+" intrinsic raster follows zoom",Math.abs(image.implicitWidth-cap)<1)
            })
            root.check(root.stops[root.index]+" thumbnail follows full slot",Math.abs(photo.thumbItem.paintedWidth-root.pixels)<1)
            root.check(root.stops[root.index]+" thumbnail keeps priority",photo.desktopIcon==="")
            if (++root.index===root.stops.length) {
                if (root.selection==="adaptive") {root.selection="system";root.index=0}
                else {stop();root.done();return}
            }
            root.changing=false;root.started=Date.now()
        }
    }
}
