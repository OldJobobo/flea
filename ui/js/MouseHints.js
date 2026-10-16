.pragma library

// Walk only the painted item chain under the pointer, never the directory model.
// An overlay wins the hit test, so covered controls cannot advertise a stale hint.
function at(surface, x, y) {
    var item = surface
    var found = null
    for (var depth = 0; item && depth < 64; depth++) {
        if (typeof item.mouseHint === "string" && item.mouseHint.length)
            found = item
        var child = item.childAt(x, y)
        if (!child) break
        var point = child.mapFromItem(item, x, y)
        item = child
        x = point.x
        y = point.y
    }
    return found
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
