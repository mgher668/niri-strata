import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../common/"

Scope {
    id: root

    required property var service
    required property var niriState
    property var sidebarController: null

    readonly property string targetOutputName: niriState.focusedOutputName

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: toastWindow
            required property ShellScreen modelData

            readonly property bool targetScreen: modelData.name === root.targetOutputName

            screen: modelData
            visible: targetScreen && root.service.popupCount > 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 380 + Config.sidebar.margin * 2
            implicitHeight: toastColumn.implicitHeight + Config.sidebar.margin
            WlrLayershell.namespace: "quickshell:notifications"
            WlrLayershell.layer: WlrLayer.Overlay

            anchors {
                top: true
                right: true
            }

            margins {
                top: Config.bar.height + Config.bar.margin * 2
            }

            Column {
                id: toastColumn

                anchors {
                    top: parent.top
                    right: parent.right
                    rightMargin: Config.sidebar.margin
                }
                width: 380
                spacing: Theme.spacing.md

                Repeater {
                    model: root.service.popupNotifications.slice(0, 3)

                    DismissibleNotificationCard {
                        required property var modelData

                        width: parent.width
                        notification: modelData
                        service: root.service
                        bodyLineCount: 2
                        cardRadius: Theme.rounding.lg
                        minimumCardHeight: 82
                        onDismissed: root.service.dismissNotification(modelData.notificationId)
                    }
                }
            }
        }
    }
}
