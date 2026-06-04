import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service

    implicitWidth: 260
    implicitHeight: popupColumn.implicitHeight

    ColumnLayout {
        id: popupColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Theme.spacing.lg

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            Item {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 28

                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: 46
                    height: 24
                    radius: Theme.rounding.sm
                    color: Theme.colors.transparent
                    border.width: 1
                    border.color: root.service.low ? Theme.colors.warningColor : Theme.colors.outline

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            margins: 3
                        }
                        width: Math.max(3, (parent.width - 6) * root.service.percentage)
                        radius: Theme.rounding.xs
                        color: root.service.low ? Theme.colors.warningColor : Theme.colors.primary
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        leftMargin: 46
                        verticalCenter: parent.verticalCenter
                    }
                    width: 4
                    height: 12
                    radius: 2
                    color: root.service.low ? Theme.colors.warningColor : Theme.colors.outline
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.service.percentText
                    color: root.service.low ? Theme.colors.warningColor : Theme.colors.text
                    font.family: Theme.font.familyMono
                    font.pixelSize: Theme.font.xl
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.service.stateText
                    color: Theme.colors.mutedText
                    font.pixelSize: Theme.font.sm
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.outline
            opacity: 0.7
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.sm

            DetailRow {
                label: "Device"
                value: root.service.modelText
            }

            DetailRow {
                label: root.service.charging ? "To full" : "Remaining"
                value: root.service.timeText
            }

            DetailRow {
                label: "Rate"
                value: root.service.powerText
            }

            DetailRow {
                label: "Energy"
                value: root.service.energyText
            }

            DetailRow {
                label: "Health"
                value: root.service.healthText
            }
        }
    }

    component DetailRow: RowLayout {
        required property string label
        required property string value

        Layout.fillWidth: true
        spacing: Theme.spacing.lg

        StyledText {
            Layout.fillWidth: true
            text: label
            color: Theme.colors.subtleText
            font.pixelSize: Theme.font.sm
        }

        StyledText {
            text: value
            color: Theme.colors.text
            font.family: Theme.font.familyMono
            font.pixelSize: Theme.font.sm
            horizontalAlignment: Text.AlignRight
        }
    }
}
