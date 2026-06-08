import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../common/"

Scope {
    id: root

    required property var controller
    required property var notificationService
    required property var systemActions
    required property var resourceService
    required property var batteryService
    required property var wifiService
    required property var bluetoothService
    required property var audioService
    required property var mediaService

    Timer {
        id: startRegionRecordingTimer
        interval: 250
        repeat: false
        onTriggered: root.systemActions.toggleRegionRecording()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: sidebarWindow
            required property ShellScreen modelData

            readonly property bool shown: root.controller.open && root.controller.screenMatches(modelData)

            screen: modelData
            visible: shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: Config.sidebar.width + Config.sidebar.margin * 2
            implicitHeight: modelData.height
            WlrLayershell.namespace: "quickshell:sidebar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: true
                bottom: true
                right: true
            }

            Rectangle {
                id: scrim
                anchors.fill: parent
                color: Theme.colors.transparent

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.controller.close()
                }

                Rectangle {
                    id: panel
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                        topMargin: Config.sidebar.topMargin
                        bottomMargin: Config.sidebar.bottomMargin
                        rightMargin: Config.sidebar.margin
                    }
                    width: Config.sidebar.width
                    radius: Theme.rounding.xxl
                    color: Theme.colors.surfaceContainerLow
                    border.width: Theme.elevation.outlineWidth
                    border.color: Theme.colors.outlineVariant
                    opacity: sidebarWindow.shown ? 1 : 0
                    scale: sidebarWindow.shown ? 1 : 0.98
                    transform: Translate {
                        id: panelTranslate
                        x: sidebarWindow.shown ? 0 : 24

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animation.normal
                                easing.type: Theme.animation.emphasized
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animation.normal
                            easing.type: Theme.animation.easing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animation.normal
                            easing.type: Theme.animation.emphasized
                        }
                    }

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: Config.sidebar.contentPadding
                        }
                        spacing: Theme.spacing.xl

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48

                            Rectangle {
                                id: headerIcon

                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 48
                                height: 48
                                radius: Theme.rounding.lg
                                color: Theme.colors.primaryContainer

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "dashboard_customize"
                                    size: 26
                                    filled: true
                                    iconColor: Theme.colors.primaryContainerText
                                }
                            }

                            ColumnLayout {
                                anchors {
                                    left: headerIcon.right
                                    right: closeButton.left
                                    leftMargin: Theme.spacing.lg
                                    rightMargin: Theme.spacing.lg
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: Theme.spacing.xs

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Control center"
                                    font.pixelSize: Theme.font.xxl
                                    font.weight: Font.DemiBold
                                    color: Theme.colors.text
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.controller.targetOutputName || "No focused output"
                                    font.pixelSize: Theme.font.sm
                                    color: Theme.colors.mutedText
                                    elide: Text.ElideRight
                                }
                            }

                            IconButton {
                                id: closeButton

                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                size: Config.sidebar.iconButtonSize
                                icon: "close"
                                label: "Close"
                                showBorder: true
                                baseColor: Theme.colors.surfaceContainer
                                onClicked: root.controller.close()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.colors.outlineVariant
                        }

                        Flickable {
                            id: sidebarFlickable

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: sidebarContent.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            function scrollBy(delta) {
                                const maxY = Math.max(0, contentHeight - height);
                                contentY = Math.max(0, Math.min(maxY, contentY + delta));
                            }

                            WheelHandler {
                                target: null
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    sidebarFlickable.scrollBy(-event.angleDelta.y * Config.sidebar.wheelScrollFactor);
                                    event.accepted = true;
                                }
                            }

                            ColumnLayout {
                                id: sidebarContent
                                width: parent.width
                                spacing: Theme.spacing.lg

                                QuickToggleGrid {
                                    Layout.fillWidth: true
                                    actions: root.systemActions
                                    onStartRegionRecordingRequested: {
                                        root.controller.close();
                                        startRegionRecordingTimer.restart();
                                    }
                                }

                                ResourceCard {
                                    service: root.resourceService
                                }

                                PowerSummary {
                                    batteryService: root.batteryService
                                    actions: root.systemActions
                                }

                                WifiPanel {
                                    service: root.wifiService
                                }

                                BluetoothPanel {
                                    service: root.bluetoothService
                                }

                                AudioMixer {
                                    service: root.audioService
                                }

                                MediaPanel {
                                    service: root.mediaService
                                }

                                BrightnessPanel {
                                    actions: root.systemActions
                                }

                                NightModePanel {
                                    actions: root.systemActions
                                }

                                SystemPanel {
                                    actions: root.systemActions
                                }

                                SurfaceCard {
                                    Layout.fillWidth: true

                                    NotificationCenter {
                                        id: notificationCenter
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            top: parent.top
                                        }
                                        service: root.notificationService
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: sidebarWindow.visible
                onActivated: root.controller.close()
            }
        }
    }
}
