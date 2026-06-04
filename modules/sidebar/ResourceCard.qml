import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var service

    ColumnLayout {
        id: resourceContent
        width: parent.width
        spacing: Theme.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            MaterialIcon {
                name: "monitoring"
                size: 22
                iconColor: Theme.colors.primary
            }

            StyledText {
                Layout.fillWidth: true
                text: "Resources"
                font.pixelSize: Theme.font.lg
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }
        }

        MetricRow {
            label: "CPU"
            value: root.service.cpuUsage
            valueText: root.service.cpuText
            warning: root.service.cpuUsage >= 0.85
        }

        MetricRow {
            label: "Memory"
            value: root.service.memoryUsage
            valueText: root.service.memoryText
            detailText: root.service.memoryTotalText
            warning: root.service.memoryUsage >= 0.85
        }

        MetricRow {
            label: "Swap"
            value: root.service.swapUsage
            valueText: root.service.swapText
            detailText: root.service.swapTotalText
            warning: root.service.swapUsage >= 0.85
        }
    }

    component MetricRow: ColumnLayout {
        required property string label
        required property real value
        required property string valueText
        property string detailText: ""
        property bool warning: false

        Layout.fillWidth: true
        spacing: Theme.spacing.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            StyledText {
                Layout.fillWidth: true
                text: label
                font.pixelSize: Theme.font.sm
                color: Theme.colors.mutedText
            }

            StyledText {
                visible: detailText.length > 0
                text: detailText
                font.pixelSize: Theme.font.xs
                color: Theme.colors.subtleText
            }

            StyledText {
                Layout.preferredWidth: percentMetrics.width
                text: valueText
                font.pixelSize: Theme.font.sm
                font.family: Theme.font.familyMono
                color: warning ? Theme.colors.warningColor : Theme.colors.text
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
            Layout.preferredHeight: 6
            radius: Theme.rounding.full
            color: Theme.colors.surfaceContainerLow

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
    }
}
