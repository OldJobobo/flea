import QtQuick
import QtQuick.Shapes
import qs.Commons

// One semantic mark, resolved through the selected icon pack and scaled to the slot.
Item {
    id: root

    property string name: "file"
    property color color: "transparent"
    // All packs share the same 24-unit geometry contract.
    readonly property real grid: 24
    // The mark's ceiling. Default is the row and menu mark; a surface drawing a mark alone passes its own.
    property real maxSize: Theme.markSize
    // The min() against the slot is the icon spec's own rule, so a smaller caller slot still wins
    // (the Network "+" at the caption token needs it) and no container can ever enlarge a mark.
    readonly property real markSize: Math.min(root.maxSize, root.width, root.height)
    // Its own name: "scale" would shadow Item.scale, which qmllint flagged.
    readonly property real gridScale: root.markSize / root.grid
    property real strokeWidth: Theme.strokeWidth
    readonly property string iconPath: ViewState.iconTheme.pathFor(root.name)
    readonly property bool rounded: ViewState.iconTheme.rounded(root.name, ViewState.hyprlandIcons && Style.cornerRadius > 0)
    // Expanded filled outlines (Phosphor) reuse the main shape; no extra row objects.
    readonly property bool solidOnly: ViewState.iconTheme.solidOnly(root.name)
    readonly property string filledPath: ViewState.iconTheme.filledFor(root.name)
    // Built the first time a mark names a solid part: a plain glyph owns no object for it, which tests/rowcost.qml counts.
    property Item solid: null
    function syncSolid() {
        if (root.solid === null && root.filledPath.length > 0)
            root.solid = Qt.createComponent("GlyphSolid.qml").createObject(root, { glyph: root })
    }
    // filledPath starts empty, so its first non-empty value, on a build or a reuse, lands here.
    onFilledPathChanged: root.syncSolid()

    // The Shape is sized in grid units pre-transform; Scale's origin defaults to (0,0), so this
    // offset is what re-centers the scaled-down box in root's slot instead of pinning it top-left.
    Shape {
        width: root.grid
        height: root.grid
        x: (root.width - root.markSize) / 2
        y: (root.height - root.markSize) / 2
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: root.gridScale; yScale: root.gridScale }

        ShapePath {
            strokeColor: root.solidOnly ? "transparent" : root.color
            fillColor: root.solidOnly ? root.color : "transparent"
            fillRule: ShapePath.WindingFill
            strokeWidth: root.strokeWidth
            // Selected packs own their edge style; missing marks retain Flea's own recipe.
            capStyle: root.rounded ? ShapePath.RoundCap : ShapePath.SquareCap
            joinStyle: root.rounded ? ShapePath.RoundJoin : ShapePath.MiterJoin
            PathSvg { path: root.iconPath }
        }
    }
}
