import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var service

    ColumnLayout {
        id: wifiContent
        width: parent.width
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "wifi"
            title: "Network"
            subtitle: root.service.detailText
            active: root.service.enabled

            ActionChip {
                text: root.service.enabled ? "Wi-Fi on" : "Wi-Fi off"
                active: root.service.enabled
                enabled: root.service.available
                onTriggered: root.service.toggleEnabled()
            }

            ActionChip {
                text: root.service.scanning ? "Scanning" : "Scan"
                icon: "refresh"
                enabled: root.service.available && root.service.enabled && !root.service.scanning
                onTriggered: root.service.scan()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.service.lastError.length > 0
            text: root.service.lastError
            font.pixelSize: Theme.font.xs
            color: Theme.colors.errorColor
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.service.available
            text: "NetworkManager Wi-Fi is unavailable"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.subtleText
        }

        Repeater {
            model: root.service.enabled ? root.service.sortedNetworks.slice(0, 6) : []

            NetworkRow {
                required property var modelData

                network: modelData
                service: root.service
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            visible: root.service.vpnProfiles.length > 0
            color: Theme.colors.outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.service.vpnProfiles.length > 0
            spacing: Theme.spacing.md

            StyledText {
                Layout.fillWidth: true
                text: "VPN"
                font.pixelSize: Theme.font.md
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }

            StyledText {
                text: root.service.vpnStatusText
                font.pixelSize: Theme.font.xs
                color: Theme.colors.mutedText
                elide: Text.ElideRight
            }
        }

        Repeater {
            model: root.service.vpnProfiles

            Rectangle {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.rounding.sm
                color: modelData.active ? Theme.colors.primaryContainer : vpnArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainerLow
                border.width: Theme.elevation.outlineWidth
                border.color: modelData.active ? Theme.colors.primary : Theme.colors.outlineVariant

                RowLayout {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.md
                    }
                    spacing: Theme.spacing.md

                    MaterialIcon {
                        name: "vpn_lock"
                        size: 18
                        filled: modelData.active
                        iconColor: modelData.active ? Theme.colors.primaryContainerText : Theme.colors.primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.pixelSize: Theme.font.sm
                        color: modelData.active ? Theme.colors.primaryContainerText : Theme.colors.text
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: modelData.active ? "Connected" : "Connect"
                        font.pixelSize: Theme.font.xs
                        color: modelData.active ? Theme.colors.primaryContainerText : Theme.colors.mutedText
                    }
                }

                MouseArea {
                    id: vpnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.toggleVpn(modelData)
                }
            }
        }
    }

    component NetworkRow: Rectangle {
        required property var network
        required property var service

        readonly property bool passwordOpen: service.passwordNetwork === network

        Layout.fillWidth: true
        implicitHeight: networkLayout.implicitHeight + Theme.spacing.md * 2
        radius: Theme.rounding.md
        color: network.connected ? Theme.colors.primaryContainer : rowArea.containsMouse ? Theme.colors.surfaceContainerHigh : Theme.colors.surfaceContainerLow
        border.width: Theme.elevation.outlineWidth
        border.color: network.connected ? Theme.colors.primary : Theme.colors.outlineVariant

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            enabled: !passwordOpen
            onClicked: network.connected ? service.disconnectNetwork(network) : service.connectNetwork(network)
        }

        Connections {
            target: network

            function onConnectionFailed(reason) {
                service.recordConnectionFailure(reason);
            }
        }

        ColumnLayout {
            id: networkLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacing.md
            }
            spacing: Theme.spacing.sm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.md

                MaterialIcon {
                    name: "wifi"
                    size: 20
                    filled: network.connected
                    iconColor: network.connected ? Theme.colors.primaryContainerText : Theme.colors.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: network.name || "Hidden network"
                        font.pixelSize: Theme.font.sm
                        font.weight: Font.DemiBold
                        color: network.connected ? Theme.colors.primaryContainerText : Theme.colors.text
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: `${service.signalPercent(network)}% · ${service.networkStatusText(network)}`
                        font.pixelSize: Theme.font.xs
                        color: network.connected ? Theme.colors.primaryContainerText : Theme.colors.mutedText
                        elide: Text.ElideRight
                    }
                }

                ActionChip {
                    text: network.connected ? "Disconnect" : service.shouldPromptPassword(network) ? "Password" : "Connect"
                    active: network.connected
                    enabled: !network.stateChanging
                    onTriggered: network.connected ? service.disconnectNetwork(network) : service.connectNetwork(network)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: passwordOpen
                spacing: Theme.spacing.sm

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: Theme.rounding.sm
                    color: Theme.colors.background
                    border.width: Theme.elevation.outlineWidth
                    border.color: passwordInput.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant

                    TextInput {
                        id: passwordInput
                        anchors {
                            fill: parent
                            leftMargin: Theme.spacing.md
                            rightMargin: Theme.spacing.md
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.colors.text
                        selectionColor: Theme.colors.primaryContainer
                        selectedTextColor: Theme.colors.primaryContainerText
                        font.family: Theme.font.familyText
                        font.pixelSize: Theme.font.sm
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        clip: true
                        onAccepted: {
                            service.connectWithPassword(network, text);
                            text = "";
                        }
                    }

                    StyledText {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.spacing.md
                            verticalCenter: parent.verticalCenter
                        }
                        visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
                        text: "Password"
                        font.pixelSize: Theme.font.sm
                        color: Theme.colors.subtleText
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.sm

                    Item {
                        Layout.fillWidth: true
                    }

                    ActionChip {
                        text: "Cancel"
                        onTriggered: {
                            passwordInput.text = "";
                            service.cancelPassword();
                        }
                    }

                    ActionChip {
                        text: "Connect"
                        active: true
                        onTriggered: {
                            service.connectWithPassword(network, passwordInput.text);
                            passwordInput.text = "";
                        }
                    }
                }
            }
        }
    }

}
