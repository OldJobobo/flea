.pragma library
.import "Tabs.js" as Tabs

// Capture an identity, never a strip index: reorder/close may happen while a menu is up.
function capture(pane, index) {
    var item = pane && pane.tabs && pane.tabs.items[index]
    if (!item || !item.tabIdentity) return null
    return { pane: pane, identity: item.tabIdentity,
        path: Tabs.pathAt(pane.tabs, pane.tabs.index, index, pane.path) }
}

function indexOf(context) {
    if (!context) return -1
    var pane = context.pane
    var index = Tabs.resolveMovedTab(pane, context.identity)
    return index >= 0 && Tabs.pathAt(pane.tabs, pane.tabs.index, index, pane.path) === context.path ? index : -1
}

function entries(context) {
    var unavailable = indexOf(context) < 0
    return [
        { action: "tabNew", label: "New tab", glyph: "plus", disabled: unavailable },
        { action: "tabDuplicate", label: "Duplicate tab", glyph: "copy", disabled: unavailable },
        { separator: true },
        { action: "tabClose", label: "Close tab", glyph: "x", disabled: unavailable }
    ]
}

function choose(context, action) {
    var index = indexOf(context)
    if (index < 0) return false
    if (action === "tabNew") Tabs.openNew(context.pane)
    else if (action === "tabDuplicate") Tabs.openNew(context.pane, context.path)
    else if (action === "tabClose") Tabs.closeAt(context.pane, index)
    else return false
    return true
}
