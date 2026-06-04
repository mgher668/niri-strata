import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../common/"

Item {
    id: root

    required property var items
    property var requestMenu: (item, button) => false
    property var itemText: item => String(item?.tooltipTitle || item?.title || item?.id || "Tray item")
    property var itemDescription: item => String(item?.tooltipDescription || item?.id || "")
    property var needsAttention: item => String(item?.status ?? "").toLowerCase().includes("attention") || item?.status === 2

    signal itemActivated()
    signal tooltipRequested(var button, string title, string description)
    signal tooltipDismissed(var button)

    implicitWidth: Math.max(188, overflowColumn.implicitWidth)
    implicitHeight: overflowColumn.implicitHeight

    ColumnLayout {
        id: overflowColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Theme.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            StyledText {
                Layout.fillWidth: true
                text: "Tray"
                color: Theme.colors.text
                font.pixelSize: Theme.font.md
                font.weight: Font.DemiBold
            }

            StyledText {
                text: String(root.items.length)
                color: Theme.colors.subtleText
                font.pixelSize: Theme.font.xs
                font.family: Theme.font.familyMono
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.outline
            opacity: 0.7
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.min(4, Math.max(1, root.items.length))
            rowSpacing: Theme.spacing.sm
            columnSpacing: Theme.spacing.sm

            Repeater {
                model: root.items

                MouseArea {
                    id: trayButton

                    required property SystemTrayItem modelData
                    property bool hovered: containsMouse
                    property string tooltipTitle: root.itemText(modelData)
                    property string tooltipDescription: root.itemDescription(modelData)
                    property bool attention: root.needsAttention(modelData)

                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onContainsMouseChanged: {
                        if (containsMouse)
                            root.tooltipRequested(trayButton, tooltipTitle, tooltipDescription);
                        else
                            root.tooltipDismissed(trayButton);
                    }

                    onClicked: event => {
                        root.tooltipDismissed(trayButton);

                        if (event.button === Qt.LeftButton) {
                            if (modelData.onlyMenu && modelData.hasMenu) {
                                root.requestMenu(modelData, trayButton);
                            } else {
                                console.info("Activating tray overflow item:", modelData.id);
                                modelData.activate();
                                root.itemActivated();
                            }
                        } else if (event.button === Qt.RightButton) {
                            root.requestMenu(modelData, trayButton);
                        } else if (event.button === Qt.MiddleButton) {
                            console.info("Secondary activating tray overflow item:", modelData.id);
                            modelData.secondaryActivate();
                        }
                        event.accepted = true;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rounding.md
                        color: trayButton.attention ? Theme.colors.warningContainer
                            : trayButton.hovered ? Theme.colors.layer1Hover : Theme.colors.layer1
                        border.width: modelData.hasMenu || trayButton.attention ? 1 : 0
                        border.color: trayButton.attention ? Theme.colors.warningColor : Theme.colors.outline

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animation.fast
                                easing.type: Theme.animation.easing
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            right: parent.right
                            top: parent.top
                            margins: 4
                        }
                        visible: trayButton.attention
                        width: 7
                        height: 7
                        radius: Theme.rounding.full
                        color: Theme.colors.warningColor
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: modelData.icon
                    }
                }
            }
        }
    }
}
