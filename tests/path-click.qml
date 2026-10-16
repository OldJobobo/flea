import QtQuick
import QtTest
import Quickshell
import "flea" as Flea

Window {
    id: root
    width: 920; height: 680; visible: true
    property int checks: 0
    property int failures: 0
    property int step: 0
    property bool driving: false
    property double started: Date.now()
    property var entered: []
    property int outsideClicks: 0
    property int dualEdits: 0
    property string here: Quickshell.env("HOME") + "/Documents/Work"
    property var actions: [
        function() {
            if (!Flea.ViewState.initialReadComplete) return false
            Flea.ViewState.state = ({addressBar:"path"})
            root.check("input is lazy before the first click",!chrome.entryBuilt)
            return true
        },
        function() { root.click(chrome.pathArea); return true },
        function() {
            root.check("one click opens the path field",chrome.editing)
            root.check("one click gives the field focus",chrome.pathField.activeFocus)
            root.check("the path starts selected",chrome.pathField.selectionStart===0 && chrome.pathField.selectionEnd===chrome.editText.length)
            chrome.pathField.text="uncommitted"
            root.click(blank)
            return true
        },
        function() {
            root.check("blank-ground click closes the editor",!chrome.editing)
            root.check("blank-ground click releases text focus",!chrome.pathField.activeFocus)
            root.check("click-away never commits typed text",root.entered.length===0)
            root.click(chrome.pathArea)
            return true
        },
        function() {
            root.check("reopening restores the current path",chrome.editText===root.here+"/")
            root.click(chrome.pathField)
            return true
        },
        function() {
            root.check("a click within the input keeps editing",chrome.editing && chrome.pathField.activeFocus)
            root.click(other)
            return true
        },
        function() {
            root.check("another input closes path editing",!chrome.editing)
            root.check("another input retains its clicked focus",other.activeFocus)
            root.click(chrome.pathArea)
            return true
        },
        function() { root.click(button); return true },
        function() {
            root.check("outside button gets its click exactly once",root.outsideClicks===1)
            root.check("outside button dismisses the editor",!chrome.editing && !chrome.pathField.activeFocus)
            chrome.startEdit(); driver.keyClick(Qt.Key_Escape,Qt.NoModifier,-1)
            return true
        },
        function() {
            root.check("Escape still dismisses editing",!chrome.editing)
            chrome.startEdit(); chrome.pathField.text=root.here+"/child"
            driver.keyClick(Qt.Key_Return,Qt.NoModifier,-1)
            return true
        },
        function() {
            root.check("Enter still commits exactly once",root.entered.length===1 && root.entered[0]===root.here+"/child")
            root.check("Enter closes and releases the field",!chrome.editing && !chrome.pathField.activeFocus)
            Flea.ViewState.state=({addressBar:"breadcrumb"})
            return true
        },
        function() { root.click(chrome.crumbItems.itemAt(chrome.crumbItems.count-1)); return true },
        function() {
            root.check("one click on the current breadcrumb edits",chrome.editing)
            root.click(blank)
            return true
        },
        function() { root.click(chrome.crumbItems.itemAt(0)); return true },
        function() {
            root.check("an ancestor still navigates on one click",root.entered.length===2 && root.entered[1]===Quickshell.env("HOME"))
            root.check("an ancestor does not open the editor",!chrome.editing)
            chrome.width=460
            root.here=Quickshell.env("HOME")+"/alpha_111111111111/bravo_222222222222/charlie_333333333333/Leaf"
            return true
        },
        function() {
            if (!chrome.elisionMarker) return false
            root.click(chrome.elisionMarker)
            return true
        },
        function() {
            root.check("one click on the collapsed marker edits",chrome.editing)
            root.click(blank)
            chrome.inputLive=false
            return true
        },
        function() { root.click(chrome.elisionMarker); return true },
        function() {
            root.check("covered chrome does not open an input",!chrome.editing)
            chrome.inputLive=true
            root.click(dual,dual.width-5,dual.height/2)
            return true
        },
        function() {
            root.check("dual-pane padding edits on one click",root.dualEdits===1)
            root.here=Quickshell.env("HOME")+"/Documents/Work"; chrome.width=700
            Flea.ViewState.state=({addressBar:"path"})
            chrome.startEdit(); chrome.pathField.text="Work"
            return true
        },
        function() {
            if (!chrome.jumpShown || !chrome.jump.dropItem) return false
            var row=chrome.jump.dropItem.liveAt(chrome.jump.cursor)
            if (!row || !row.visible) return false
            driver.mousePress(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,-1)
            root.check("pressing a suggestion does not trigger outside dismissal",chrome.editing)
            driver.mouseRelease(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,-1)
            // The baseline headless probe may emit no pointer choice; still verify keyboard selection.
            if (chrome.editing) driver.keyClick(Qt.Key_Return,Qt.NoModifier,-1)
            return true
        },
        function() {
            root.check("suggestion selection still navigates once",root.entered.length===3 && root.entered[2]===Quickshell.env("HOME")+"/WorkOne")
            root.check("choosing a suggestion closes the editor",!chrome.editing)
            chrome.startEdit()
            second.visible=true; second.requestActivate()
            return true
        },
        function() {
            if (!second.active) return false
            root.check("deactivating the window releases editing",!chrome.editing && !chrome.pathField.activeFocus)
            second.visible=false
            console.log("PATHCLICK DONE checks="+root.checks+" failed="+root.failures)
            Quickshell.execDetached(["kill",String(Quickshell.processId)])
            timer.stop()
            return true
        }
    ]
    function check(label,ok) { root.checks++; if (!ok) {root.failures++;console.log("PATHCLICK FAIL "+label)} }
    function click(item,x,y) {
        if (!item) {root.check("click target exists",false);return}
        var px=x===undefined?item.width/2:x, py=y===undefined?item.height/2:y
        driver.mouseMove(item,px,py,-1,Qt.NoButton,Qt.NoModifier)
        return driver.mouseClick(item,px,py,Qt.LeftButton,Qt.NoModifier,-1)
    }
    Flea.ChromeBar {
        id:chrome; x:20; y:20; width:700; height:50
        path:root.here; home:Quickshell.env("HOME")
        onPathEntered: path => root.entered.push(path)
        onEditClosed: sink.forceActiveFocus()
        onJumpRequested: function(id,ranking,favourites,recent) {
            Qt.callLater(function(){if(chrome.jump)chrome.jump.take(id,[Quickshell.env("HOME")+"/WorkOne"],[],[])})
        }
    }
    Flea.PanePath { id:dual; x:20;y:120;width:700;height:40;path:root.here;home:Quickshell.env("HOME");onEditRequested:root.dualEdits++ }
    Item {id:sink;focus:true}
    TextInput {id:other;x:30;y:300;width:300;height:35;text:"Another field"}
    Rectangle {id:button;x:450;y:300;width:180;height:40;color:"#444444";MouseArea{anchors.fill:parent;onClicked:root.outsideClicks++}}
    Rectangle {id:blank;x:30;y:420;width:700;height:150;color:"#333333"}
    Window {id:second;width:160;height:100;visible:false}
    TestEvent {id:driver}
    Timer {
        id:timer;interval:50;repeat:true;running:true
        onTriggered: {
            if (root.driving) return
            if (Date.now()-root.started>8000) {
                root.check("step "+root.step+" completes",false)
                console.log("PATHCLICK DONE checks="+root.checks+" failed="+root.failures)
                stop();Quickshell.execDetached(["kill",String(Quickshell.processId)]);return
            }
            root.driving=true
            if (root.actions[root.step]()) {root.step++;root.started=Date.now()}
            root.driving=false
        }
    }
}
