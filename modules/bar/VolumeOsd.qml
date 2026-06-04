import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../common/"

LazyLoader {
    id: root

    required property var service

    active: service.osdVisible && service.available

    component: PanelWindow {
        id: osdWindow

        color: Theme.colors.transparent
        implicitWidth: 260
        implicitHeight: 78
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        anchors {
            bottom: Config.bar.position !== "bottom"
            top: Config.bar.position === "bottom"
            left: true
            right: true
        }

        margins {
            bottom: Config.bar.position !== "bottom" ? 42 : 0
            top: Config.bar.position === "bottom" ? 42 : 0
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:niri-strata-volume-osd"

        Rectangle {
            width: 260
            height: 78
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Theme.rounding.lg
            color: Theme.colors.layer0
            border.width: 1
            border.color: Theme.colors.outline
            opacity: root.service.osdVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animation.fast
                    easing.type: Theme.animation.easing
                }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.spacing.lg
                }
                spacing: Theme.spacing.sm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.md

                    StyledText {
                        Layout.fillWidth: true
                        text: root.service.deviceName
                        color: Theme.colors.text
                        font.pixelSize: Theme.font.sm
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.service.muted ? "Muted" : root.service.percentText
                        color: root.service.muted ? Theme.colors.subtleText : Theme.colors.primary
                        font.family: Theme.font.familyMono
                        font.pixelSize: Theme.font.sm
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: Theme.rounding.full
                    color: Theme.colors.layer1

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.service.volume)))
                        radius: Theme.rounding.full
                        color: root.service.muted ? Theme.colors.subtleText : Theme.colors.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animation.normal
                                easing.type: Theme.animation.easing
                            }
                        }
                    }
                }
            }
        }
    }
}
