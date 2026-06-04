import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common/"
import "../sidebar/"

PanelWindow {
    id: bar
    required property ShellScreen barScreen
    required property var state
    required property var clockService
    required property var batteryService
    required property var resourceService
    required property var audioService
    required property var networkService
    required property var sidebarController
    required property var trayState

    property bool bottom: Config.bar.position === "bottom"
    property bool floating: Config.bar.style === "floating"

    screen: bar.barScreen

    anchors {
        top: !bar.bottom
        bottom: bar.bottom
        left: true
        right: true
    }
    implicitHeight: Config.bar.height + (bar.floating ? Config.bar.margin * 2 : 0)
    exclusiveZone: Config.bar.height + (bar.floating ? Config.bar.margin : 0)
    color: "transparent"

    Rectangle {
        id: background
        anchors {
            left: parent.left
            right: parent.right
            top: bar.bottom ? undefined : parent.top
            bottom: bar.bottom ? parent.bottom : undefined
            margins: bar.floating ? Config.bar.margin : 0
            leftMargin: bar.floating ? Config.bar.sideMargin : 0
            rightMargin: bar.floating ? Config.bar.sideMargin : 0
        }
        height: Config.bar.height
        color: Config.bar.showBackground ? Theme.colors.surfaceContainerLow : "transparent"
        radius: bar.floating ? Theme.rounding.xl : 0
        border.width: Config.bar.showBackground ? Theme.elevation.outlineWidth : 0
        border.color: Theme.colors.outlineVariant

        RowLayout {
            id: content
            anchors {
                fill: parent
                leftMargin: Config.bar.sideMargin
                rightMargin: Config.bar.sideMargin
            }
            spacing: Config.bar.groupSpacing

            BarGroup {
                Layout.alignment: Qt.AlignVCenter
                paddingX: 8
                Workspaces {
                    state: bar.state
                    outputName: bar.barScreen.name
                }
            }

            Item {
                Layout.fillWidth: true
            }

            BarGroup {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.min(520, Math.max(160, implicitWidth))

                ActiveWindow {
                    Layout.fillWidth: true
                    state: bar.state
                }
            }

            Item {
                Layout.fillWidth: true
            }

            BarGroup {
                Layout.alignment: Qt.AlignVCenter
                SysTray {
                    Layout.alignment: Qt.AlignVCenter
                    trayState: bar.trayState
                    outputName: bar.barScreen.name
                }
                BatteryIndicator {
                    Layout.alignment: Qt.AlignVCenter
                    service: bar.batteryService
                }
                AudioIndicator {
                    Layout.alignment: Qt.AlignVCenter
                    service: bar.audioService
                }
                NetworkIndicator {
                    Layout.alignment: Qt.AlignVCenter
                    service: bar.networkService
                }
                Resources {
                    Layout.alignment: Qt.AlignVCenter
                    service: bar.resourceService
                }
                Clock {
                    Layout.alignment: Qt.AlignVCenter
                    service: bar.clockService
                }
                SidebarButton {
                    Layout.alignment: Qt.AlignVCenter
                    controller: bar.sidebarController
                    outputName: bar.barScreen.name
                }
            }
        }
    }
}
