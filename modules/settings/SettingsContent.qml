import QtQuick
import QtQuick.Layouts
import "../common/"
import "tabs/"

// SettingsContent — tab content area using StackLayout for proper sizing.

Item {
    id: content

    required property var controller
    required property var settingsData
    property var captureService: null

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: width
        contentHeight: stack.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        StackLayout {
            id: stack
            width: parent.width

            currentIndex: {
                switch (content.controller.activeTab) {
                case "appearance": return 0;
                case "bar": return 1;
                case "workspaces": return 2;
                case "capture": return 3;
                case "notifications": return 4;
                case "niri": return 5;
                case "services": return 6;
                case "about": return 7;
                }
            }

            AppearanceTab {
                settingsData: content.settingsData
            }

            BarTab {
                settingsData: content.settingsData
            }

            WorkspacesTab {
                settingsData: content.settingsData
            }

            CaptureTab {
                settingsData: content.settingsData
            }

            NotificationsTab {
                settingsData: content.settingsData
            }

            NiriTab {
                settingsData: content.settingsData
            }

            ServicesTab {
                settingsData: content.settingsData
                captureService: content.captureService
            }

            AboutTab {
                settingsData: content.settingsData
            }
        }
    }
}