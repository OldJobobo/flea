import QtQuick

Rectangle {
    id: root
    property alias text: label.text
    implicitWidth: Math.min(Theme.space(440), label.implicitWidth + 2 * Theme.spacing.rowPaddingX)
    height: label.implicitHeight + 2 * Theme.spacing.rowPaddingY
    visible: false
    color: Theme.color.background
    border.width: Theme.spacing.hairline
    border.color: Theme.color.foreground

    Text {
        id: label
        x: Theme.spacing.rowPaddingX
        y: Theme.spacing.rowPaddingY
        width: Math.max(0, root.width - 2 * x)
        font.family: Theme.font.family
        font.pixelSize: Theme.font.caption
        color: Theme.color.foreground
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 8
        elide: Text.ElideRight
    }
}
