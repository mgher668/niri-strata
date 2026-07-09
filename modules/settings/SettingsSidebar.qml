import QtQuick
import QtQuick.Layouts
import "../common/"

// SettingsSidebar — category navigation list on the left side.

Item {
    id: sidebar

    required property var controller
    required property var settingsData
    property bool _resetConfirming: false
    property int _keyboardIndex: 0

    focus: true
    activeFocusOnTab: true

    Keys.onUpPressed: {
        if (sidebar._keyboardIndex > 0)
            sidebar._keyboardIndex -= 1;
        else
            sidebar._keyboardIndex = sidebar.controller.tabs.length - 1;
    }

    Keys.onDownPressed: {
        if (sidebar._keyboardIndex < sidebar.controller.tabs.length - 1)
            sidebar._keyboardIndex += 1;
        else
            sidebar._keyboardIndex = 0;
    }

    Keys.onReturnPressed: {
        sidebar.controller.activeTab = sidebar.controller.tabs[sidebar._keyboardIndex].id;
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.colors.surfaceContainerLow
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                spacing: 10

                MaterialIcon {
                    name: "settings"
                    size: 20
                    iconColor: Theme.colors.primary
                }

                StyledText {
                    text: "Settings"
                    font.pixelSize: Theme.font.md
                    font.weight: Font.Bold
                    color: Theme.colors.text
                }

                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.outlineVariant
        }
        // Tab list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: sidebar.controller.tabs
            currentIndex: {
                var activeId = sidebar.controller.activeTab;
                for (var i = 0; i < sidebar.controller.tabs.length; i++) {
                    if (sidebar.controller.tabs[i].id === activeId)
                        return i;
                }
                return 0;
            }
            delegate: Item {
                width: sidebar.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    color: modelData.id === sidebar.controller.activeTab
                        ? Theme.colors.activeTabBg
                        : index === sidebar._keyboardIndex
                            ? Theme.colors.buttonHover
                            : mouseArea.containsMouse
                                ? Theme.colors.surfaceHover
                                : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.34, 0.8, 0.34, 1, 1, 1]
                        }
                    }
                }

                // Left active indicator bar
                Rectangle {
                    visible: modelData.id === sidebar.controller.activeTab
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    color: Theme.colors.primary
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    spacing: 10

                    MaterialIcon {
                        name: modelData.icon
                        size: 18
                        iconColor: modelData.id === sidebar.controller.activeTab
                            ? Theme.colors.primary
                            : Theme.colors.mutedText
                    }

                    StyledText {
                        text: modelData.title
                        font.pixelSize: Theme.font.sm
                        color: modelData.id === sidebar.controller.activeTab
                            ? Theme.colors.text
                            : Theme.colors.mutedText
                        font.weight: modelData.id === sidebar.controller.activeTab
                            ? Font.DemiBold
                            : Font.Normal
                    }
                    Item { Layout.fillWidth: true }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { sidebar.controller.activeTab = modelData.id; sidebar._keyboardIndex = index; }
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // --- Reset all button (bottom) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.outlineVariant
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: Theme.rounding.sm
                color: resetMouse.containsMouse
                    ? Theme.colors.errorContainer
                    : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animation.fast
                        easing.type: Theme.animation.easing
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        name: "restart_alt"
                        size: 16
                        iconColor: sidebar._resetConfirming
                            ? Theme.colors.errorColor
                            : Theme.colors.subtleText
                    }

                    StyledText {
                        text: sidebar._resetConfirming
                            ? "Click to confirm"
                            : "Reset all"
                        font.pixelSize: Theme.font.xs
                        color: sidebar._resetConfirming
                            ? Theme.colors.errorColor
                            : Theme.colors.subtleText
                    }
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sidebar._resetConfirming) {
                            sidebar.settingsData.resetAll();
                            sidebar._resetConfirming = false;
                            resetConfirmTimer.stop();
                        } else {
                            sidebar._resetConfirming = true;
                            resetConfirmTimer.restart();
                        }
                    }
                }
            }

            Timer {
                id: resetConfirmTimer
                interval: 3000
                onTriggered: sidebar._resetConfirming = false
            }
        }
    }
}