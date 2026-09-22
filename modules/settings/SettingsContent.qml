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
    readonly property int contentPadding: 24
    readonly property int activeTabIndex: {
        switch (content.controller.activeTab) {
        case "appearance": return 0;
        case "bar": return 1;
        case "workspaces": return 2;
        case "capture": return 3;
        case "notifications": return 4;
        case "niri": return 5;
        case "services": return 6;
        case "about": return 7;
        default: return 0;
        }
    }
    readonly property var activeTabItem: {
        switch (content.activeTabIndex) {
        case 0: return appearanceTab;
        case 1: return barTab;
        case 2: return workspacesTab;
        case 3: return captureTab;
        case 4: return notificationsTab;
        case 5: return niriTab;
        case 6: return servicesTab;
        case 7: return aboutTab;
        default: return null;
        }
    }

    Flickable {
        id: contentFlickable
        anchors.fill: parent
        contentWidth: width
        // The viewport must include the full settings area. Padding belongs to
        // the tab content below, otherwise the scrollbar is inset as well.
        contentHeight: Math.max(
            height,
            stack.y + (content.activeTabItem ? content.activeTabItem.implicitHeight : 0)
                + content.contentPadding
        )
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        StackLayout {
            id: stack
            x: content.contentPadding
            y: content.contentPadding
            width: Math.max(0, parent.width - content.contentPadding * 2)
            // Only the active tab contributes to the scrollable height. Do not
            // stretch this to the viewport: that makes visibleArea.heightRatio
            // equal to 1 and produces a full-track scrollbar thumb.
            height: Math.max(0, content.activeTabItem ? content.activeTabItem.implicitHeight : 0)

            currentIndex: content.activeTabIndex
            onCurrentIndexChanged: contentFlickable.contentY = 0

            AppearanceTab {
                id: appearanceTab
                settingsData: content.settingsData
            }

            BarTab {
                id: barTab
                settingsData: content.settingsData
            }

            WorkspacesTab {
                id: workspacesTab
                settingsData: content.settingsData
            }

            CaptureTab {
                id: captureTab
                settingsData: content.settingsData
            }

            NotificationsTab {
                id: notificationsTab
                settingsData: content.settingsData
            }

            NiriTab {
                id: niriTab
                settingsData: content.settingsData
            }

            ServicesTab {
                id: servicesTab
                settingsData: content.settingsData
                captureService: content.captureService
            }

            AboutTab {
                id: aboutTab
                settingsData: content.settingsData
            }
        }
    }

    StyledScrollbar {
        targetFlickable: contentFlickable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
