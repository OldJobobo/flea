.pragma library

var BLOCKED = ({})

function inside(item, x, y) {
    return x >= 0 && y >= 0 && x < item.width && y < item.height
}

// childAt() stops at inert Items too: WindowBody's inactive full-window Loaders
// otherwise hide every control. Follow stacking order through transparent wrappers;
// an enabled MouseArea (dialog/menu scrim) still blocks the content underneath.
// Only instantiated, visible UI is inspected, never the directory model.
function pick(item, x, y, inherited, depth) {
    if (!item || item.visible === false || depth > 64) return null
    var hit = inside(item, x, y)
    if (item.clip && !hit) return null
    var hint = inherited
    if (typeof item.mouseHint === "string") hint = item.mouseHint.length ? item : null
    var children = []
    for (var i = 0; i < item.children.length; i++)
        children.push({ item: item.children[i], order: i })
    children.sort(function(a, b) { return b.item.z - a.item.z || b.order - a.order })
    for (var j = 0; j < children.length; j++) {
        var child = children[j].item
        if (child.visible === false) continue
        var point = child.mapFromItem(item, x, y)
        var found = pick(child, point.x, point.y, hit ? hint : null, depth + 1)
        if (found) return found
    }
    if (!hit) return null
    if (hint) return hint
    // MouseArea exposes both properties; decorative Items and inactive Loaders do not.
    if (item.enabled !== false && item.mouseHintPassthrough !== true
            && item.acceptedButtons !== undefined && item.hoverEnabled !== undefined)
        return BLOCKED
    return null
}

function at(surface, x, y) {
    var found = pick(surface, x, y, null, 0)
    return found === BLOCKED ? null : found
}

function position(x, y, width, height, boundsWidth, boundsHeight, gap) {
    return {
        x: Math.max(0, Math.min(x + gap, boundsWidth - width)),
        y: y + gap + height <= boundsHeight ? y + gap : Math.max(0, y - height - gap)
    }
}

function text(label, shortcut) {
    return shortcut ? label + "  ·  " + shortcut : label
}
