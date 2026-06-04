import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service
    property bool popupOpen: false

    implicitWidth: resourceRow.implicitWidth
    implicitHeight: 26

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popupOpen = !root.popupOpen
    }

    RowLayout {
        id: resourceRow
        anchors.centerIn: parent
        spacing: Theme.spacing.md

        MaterialIcon {
            name: "monitoring"
            size: 18
            iconColor: Theme.colors.primary
        }

        ResourceMetric {
            label: "CPU"
            value: root.service.cpuUsage
            text: root.service.cpuText
            warning: root.service.cpuUsage >= 0.85
        }

        ResourceMetric {
            label: "RAM"
            value: root.service.memoryUsage
            text: root.service.memoryText
            warning: root.service.memoryUsage >= 0.85
        }
    }

    component ResourceMetric: RowLayout {
        required property string label
        required property real value
        required property string text
        property bool warning: false

        spacing: Theme.spacing.xs

        Rectangle {
            Layout.preferredWidth: 4
            Layout.preferredHeight: 16
            radius: Theme.rounding.full
            color: Theme.colors.layer1Active

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Math.max(2, parent.height * Math.max(0, Math.min(1, value)))
                radius: Theme.rounding.full
                color: warning ? Theme.colors.warningColor : Theme.colors.primary

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.animation.normal
                        easing.type: Theme.animation.easing
                    }
                }
            }
        }

        StyledText {
            text: label
            color: Theme.colors.subtleText
            font.pixelSize: Theme.font.xs
            font.family: Theme.font.familyMono
            font.weight: Font.DemiBold
        }

        StyledText {
            Layout.preferredWidth: percentMetrics.width
            text: parent.text
            color: warning ? Theme.colors.warningColor : Theme.colors.text
            font.pixelSize: Theme.font.xs
            font.family: Theme.font.familyMono
            horizontalAlignment: Text.AlignRight

            TextMetrics {
                id: percentMetrics
                text: "100%"
                font.family: Theme.font.familyMono
                font.pixelSize: Theme.font.xs
            }
        }
    }

    PanelPopup {
        open: root.popupOpen
        target: clickArea

        ResourcesPopup {
            service: root.service
        }
    }
}
