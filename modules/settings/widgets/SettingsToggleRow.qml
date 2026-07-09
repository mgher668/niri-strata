import QtQuick
import QtQuick.Layouts
import "../../common/"

// SettingsToggleRow — label + description on the left, toggle switch on the right.
// Clicking anywhere on the row toggles. onToggle is invoked with the new boolean value.

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    property var toggleCallback: null

    Layout.fillWidth: true
    Layout.preferredHeight: 44
    implicitHeight: 44

    // Hover background (covers the whole row)
    Rectangle {
        id: hoverBg
        anchors.fill: parent
        radius: Theme.rounding.sm
        color: rowHover.containsMouse ? Theme.colors.layer1Hover : "transparent"
        z: -1

        Behavior on color {
            ColorAnimation {
                duration: Theme.animation.fast
                easing.type: Theme.animation.easing
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing.lg
        anchors.rightMargin: Theme.spacing.lg
        spacing: Theme.spacing.md

        // Left: label + description
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Theme.font.sm
                color: Theme.colors.text
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                font.pixelSize: Theme.font.xs
                color: Theme.colors.subtleText
                elide: Text.ElideRight
            }
        }

        // Right: toggle switch (44x24) — purely visual; the row MouseArea toggles
        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: track
                anchors.fill: parent
                radius: 12
                color: root.checked ? Theme.colors.primary : Theme.colors.layer1
                border.width: Theme.elevation.outlineWidth
                border.color: root.checked ? Theme.colors.primary : Theme.colors.outlineVariant

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animation.normal
                        easing.type: Theme.animation.easing
                    }
                }

                // Knob (20x20 white circle)
                Rectangle {
                    id: knob
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.checked ? parent.width - width - 2 : 2

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animation.normal
                            easing.type: Theme.animation.emphasized
                        }
                    }
                }
            }
        }
    }

    // Full-row hover + click-to-toggle (on top; Text/Rectangle children don't steal mouse)
    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.toggleCallback)
                root.toggleCallback(!root.checked);
        }
    }
}