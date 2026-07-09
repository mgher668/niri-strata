import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// CaptureTab — recording + screenshot settings.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    // --- Recording section ---
    SettingsSectionHeader {
        title: "Recording"
    }

    // Save directory — read-only display (path input deferred).
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.md

        StyledText {
            Layout.fillWidth: true
            text: "Save directory"
            font.pixelSize: Theme.font.md
            color: Theme.colors.text
        }

        StyledText {
            Layout.alignment: Qt.AlignRight
            text: root.settingsData.recordingSaveDir.length > 0
                ? root.settingsData.recordingSaveDir
                : "(home directory)"
            font.pixelSize: Theme.font.sm
            muted: true
        }
    }

    SettingsSegmentedRow {
        label: "Default mode"
        value: root.settingsData.recordingDefaultMode
        options: [
            { label: "Focused output", value: "output" },
            { label: "Region", value: "region" }
        ]
        selectedCallback: (val) => root.settingsData.set("recordingDefaultMode", val)
    }

    SettingsToggleRow {
        label: "Record audio"
        checked: root.settingsData.recordingAudioEnabled
        toggleCallback: (val) => root.settingsData.set("recordingAudioEnabled", val)
    }

    // --- Screenshot section ---
    SettingsSectionHeader {
        title: "Screenshot"
    }

    SettingsSegmentedRow {
        label: "Default action"
        value: root.settingsData.screenshotDefaultAction
        options: [
            { label: "Copy to clipboard", value: "copy" },
            { label: "Save to file", value: "save" }
        ]
        selectedCallback: (val) => root.settingsData.set("screenshotDefaultAction", val)
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}