import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var actions
    readonly property bool available: actions.brightnessAvailable === true
    readonly property bool serviceBusy: actions.brightnessServiceBusy === true
    readonly property string statusText: actions.brightnessStatus || "No DDC display"

    ColumnLayout {
        id: brightnessContent
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "brightness_6"
            title: "Brightness"
            subtitle: root.available ? root.statusText : "DDC/CI unavailable"
            active: root.available

            ActionChip {
                text: "Refresh"
                icon: "refresh"
                onTriggered: actions.refreshBrightness()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.available
            text: "No controllable DDC display detected"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.subtleText
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: actions.brightnessDisplays

            DisplayBrightness {
                required property var modelData

                display: modelData
                actions: root.actions
            }
        }
    }

    component DisplayBrightness: ColumnLayout {
        required property var display
        required property var actions

        Layout.fillWidth: true
        spacing: Theme.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: Theme.rounding.full
                color: Theme.colors.surfaceContainerHighest

                MaterialIcon {
                    anchors.centerIn: parent
                    name: "desktop_windows"
                    size: 21
                    filled: true
                    iconColor: Theme.colors.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: display.label
                    font.pixelSize: Theme.font.sm
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: display.errorText.length > 0
                        ? display.errorText
                        : display.connector.length > 0 ? display.connector : `i2c-${display.bus}`
                    font.pixelSize: Theme.font.xs
                    color: display.errorText.length > 0 ? Theme.colors.errorColor : Theme.colors.mutedText
                    elide: Text.ElideRight
                }
            }

            StyledText {
                text: display.ready ? `${display.percent}%` : "--"
                font.pixelSize: Theme.font.sm
                font.family: Theme.font.familyMono
                color: display.ready ? Theme.colors.text : Theme.colors.subtleText
            }
        }

        MaterialSlider {
            Layout.fillWidth: true
            visible: display.controllable
            enabled: display.ready
            from: 0
            to: 100
            stepSize: 1
            value: display.percent
            onSetValue: value => actions.setBrightness(display, value)
        }
    }
}
