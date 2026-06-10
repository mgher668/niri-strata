import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var actions
    signal closeRequested()

    readonly property bool active: actions.recordingActive
    readonly property bool selectedModeAvailable: actions.recordingModeAvailable(actions.recordingMode)
    readonly property string modeLabel: actions.recordingMode === "region" ? "Region" : "Current screen"
    readonly property string audioLabel: actions.recordingAudioEnabled
        ? actions.recordingAudioAvailable ? "System audio" : "Silent fallback"
        : "Silent"

    ColumnLayout {
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "radio_button_checked"
            title: "Recording"
            subtitle: actions.recordingStatus
            active: root.active

            IconButton {
                size: 32
                icon: "close"
                label: "Close recording panel"
                showBorder: true
                baseColor: Theme.colors.surfaceContainerLow
                onClicked: root.closeRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            ActionChip {
                Layout.fillWidth: true
                minWidth: 120
                text: "Region"
                icon: "crop_free"
                active: actions.recordingMode === "region"
                enabled: !root.active && actions.regionRecordingAvailable
                onTriggered: actions.setRecordingMode("region")
            }

            ActionChip {
                Layout.fillWidth: true
                minWidth: 120
                text: "Current screen"
                icon: "desktop_windows"
                active: actions.recordingMode === "output"
                enabled: !root.active && actions.currentOutputRecordingAvailable
                onTriggered: actions.setRecordingMode("output")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            ActionChip {
                Layout.fillWidth: true
                minWidth: 120
                text: "Audio"
                icon: "graphic_eq"
                active: actions.recordingAudioEnabled
                enabled: !root.active
                onTriggered: actions.setRecordingAudioEnabled(!actions.recordingAudioEnabled)
            }
        }

        DetailRow {
            label: "Mode"
            value: root.modeLabel
            available: root.selectedModeAvailable
        }

        DetailRow {
            label: "Audio"
            value: root.audioLabel
            available: !actions.recordingAudioEnabled || actions.recordingAudioAvailable
        }

        DetailRow {
            visible: actions.recordingDegradedReason.length > 0
            label: "Degraded"
            value: actions.recordingDegradedReason
            available: false
        }

        DetailRow {
            visible: actions.recordingLastError.length > 0
            label: "Error"
            value: actions.recordingLastError
            available: false
        }
    }

    component DetailRow: RowLayout {
        required property string label
        required property string value
        property bool available: true

        Layout.fillWidth: true
        spacing: Theme.spacing.md

        StyledText {
            Layout.fillWidth: true
            text: label
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            elide: Text.ElideRight
        }

        StyledText {
            Layout.maximumWidth: root.width * 0.58
            text: value
            font.pixelSize: Theme.font.sm
            font.family: Theme.font.familyMono
            color: available ? Theme.colors.text : Theme.colors.subtleText
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
