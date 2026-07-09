import QtQuick
import QtQuick.Layouts
import "../../common/"

// SettingsSegmentedRow — label on the left, segmented buttons on the right.
// options is an array of {label: string, value: string}.
// onSelected is invoked with the selected value string when a segment is clicked.

Item {
    id: root

    property string label: ""
    property string value: ""
    property var options: []
    property var selectedCallback: null

    Layout.fillWidth: true
    Layout.preferredHeight: 44
    implicitHeight: 44

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing.lg
        anchors.rightMargin: Theme.spacing.lg
        spacing: Theme.spacing.md

        // Left: label
        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Theme.font.sm
            color: Theme.colors.text
            elide: Text.ElideRight
        }

        // Right: segmented buttons
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Repeater {
                model: root.options

                Rectangle {
                    id: segment
                    readonly property bool selected: root.value === modelData.value
                    width: 70
                    height: 32
                    radius: Theme.rounding.xs
                    color: selected ? Theme.colors.primary
                        : (segMouse.containsMouse ? Theme.colors.layer1Hover : "transparent")
                    border.width: selected ? 0 : Theme.elevation.outlineWidth
                    border.color: Theme.colors.outlineVariant

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animation.fast
                            easing.type: Theme.animation.easing
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.label ?? modelData.value
                        font.pixelSize: Theme.font.xs
                        color: selected ? Theme.colors.primaryText : Theme.colors.mutedText
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!segment.selected && root.selectedCallback)
                                root.selectedCallback(modelData.value);
                        }
                    }
                }
            }
        }
    }
}