import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common/"

// SettingsWindow — real managed window (FloatingWindow), not layer-shell.
// niri can move, float, and tile this window like any normal application.

FloatingWindow {
    id: window

    required property var controller
    required property var settingsData
    property var captureService: null

    title: "niri-strata Settings"
    visible: controller.open
    implicitWidth: 780
    implicitHeight: 560
    minimumSize: Qt.size(600, 400)
    maximumSize: Qt.size(1000, 700)
    color: Theme.colors.surfaceContainer

    onVisibleChanged: {
        if (!visible)
            controller.close();
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.colors.surfaceContainer
        border.width: Theme.elevation.outlineWidth
        border.color: Theme.colors.outlineVariant
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Title bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: Theme.colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 10

                    MaterialIcon {
                        name: "tune"
                        size: 18
                        iconColor: Theme.colors.primary
                    }

                    StyledText {
                        text: "niri-strata Settings"
                        font.pixelSize: Theme.font.sm
                        font.weight: Font.Bold
                        color: Theme.colors.text
                        Layout.fillWidth: true
                    }

                    IconButton {
                        icon: "close"
                        size: 28
                        iconSize: 16
                        onClicked: window.controller.close()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 44
                    cursorShape: Qt.SizeAllCursor
                    onPressed: window.startSystemMove()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.outlineVariant
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                SettingsSidebar {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 200
                    controller: window.controller
                    settingsData: window.settingsData
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Theme.colors.outlineVariant
                }

                SettingsContent {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: window.controller
                    settingsData: window.settingsData
                    captureService: window.captureService
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.visible
        onActivated: window.controller.close()
    }
}
