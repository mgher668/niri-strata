import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var actions
    readonly property bool available: actions.nightModeAvailable === true
    readonly property bool serviceBusy: actions.nightModeBusy === true
    readonly property int minTemperature: actions.nightModeMinTemperature || 2500
    readonly property int maxTemperature: actions.nightModeMaxTemperature || 6500
    readonly property int temperature: actions.nightModeTemperature || maxTemperature
    readonly property string statusText: actions.nightModeStatus || "Backend unavailable"
    readonly property bool enabledState: actions.nightModeEnabled === true

    ColumnLayout {
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "nightlight"
            title: "Night mode"
            subtitle: root.available ? root.statusText : "Color temperature unavailable"
            active: root.enabledState

            ActionChip {
                text: root.enabledState ? "On" : "Off"
                icon: "nightlight"
                active: root.enabledState
                enabled: root.available
                onTriggered: actions.toggleNightMode()
            }

            ActionChip {
                text: "Refresh"
                icon: "refresh"
                onTriggered: actions.refreshNightMode()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.available
            text: "Start the color temperature service to enable these controls"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.subtleText
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            MaterialIcon {
                name: "bedtime"
                size: 20
                filled: root.enabledState
                iconColor: root.enabledState ? Theme.colors.primary : Theme.colors.mutedText
            }

            MaterialSlider {
                Layout.fillWidth: true
                enabled: root.available
                from: root.minTemperature
                to: root.maxTemperature
                stepSize: 50
                value: root.temperature
                onSetValue: value => actions.setNightModeTemperature(value)
            }

            MaterialIcon {
                name: "wb_sunny"
                size: 20
                iconColor: root.enabledState ? Theme.colors.mutedText : Theme.colors.primary
            }
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: `${root.minTemperature}K`
                font.pixelSize: Theme.font.xs
                color: Theme.colors.subtleText
            }

            StyledText {
                text: `${root.temperature}K`
                font.pixelSize: Theme.font.sm
                font.family: Theme.font.familyMono
                color: root.available ? Theme.colors.text : Theme.colors.subtleText
            }

            StyledText {
                Layout.fillWidth: true
                text: `${root.maxTemperature}K`
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Theme.font.xs
                color: Theme.colors.subtleText
            }
        }
    }

}
