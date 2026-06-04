import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../common/"

SurfaceCard {
    id: root

    required property var service

    ColumnLayout {
        id: bluetoothContent
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "bluetooth"
            title: "Bluetooth"
            subtitle: service.detailText
            active: service.enabled

            ActionChip {
                text: service.enabled ? "On" : "Off"
                active: service.enabled
                enabled: service.available
                onTriggered: service.toggleEnabled()
            }

            ActionChip {
                text: service.discovering ? "Scanning" : "Scan"
                icon: "refresh"
                enabled: service.available && service.enabled && !service.discovering
                onTriggered: service.scan()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !service.available
            text: "BlueZ adapter is unavailable"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.subtleText
        }

        StyledText {
            Layout.fillWidth: true
            visible: service.available && service.enabled && service.sortedDevices.length === 0
            text: service.discovering ? "Scanning..." : "No Bluetooth devices"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.subtleText
        }

        Repeater {
            model: service.enabled ? service.sortedDevices.slice(0, 8) : []

            Rectangle {
                required property var modelData

                readonly property bool busy: modelData.pairing
                    || modelData.state === BluetoothDeviceState.Connecting
                    || modelData.state === BluetoothDeviceState.Disconnecting

                Layout.fillWidth: true
                implicitHeight: deviceRow.implicitHeight + Theme.spacing.md * 2
                radius: Theme.rounding.md
                color: modelData.connected ? Theme.colors.primaryContainer : deviceArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainerLow
                border.width: Theme.elevation.outlineWidth
                border.color: modelData.connected ? Theme.colors.primary : Theme.colors.outlineVariant
                opacity: modelData.blocked ? 0.45 : 1

                RowLayout {
                    id: deviceRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.spacing.md
                    }
                    spacing: Theme.spacing.md

                    MaterialIcon {
                        name: "bluetooth"
                        size: 20
                        filled: modelData.connected
                        iconColor: modelData.connected ? Theme.colors.primaryContainerText : Theme.colors.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: service.deviceName(modelData)
                            font.pixelSize: Theme.font.sm
                            font.weight: Font.DemiBold
                            color: modelData.connected ? Theme.colors.primaryContainerText : Theme.colors.text
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: service.deviceStatus(modelData)
                            font.pixelSize: Theme.font.xs
                            color: modelData.connected ? Theme.colors.primaryContainerText : Theme.colors.mutedText
                            elide: Text.ElideRight
                        }
                    }

                    ActionChip {
                        text: modelData.connected ? "Disconnect" : "Connect"
                        active: modelData.connected
                        enabled: !busy && !modelData.blocked
                        onTriggered: service.toggleDevice(modelData)
                    }
                }

                MouseArea {
                    id: deviceArea
                    anchors.fill: parent
                    enabled: !busy && !modelData.blocked
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: service.toggleDevice(modelData)
                }
            }
        }
    }

}
