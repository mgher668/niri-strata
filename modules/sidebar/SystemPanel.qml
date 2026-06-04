import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var actions
    readonly property string pendingAction: actions.pendingSessionAction || ""

    ColumnLayout {
        id: systemContent
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "settings"
            title: "System"
            subtitle: root.pendingAction.length > 0 ? `Confirm ${root.pendingAction}` : "Session and device controls"
            active: root.pendingAction.length > 0
        }

        StatusRow {
            label: "Brightness"
            value: actions.brightnessStatus
            available: actions.brightnessAvailable
        }

        StatusRow {
            label: "Night mode"
            value: actions.nightModeStatus
            available: actions.nightModeAvailable
        }

        StatusRow {
            label: "Power profile"
            value: actions.powerProfileStatus
            available: actions.powerProfileAvailable
        }

        RowLayout {
            Layout.fillWidth: true
            visible: actions.powerProfiles.length > 0
            spacing: Theme.spacing.md

            Repeater {
                model: actions.powerProfiles

                ActionPill {
                    required property var modelData

                    label: modelData.name
                    active: modelData.active || modelData.name === actions.powerProfileStatus
                    onTriggered: actions.setPowerProfile(modelData.name)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing.md
            rowSpacing: Theme.spacing.md

            ActionTile {
                icon: "screenshot_region"
                label: "Screenshot"
                detail: actions.screenshotStatus
                enabled: actions.screenshotAvailable
                onTriggered: actions.takeScreenshot()
            }

            ActionTile {
                icon: "radio_button_checked"
                label: "Record"
                detail: actions.recordingStatus
                active: actions.recordingActive
                enabled: actions.recordingAvailable
                onTriggered: actions.toggleRecording()
            }

            ActionTile {
                icon: "lock"
                label: "Lock"
                detail: "Screenshot clock"
                enabled: actions.lockAvailable
                onTriggered: actions.runSessionAction("lock")
            }

            ActionTile {
                icon: "logout"
                label: "Logout"
                detail: root.pendingAction === "logout" ? "Confirm" : "niri"
                active: root.pendingAction === "logout"
                onTriggered: actions.runSessionAction("logout")
            }

            ActionTile {
                icon: "bedtime"
                label: "Suspend"
                detail: root.pendingAction === "suspend" ? "Confirm" : "systemd"
                active: root.pendingAction === "suspend"
                onTriggered: actions.runSessionAction("suspend")
            }

            ActionTile {
                icon: "restart_alt"
                label: "Reboot"
                detail: root.pendingAction === "reboot" ? "Confirm" : "systemd"
                active: root.pendingAction === "reboot"
                onTriggered: actions.runSessionAction("reboot")
            }

            ActionTile {
                icon: "power_settings_new"
                label: "Shutdown"
                detail: root.pendingAction === "shutdown" ? "Confirm" : "systemd"
                active: root.pendingAction === "shutdown"
                onTriggered: actions.runSessionAction("shutdown")
            }

            ActionTile {
                icon: "cancel"
                label: "Cancel"
                detail: "Clear confirm"
                enabled: root.pendingAction.length > 0
                onTriggered: actions.cancelSessionAction()
            }
        }
    }

    component StatusRow: RowLayout {
        required property string label
        required property string value
        property bool available: false

        Layout.fillWidth: true
        spacing: Theme.spacing.md

        StyledText {
            Layout.fillWidth: true
            text: label
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
        }

        StyledText {
            text: value
            font.pixelSize: Theme.font.sm
            font.family: Theme.font.familyMono
            color: available ? Theme.colors.text : Theme.colors.subtleText
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    component ActionTile: Rectangle {
        id: tile

        signal triggered()

        required property string label
        required property string detail
        property string icon: ""
        property bool active: false

        Layout.fillWidth: true
        Layout.preferredHeight: 72
        radius: Theme.rounding.lg
        color: active ? Theme.colors.primaryContainer : tileArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainerLow
        border.width: Theme.elevation.outlineWidth
        border.color: active ? Theme.colors.primary : Theme.colors.outlineVariant
        opacity: enabled ? 1 : 0.45

        RowLayout {
            anchors {
                fill: parent
                margins: Theme.spacing.md
            }
            spacing: Theme.spacing.md

            MaterialIcon {
                name: tile.icon
                size: 22
                filled: tile.active
                iconColor: active ? Theme.colors.primaryContainerText : Theme.colors.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: tile.label
                    font.pixelSize: Theme.font.sm
                    font.weight: Font.DemiBold
                    color: active ? Theme.colors.primaryContainerText : Theme.colors.text
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.detail
                    font.pixelSize: Theme.font.xs
                    color: active ? Theme.colors.primaryContainerText : Theme.colors.mutedText
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            enabled: tile.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.triggered()
        }
    }

    component ActionPill: ActionChip {
        required property string label

        Layout.fillWidth: true
        text: label
    }
}
