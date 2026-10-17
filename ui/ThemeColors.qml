import QtQuick
import qs.Commons as Commons
import "js/Contrast.js" as Contrast
import "js/Material.js" as Material
import "js/SemanticColors.js" as SemanticColors

// Palette roles stay opaque; the default mode's text lift is computed once per palette, alpha or focus change.
QtObject {
    id: root
    required property real textContrast
    required property real hueFloor
    readonly property color background: Commons.Color.background
    readonly property color foreground: root.material.foreground
    property color opaqueForegroundBright: Commons.Color.foreground
    property color foregroundBright: Contrast.ratio(String(root.opaqueForegroundBright), String(root.background)) > Contrast.ratio(String(root.foreground), String(root.background)) ? root.opaqueForegroundBright : root.foreground
    property color opaqueMuted: Qt.darker(Commons.Color.foreground, 1.4)
    property color muted: root.material.muted
    property color opaqueMutedFrame: Qt.darker(Commons.Color.foreground, 1.4)
    property color mutedFrame: root.modeInk(root.opaqueMutedFrame, 3)
    property color opaqueMetadata: Qt.darker(Commons.Color.foreground, 1.4)
    property color metadata: root.material.metadata
    property color opaqueMetadataFrame: Qt.darker(Commons.Color.foreground, 1.4)
    property color metadataFrame: root.modeInk(root.opaqueMetadataFrame, 3)
    readonly property color accent: root.modeInk(Commons.Color.accent, 3)
    property color opaqueError: Commons.Color.urgent
    property color error: root.modeInk(root.opaqueError, root.textContrast, root.muted)
    property color opaqueErrorOnSurface: Commons.Color.urgent
    property color errorOnSurface: root.modeInk(root.opaqueErrorOnSurface, root.textContrast, root.muted)
    property color surface: Theme.fallbackColor.surface
    property color opaqueSymlink: Theme.fallbackColor.symlink
    property color symlink: root.modeInk(root.opaqueSymlink, root.textContrast)
    property color opaqueExecutable: Theme.fallbackColor.executable
    property color executable: root.modeInk(root.opaqueExecutable, root.textContrast)
    property color opaqueAccentFrame: Commons.Color.accent
    property color accentFrame: root.modeInk(root.opaqueAccentFrame, 3)
    property bool accentHasHue: Commons.Color.accent.hsvSaturation > root.hueFloor
    readonly property var opaquePalette: ({background: root.background, surface: root.surface,
        foreground: Commons.Color.foreground, muted: root.opaqueMuted, metadata: root.opaqueMetadata})
    readonly property var modePalette: Object.assign({}, root.opaquePalette, {blurBrightness: Glass.mode === "glassy" ? 0.75 : 1})
    readonly property var material: Glass.on && Glass.usesDefault ? Material.inks(root.modePalette, Math.round(Glass.alpha * 255), root.textContrast) : root.opaquePalette
    readonly property var semantic: ViewState.semanticColors
        ? SemanticColors.inks(Theme.palette, Commons.Color.accent, root.modePalette,
            Glass.on && Glass.usesDefault ? Math.round(Glass.alpha * 255) : 255, root.textContrast)
        : ({ text: {}, frame: {} })
    function semanticInk(role, fallback, frame) {
        var roles = frame === true ? root.semantic.frame : root.semantic.text
        return roles[role] || fallback
    }
    function fileInk(row, active, fallback) {
        if (!ViewState.semanticColors || active) return fallback
        var role = SemanticColors.fileRole(row)
        if (role === "symlink") return root.symlink
        if (role === "executable") return root.executable
        return root.semanticInk(role, fallback)
    }
    function modeInk(ink, need, quiet) {
        return Glass.on && Glass.usesDefault ? Material.liftInk(ink, root.modePalette, Math.round(Glass.alpha * 255), need, quiet) : ink
    }
}
