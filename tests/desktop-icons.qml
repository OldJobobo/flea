import QtQuick
import Quickshell
import Quickshell.Io
import "flea" as Flea

Window {
    id: root
    width: 940; height: 680; visible: true
    color: Flea.Theme.color.background
    property int phase: 0
    property int checks: 0
    property int failures: 0
    property double started: Date.now()
    property var folder: ({n:"Folder",i:"folder",p:16877,d:true,s:0,m:1})
    property var file: ({n:"Document.txt",i:"text-x-generic",p:420,d:false,s:10,m:1})
    property var missing: ({n:"Missing icon",i:"not-in-theme",p:420,d:false,s:10,m:1})
    property bool captured: false
    property bool capturing: false
    function check(name, ok) {
        root.checks++
        if (!ok) { root.failures++; console.log("DESKTOPICONS FAIL " + name) }
    }
    function next() { root.phase++; root.started = Date.now() }
    function done() {
        console.log("DESKTOPICONS DONE checks=" + root.checks + " failed=" + root.failures)
        Quickshell.execDetached(["kill", String(Quickshell.processId)])
    }
    function choose(id, value) {
        for (var j = 0; j < 20; j++) {
            var index = panel.rows.findIndex(function(row) { return row.id === id })
            if (panel.rows[index].selected === value) return
            panel.activate(index)
        }
        root.check("selector reaches " + value, false)
    }
    function hasTheme(theme) {
        return [list, column, grid, document].every(function(item) {
            return item.desktopDrawn && item.thumbItem.source.toString().indexOf("/" + theme + "/") >= 0
        })
    }
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
    function capture(label) {
        var dir = Quickshell.env("DESKTOP_ICON_CAPTURE_DIR")
        if (!dir || root.captured) return true
        if (!root.capturing) {
            root.capturing = true
            root.contentItem.grabToImage(function(image) {
                root.check("capture " + label, image.saveToFile(dir + "/" + label + ".png"))
                root.captured = true
            })
        }
        return false
    }
    Item {
        id: views; anchors.fill: parent
        Flea.Row { id:list; x:24; y:70; width:420; row:root.folder; hiddenCols:["mode","size","date","kind"] }
        Flea.ColumnRow { id:column; x:24; y:120; width:420; row:root.folder }
        Flea.Row { id:document; x:24; y:170; width:420; row:root.file; hiddenCols:["mode","size","date","kind"] }
        Flea.Row { id:missing; x:24; y:220; width:420; row:root.missing; hiddenCols:["mode","size","date","kind"] }
        Flea.GridTile { id:grid; x:500; y:70; width:250; height:250; row:root.folder }
    }
    Flea.SettingsPanel { id:panel; anchors.fill:parent; section:"display" }
    Process {
        id: changeSystem
        command:["sh","-c","printf 'Blue\\n' > \"$1\"","sh",Quickshell.env("HOME")+"/.local/state/omarchy/current/theme/icons.theme"]
    }
    Timer {
        interval:50; repeat:true; running:true
        onTriggered: {
            if (Date.now()-root.started > 12000) {
                root.check("phase " + root.phase + " finishes",false); stop(); root.done(); return
            }
            if (!Flea.ViewState.initialReadComplete || Flea.ViewState.saveStatus !== "Saved") return
            if (root.phase === 0) {
                if (Quickshell.env("DESKTOP_ICON_REAL_THEME")) {
                    Flea.ViewState.changeSetting("display.fileIconTheme","theme:"+Quickshell.env("DESKTOP_ICON_REAL_THEME"))
                    root.phase=11; root.started=Date.now(); return
                }
                if (Quickshell.env("DESKTOP_ICON_RESTART")) {
                    if (!root.hasTheme("Blue")) return
                    root.check("next process retains named theme",Flea.ViewState.fileIconTheme === "theme:Blue")
                    root.check("next process retains interface pack",Flea.ViewState.iconTheme.selection === "feather")
                    stop(); root.done(); return
                }
                root.check("builtin does not create a resolver",Flea.ViewState.desktopIcons === null)
                root.check("default row census",root.countUnder(list) === 17)
                root.check("default column census",root.countUnder(column) === 15)
                root.check("default grid census",root.countUnder(grid) === 13)
                panel.open(null); root.next(); return
            }
            var service=Flea.ViewState.desktopIcons
            if (!service || !service.ready || service.themes.length < 2) return
            if (root.phase === 1) {
                root.check("installed themes discovered",service.themes.some(function(t){return t.id === "theme:Child"}))
                root.choose("display.iconSet","feather")
                root.choose("display.fileIconTheme","theme:Child")
                root.next(); return
            }
            if (root.phase === 2) {
                if (!list.desktopDrawn || !column.desktopDrawn || !grid.desktopDrawn || !document.desktopDrawn) return
                root.check("folder art in all views",[list,column,grid].every(function(item){return item.thumbItem.source.toString().indexOf("/Child/")>=0}))
                root.check("file inherits parent art",document.thumbItem.source.toString().indexOf("/Parent/")>=0)
                root.check("file URLs encode special root characters",list.thumbItem.source.toString().indexOf("%23")>=0)
                root.check("missing theme icon falls back",!missing.desktopDrawn && missing.desktopIcon === "")
                root.check("themed row adds no objects",root.countUnder(list) === 17)
                root.check("themed column adds no objects",root.countUnder(column) === 15)
                root.check("themed grid adds no objects",root.countUnder(grid) === 13)
                panel.close()
                if (!root.capture("inherited")) return
                root.choose("display.fileIconTheme","theme:Blue")
                root.next(); return
            }
            if (root.phase === 3) {
                if (!root.hasTheme("Blue")) return
                root.check("interface pack remains independent",Flea.ViewState.iconTheme.selection === "feather")
                root.check("file selection switches all views",root.hasTheme("Blue"))
                views.visible=false
                root.choose("display.fileIconTheme","theme:Child")
                root.next(); return
            }
            if (root.phase === 4) {
                if (service.selection !== "theme:Child" || service.busy || Date.now()-root.started<250) return
                root.check("hidden views request no artwork",Object.keys(service.cache).length === 0)
                views.visible=true
                root.choose("display.fileIconTheme","system")
                root.next(); return
            }
            if (root.phase === 5) {
                if (!list.desktopDrawn || list.thumbItem.source.toString().indexOf("/Child/")<0) return
                root.check("system follows Omarchy icons.theme",service.selection === "system")
                changeSystem.running=true
                root.next(); return
            }
            if (root.phase === 6) {
                if (!root.hasTheme("Blue")) return
                root.check("system theme changes reload live",service.systemName === "Blue")
                root.choose("display.fileIconTheme","builtin")
                root.next(); return
            }
            if (root.phase === 7) {
                root.check("builtin restores vector marks",[list,column,grid,document].every(function(item){return !item.desktopDrawn && item.desktopIcon === ""}))
                root.choose("display.fileIconTheme","theme:Blue")
                root.captured=false; root.capturing=false
                root.next(); return
            }
            if (root.phase === 8) {
                if (!root.hasTheme("Blue") || !root.capture("blue")) return
                root.check("grid folder art is capped",grid.thumbItem.sourceSize.width<=128)
                root.check("worker reports no error",service.error === "")
                panel.activate(panel.rows.findIndex(function(row){return row.id === "refreshFileIcons"}))
                root.next(); return
            }
            if (root.phase === 9) {
                if (!root.hasTheme("Blue") || Date.now()-root.started < 5500) return
                root.check("idle worker stays available beyond its request timeout",service.ready && service.error === "")
                root.check("rescan refreshes artwork cache keys",list.thumbItem.source.toString().indexOf("?v=")>=0)
                document.thumb=Quickshell.env("DESKTOP_ICON_THUMB")
                root.next(); return
            }
            if (root.phase === 11) {
                if (service.selection !== "theme:"+Quickshell.env("DESKTOP_ICON_REAL_THEME")) return
                if (![list,column,grid,document].every(function(item){return item.desktopDrawn})) return
                root.check("installed theme renders in every view",[list,column,grid,document].every(function(item){return item.thumbItem.source.toString().indexOf("/usr/share/icons/")>=0}))
                if (!root.capture("installed-"+Quickshell.env("DESKTOP_ICON_REAL_THEME"))) return
                stop(); root.done(); return
            }
            if (root.phase === 10) {
                if (!document.thumbDrawn || document.iconStatus !== Image.Ready) return
                root.check("thumbnails take precedence over theme artwork",document.desktopIcon === "" && document.thumbItem.source.toString().indexOf("folder.png")>=0)
                root.check("thumbnail mode keeps row cost",root.countUnder(document)===17)
                stop(); root.done()
            }
        }
    }
}
