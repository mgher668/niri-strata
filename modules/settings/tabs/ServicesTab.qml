import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// ServicesTab — real backend availability + paths summary (read-only).
// Reads tool detection from Capture.qml's `tools` property.

ColumnLayout {
    id: root

    required property var settingsData
    property var captureService: null

    spacing: 16
    Layout.fillWidth: true

    // --- Backend Availability ---
    SettingsSectionHeader {
        title: "Backend Availability"
    }

    // Tool rows — each reads from captureService.tools.<name>
    Repeater {
        model: [
            { key: "niri", label: "niri", hint: "Compositor IPC" },
            { key: "wlCopy", label: "wl-copy", hint: "Clipboard" },
            { key: "wfRecorder", label: "wf-recorder", hint: "Screen recording" },
            { key: "slurp", label: "slurp", hint: "Region selection" },
            { key: "pactl", label: "pactl", hint: "Audio monitor" },
            { key: "notifySend", label: "notify-send", hint: "Notifications" }
        ]

        RowLayout {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing.lg
            Layout.rightMargin: Theme.spacing.lg
            spacing: 8

            MaterialIcon {
                name: root.captureService && root.captureService.tools[modelData.key] ? "check_circle" : "cancel"
                size: 18
                iconColor: root.captureService && root.captureService.tools[modelData.key]
                    ? Theme.colors.successColor
                    : Theme.colors.subtleText
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: modelData.label
                    font.pixelSize: Theme.font.sm
                    color: Theme.colors.text
                }

                StyledText {
                    text: modelData.hint
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.subtleText
                }
            }

            StyledText {
                text: root.captureService && root.captureService.tools[modelData.key] ? "available" : "unavailable"
                font.pixelSize: Theme.font.xs
                color: root.captureService && root.captureService.tools[modelData.key]
                    ? Theme.colors.successColor
                    : Theme.colors.subtleText
            }
        }
    }

    // --- Paths ---
    SettingsSectionHeader {
        title: "Paths"
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        spacing: Theme.spacing.md

        StyledText {
            Layout.fillWidth: true
            text: "Settings file"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.text
        }

        StyledText {
            text: root.settingsData.settingsPath
            font.pixelSize: Theme.font.xs
            muted: true
            elide: Text.ElideMiddle
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        spacing: Theme.spacing.md

        StyledText {
            Layout.fillWidth: true
            text: "Niri fragment"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.text
        }

        StyledText {
            text: "~/.config/niri/strata/layout.kdl"
            font.pixelSize: Theme.font.xs
            muted: true
            elide: Text.ElideMiddle
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}