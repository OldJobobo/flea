import QtQuick
import Quickshell
import Quickshell.Io
import "flea" as Flea

Window {
    id: root
    width: 1000; height: 560; visible: true
    color: Flea.Theme.color.background
    property int phase: 0
    property int checks: 0
    property int failures: 0
    property double started: Date.now()
    property string firstSource: ""
    property int rendered: 0
    property bool captured: false
    property bool capturing: false
    property var folder: ({n:"Documents",i:"folder",p:16877,d:true,s:0,m:1})
    function check(name, ok) {
        root.checks++
        if (!ok) { root.failures++; console.log("ADAPTIVEICONS FAIL " + name) }
    }
    function next() { root.phase++; root.started = Date.now() }
    function finish() {
        console.log("ADAPTIVEICONS DONE checks=" + root.checks + " failed=" + root.failures)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
    function drawn() { return list.desktopDrawn && column.desktopDrawn && grid.desktopDrawn }
    function countUnder(item) {
        var count = 0, stack = [item]
        while (stack.length) {
            var object = stack.pop(); count++
            var children = object.children || [], resources = object.resources || []
            for (var i=0;i<children.length;i++) stack.push(children[i])
            for (var j=0;j<resources.length;j++) stack.push(resources[j])
        }
        return count - 1
    }
    function capture() {
        var dir = Quickshell.env("ADAPTIVE_ICON_CAPTURE_DIR")
        if (!dir || root.captured) return true
        if (!root.capturing) {
            root.capturing = true
            root.contentItem.grabToImage(function(image) {
                root.check("capture actual Qt artwork", image.saveToFile(dir + "/adaptive-qt.png"))
                root.captured = true
            })
        }
        return false
    }
    Item {
        id: views; anchors.fill:parent
        Flea.Row { id:list; x:24; y:30; width:420; row:root.folder; hiddenCols:["mode","size","date","kind"] }
        Flea.ColumnRow { id:column; x:24; y:80; width:420; row:root.folder }
        Flea.GridTile { id:grid; x:500; y:20; width:250; height:250; row:root.folder }
        Flea.Row { id:file; x:24; y:140; width:420; row:({n:"Photo",i:"image-x-generic",d:false}); hiddenCols:["mode","size","date","kind"] }
        Flea.Row { id:brand; x:24; y:190; width:420; row:({n:"Original app",i:"keep-brand",d:false}); hiddenCols:["mode","size","date","kind"] }
        Row {
            x:500; y:300; spacing:20
            Repeater {
                model:["utilities-terminal","accessories-text-editor","system-file-manager"]
                Image { required property string modelData; width:80; height:80; sourceSize.width:80; sourceSize.height:80
                    source: visible ? Flea.ViewState.fileIconSource({i:modelData},80) : "" }
            }
        }
    }
    Process {
        id: recolor
        command:["sh","-c",'printf "%s\\n" "$2" > "$1"; printf "Daylight\\n" > "$3"',"sh",
            Quickshell.env("HOME")+"/.local/state/omarchy/current/theme/colors.toml",
            'background = "#f4f1eb"\nforeground = "#292d34"\naccent = "#386d94"\nselection = "#d3e2ed"\n',
            Quickshell.env("HOME")+"/.local/state/omarchy/current/theme.name"]
    }
    Timer {
        interval:50; repeat:true; running:true
        onTriggered: {
            if (Date.now()-root.started > 10000) {
                root.check("phase " + root.phase + " finishes",false); stop(); root.finish(); return
            }
            if (!Flea.ViewState.initialReadComplete || Flea.ViewState.saveStatus !== "Saved") return
            var service = Flea.ViewState.adaptiveIcons
            if (root.phase === 0) {
                if (Quickshell.env("ADAPTIVE_ICON_RESTART")) {
                    if (!root.drawn()) return
                    root.check("adaptive choice persists",Flea.ViewState.fileIconTheme === "adaptive")
                    if (Quickshell.env("ADAPTIVE_ICON_SEMANTIC_COLORS") === "1") root.check("semantic mode persists", Flea.ViewState.semanticColors)
                    root.check("restart renders palette SVGs",list.desktopIcon.indexOf("data:image/svg+xml,")===0)
                    stop(); root.finish(); return
                }
                root.check("default is cold",!service && Flea.ViewState.desktopIcons === null)
                if (Quickshell.env("ADAPTIVE_ICON_SEMANTIC_COLORS") === "1") root.check("semantic mode enabled", Flea.ViewState.semanticColors)
                Flea.ViewState.changeSetting("display.fileIconTheme","adaptive")
                root.next(); return
            }
            if (!service) return
            if (root.phase === 1) {
                if (!root.drawn() || !file.desktopDrawn || !brand.desktopDrawn) return
                root.check("shared list and column SVG",list.desktopIcon===column.desktopIcon)
                root.check("small and large artwork differ",list.desktopIcon!==grid.desktopIcon)
                root.check("unsupported brand uses original system file",brand.desktopIcon.indexOf("/Preserve/")>=0)
                root.check("row census stays fixed",root.countUnder(list)===17)
                root.check("column census stays fixed",root.countUnder(column)===15)
                root.check("grid census stays fixed",root.countUnder(grid)===13)
                root.check("cache is shared at the same size",service.source(root.folder,20)===service.source(root.folder,20))
                root.check("different sizes get distinct SVG canvases",service.source(root.folder,48)!==service.source(root.folder,96))
                var before=service.stats.renders
                for (var i=0;i<500;i++) service.source(root.folder,20)
                root.check("repeated rows do not render again",service.stats.renders===before)
                root.check("cache bound",Object.keys(service.cache).length<=128)
                if (!root.capture()) return
                root.firstSource=list.desktopIcon
                views.visible=false
                root.rendered=service.stats.renders
                recolor.running=true
                root.next(); return
            }
            if (root.phase === 2) {
                if (Flea.Theme.palette.accent!=="#386d94" || Date.now()-root.started<250) return
                root.check("hidden views do not generate new artwork",service.stats.renders===root.rendered)
                root.check("palette switch drops cached artwork",Object.keys(service.cache).length===0)
                views.visible=true
                root.next(); return
            }
            if (root.phase === 3) {
                if (!root.drawn() || list.desktopIcon===root.firstSource) return
                root.check("theme file change renders new colours",list.desktopIcon!==root.firstSource)
                list.thumb=Quickshell.env("ADAPTIVE_ICON_THUMB")
                root.next(); return
            }
            if (root.phase === 4) {
                if (!list.thumbDrawn) return
                root.check("thumbnail keeps priority",list.desktopIcon==="")
                Flea.ViewState.desktopIcons.fail()
                root.check("resolver failure cannot remove adaptive art",service.source(root.folder,20).length>0)
                Flea.ViewState.changeSetting("display.fileIconTheme","builtin")
                root.next(); return
            }
            if (root.phase === 5) return
        }
    }
    // The final switch destroys the opt-in service, then reselects it for next-process coverage.
    Timer {
        interval:50; repeat:true; running:root.phase>=5
        onTriggered: {
            if (root.phase===5 && !Flea.ViewState.adaptiveIcons) {
                root.check("leaving adaptive releases service",Flea.ViewState.fileIconTheme==="builtin")
                root.check("builtin restores interface artwork",!column.desktopDrawn)
                list.thumb=""
                Flea.ViewState.changeSetting("display.fileIconTheme","adaptive")
                root.next()
            } else if (root.phase===6 && root.drawn() && Flea.ViewState.saveStatus==="Saved") {
                root.check("adaptive survives resolver failure",root.drawn())
                stop(); root.finish()
            }
        }
    }
}
