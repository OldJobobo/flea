import QtQuick
import "js/IconColors.js" as IconColors
import "js/AdaptiveMarks.js" as Marks
import "js/AdaptiveArtwork.js" as Artwork

// One opt-in service, not an object per delegate. Only visible delegates call source().
QtObject {
    id: root
    readonly property var palette: IconColors.derive(Theme.palette, String(Theme.color.background),
                                                    String(Theme.color.foreground), String(Theme.color.accent))
    property var cache: ({})
    property var order: []
    property var stats: ({ renders: 0 })
    onPaletteChanged: { root.cache = ({}); root.order = [] }

    function source(row, size) {
        var icon = Marks.resolve(row)
        if (!icon) return ""
        var small = size <= 24, key = icon.key + (small ? ":small" : ":large")
        if (root.cache[key] !== undefined) return root.cache[key]
        var url = Artwork.source(icon, root.palette, small)
        // Mutating these objects does not invalidate other rows. A palette swap replaces them.
        if (root.order.length >= 128) delete root.cache[root.order.shift()]
        root.cache[key] = url
        root.order.push(key)
        root.stats.renders++
        return url
    }
}
