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
    property bool floating: false

    screen: bar.barScreen

    anchors {
        top: !bar.bottom
        bottom: bar.bottom
        left: true
        right: true
    }
    implicitHeight: Config.bar.height
    exclusiveZone: Config.bar.height
    color: "transparent"

    // Detect if focused window is maximized (non-floating) to flatten bar shape.
    readonly property bool hasMaximizedWindow: {
        if (!SettingsData.barFlattenOnMaximized)
            return false;
        var win = bar.state.focusedWindow;
        if (!win || !win.title)
            return false;
        return !win.isFloating;
    }

    BarCanvas {
        id: canvas
        anchors.fill: parent
        bgColor: Config.bar.showBackground ? Theme.colors.surfaceContainerLow : "transparent"
        borderColor: Theme.colors.outlineVariant
        showBorder: Config.bar.showBackground
        borderThickness: Theme.elevation.outlineWidth
        wingRadius: SettingsData.barWingRadius
        bottomRadius: SettingsData.barBottomRadius
        hasMaximizedWindow: bar.hasMaximizedWindow
    }

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