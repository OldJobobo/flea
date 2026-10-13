//@ pragma ShellId flea-hinting-comparison
//@ pragma NativeTextRendering
import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    Window {
        id: window
        visible: true
        width: 1180
        height: 780
        title: "Flea — native font hinting comparison"
        color: "#101315"
        readonly property var modes: [Font.PreferDefaultHinting, Font.PreferVerticalHinting, Font.PreferFullHinting]
        readonly property var labels: ["CURRENT / DEFAULT", "VERTICAL", "FULL / PATCH"]
        Column {
            x: 24; y: 20; spacing: 12
            Text {
                text: "FLEA  /  NATIVE FONT HINTING"
                font.family: "monospace"; font.pixelSize: 20
                font.hintingPreference: Font.PreferFullHinting
                color: "#c0caf5"
            }
            Text {
                text: "Maple Mono NF Regular  •  1× display scale  •  native rendering in all three columns"
                font.family: "monospace"; font.pixelSize: 12
                font.hintingPreference: Font.PreferFullHinting
                color: "#a9b1d6"
            }
            Row {
                spacing: 16
                Repeater {
                    model: 3
                    Text {
                        required property int index
                        width: 360
                        height: 30
                        verticalAlignment: Text.AlignBottom
                        text: window.labels[index]
                        font.family: "monospace"; font.pixelSize: 14
                        font.hintingPreference: Font.PreferFullHinting
                        color: index === 2 ? "#7dcfff" : "#a9b1d6"
                    }
                }
            }
            Repeater {
                model: [10, 12, 14, 16, 20]
                Row {
                    id: samples
                    required property int modelData
                    spacing: 16
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 360; height: 110
                            color: "#171824"
                            border.color: index === 2 ? "#345363" : "#292b3b"
                            Text {
                                x: 12; y: 8
                                text: samples.modelData + " px"
                                font.family: "monospace"; font.pixelSize: 10
                                font.hintingPreference: Font.PreferFullHinting
                                color: "#737c9c"
                            }
                            Text {
                                x: 12; y: 27
                                text: "Il1 O0 rn m / [] {}\nREADME.md   notes.txt\n0123456789  1.2 kB"
                                font.family: "monospace"
                                font.pixelSize: samples.modelData
                                font.hintingPreference: window.modes[index]
                                renderType: Text.NativeRendering
                                color: "#c0caf5"
                            }
                        }
                    }
                }
            }
            Text {
                text: "Identical text, font, colors and size. Only hinting differs. Judge the PNG at 100%; results vary by font/display."
                font.family: "monospace"; font.pixelSize: 11
                font.hintingPreference: Font.PreferFullHinting
                color: "#a9b1d6"
            }
        }
    }
}
