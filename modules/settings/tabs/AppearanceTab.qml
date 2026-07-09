import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// AppearanceTab — theme + motion settings.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    // --- Theme ---
    SettingsSectionHeader {
        title: "Theme"
    }

    SettingsSegmentedRow {
        label: "Mode"
        value: root.settingsData.themeMode
        options: [
            { label: "Dark", value: "dark" },
            { label: "Light", value: "light" },
            { label: "Auto", value: "auto" }
        ]
        selectedCallback: (val) => root.settingsData.set("themeMode", val)
    }

    SettingsSegmentedRow {
        label: "Preset"
        value: root.settingsData.themeId
        options: [
            { label: "Default", value: "default" },
            { label: "Blue", value: "blue" },
            { label: "Green", value: "green" },
            { label: "Rose", value: "rose" },
            { label: "Amber", value: "amber" },
            { label: "Neutral", value: "neutral" }
        ]
        selectedCallback: (val) => root.settingsData.set("themeId", val)
    }

    // Accent color swatches
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 0
        spacing: 8

        StyledText {
            text: "Accent"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            Layout.preferredWidth: 120
        }

        Repeater {
            model: [
                { hex: "", label: "Default" },
                { hex: "#42a5f5", label: "Blue" },
                { hex: "#66bb6a", label: "Green" },
                { hex: "#f48fb1", label: "Rose" },
                { hex: "#ffc870", label: "Amber" },
                { hex: "#ef5350", label: "Red" },
                { hex: "#ab47bc", label: "Purple" }
            ]

            Rectangle {
                required property var modelData
                width: 28
                height: 28
                radius: 14
                color: String(modelData.hex).length > 0 ? modelData.hex : Theme.colors.presetPrimary
                border.width: root.settingsData.accentColor === String(modelData.hex) ? 3 : 0
                border.color: Theme.colors.text

                Behavior on border.width {
                    NumberAnimation { duration: 120 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsData.set("accentColor", modelData.hex)
                }

                StyledText {
                    anchors.top: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 2
                    text: modelData.label
                    font.pixelSize: 9
                    color: Theme.colors.subtleText
                    visible: false // tooltip only — labels would overflow
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // --- Motion ---
    SettingsSectionHeader {
        title: "Motion"
    }

    SettingsSegmentedRow {
        label: "Animation speed"
        value: root.settingsData.motionSpeed
        options: [
            { label: "Slower", value: "slower" },
            { label: "Normal", value: "normal" },
            { label: "Faster", value: "faster" }
        ]
        selectedCallback: (val) => root.settingsData.set("motionSpeed", val)
    }

    SettingsSliderRow {
        label: "Workspace animation duration"
        value: root.settingsData.workspaceAnimationDuration
        minValue: 0
        maxValue: 800
        stepSize: 10
        unit: "ms"
        valueChangedCallback: (val) => root.settingsData.set("workspaceAnimationDuration", val)
    }

    SettingsSliderRow {
        label: "Quick switch duration"
        value: root.settingsData.workspaceQuickAnimationDuration
        minValue: 0
        maxValue: 500
        stepSize: 10
        unit: "ms"
        valueChangedCallback: (val) => root.settingsData.set("workspaceQuickAnimationDuration", val)
    }

    // Bottom spacer so the last row isn't flush against the card edge
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
    }
}