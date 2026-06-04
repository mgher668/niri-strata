import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service

    implicitWidth: 300
    implicitHeight: popupColumn.implicitHeight

    ColumnLayout {
        id: popupColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Theme.spacing.lg

        StyledText {
            Layout.fillWidth: true
            text: "System resources"
            color: Theme.colors.text
            font.pixelSize: Theme.font.md
            font.weight: Font.DemiBold
        }

        ResourceBlock {
            label: "CPU"
            value: root.service.cpuUsage
            valueText: root.service.cpuText
            detailText: "processor"
            history: root.service.cpuHistory
            warning: root.service.cpuUsage >= 0.85
        }

        ResourceBlock {
            label: "Memory"
            value: root.service.memoryUsage
            valueText: root.service.memoryText
            detailText: root.service.memoryTotalText
            history: root.service.memoryHistory
            warning: root.service.memoryUsage >= 0.85
        }

        ResourceBlock {
            label: "Swap"
            value: root.service.swapUsage
            valueText: root.service.swapText
            detailText: root.service.swapTotalText
            history: root.service.swapHistory
            warning: root.service.swapUsage >= 0.85
        }
    }

    component ResourceBlock: ColumnLayout {
        required property string label
        required property real value
        required property string valueText
        required property string detailText
        required property var history
        property bool warning: false

        Layout.fillWidth: true
        spacing: Theme.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            StyledText {
                Layout.fillWidth: true
                text: label
                color: Theme.colors.text
                font.pixelSize: Theme.font.sm
                font.weight: Font.DemiBold
            }

            StyledText {
                text: detailText
                color: Theme.colors.subtleText
                font.pixelSize: Theme.font.xs
            }

            StyledText {
                Layout.preferredWidth: percentMetrics.width
                text: valueText
                color: warning ? Theme.colors.warningColor : Theme.colors.text
                font.family: Theme.font.familyMono
                font.pixelSize: Theme.font.sm
                horizontalAlignment: Text.AlignRight

                TextMetrics {
                    id: percentMetrics
                    text: "100%"
                    font.family: Theme.font.familyMono
                    font.pixelSize: Theme.font.sm
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: Theme.rounding.full
            color: Theme.colors.layer1

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, value)))
                radius: Theme.rounding.full
                color: warning ? Theme.colors.warningColor : Theme.colors.primary

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animation.normal
                        easing.type: Theme.animation.easing
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: history

                Rectangle {
                    required property real modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 2
                    color: Theme.colors.layer1

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: Math.max(2, parent.height * Math.max(0, Math.min(1, modelData)))
                        radius: 2
                        color: warning ? Theme.colors.warningColor : Theme.colors.primaryContainerText
                        opacity: 0.86
                    }
                }
            }
        }
    }
}
