import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service
    property bool popupOpen: false

    visible: service.present
    implicitWidth: visible ? batteryRow.implicitWidth : 0
    implicitHeight: 26

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popupOpen = !root.popupOpen
    }

    RowLayout {
        id: batteryRow
        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 14

            Rectangle {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                width: 15
                height: 10
                radius: 3
                color: Theme.colors.transparent
                border.width: 1
                border.color: root.service.low ? Theme.colors.warningColor : Theme.colors.mutedText

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: 2
                    }
                    width: Math.max(2, (parent.width - 4) * root.service.percentage)
                    radius: 2
                    color: root.service.low ? Theme.colors.warningColor : Theme.colors.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animation.normal
                            easing.type: Theme.animation.easing
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 15
                    verticalCenter: parent.verticalCenter
                }
                width: 2
                height: 5
                radius: 1
                color: root.service.low ? Theme.colors.warningColor : Theme.colors.mutedText
            }
        }

        StyledText {
            text: root.service.percentText
            color: root.service.low ? Theme.colors.warningColor : Theme.colors.text
            font.family: Theme.font.familyMono
            font.pixelSize: Theme.font.sm
            font.weight: Font.DemiBold
        }

        StyledText {
            visible: root.service.charging || root.service.full
            text: root.service.stateText
            color: Theme.colors.mutedText
            font.pixelSize: Theme.font.xs
        }
    }

    PanelPopup {
        open: root.visible && root.popupOpen
        target: clickArea

        BatteryPopup {
            service: root.service
        }
    }
}
