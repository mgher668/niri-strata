import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    signal triggered()

    property string text: ""
    property string icon: ""
    property bool active: false
    property int minWidth: 72
    property int chipHeight: 32
    property color baseColor: Theme.colors.surfaceContainerLow
    property color hoverColor: Theme.colors.surfaceContainerHigh
    property color activeColor: Theme.colors.primaryContainer
    property color textColor: active ? Theme.colors.primaryContainerText : Theme.colors.text

    Layout.preferredWidth: Math.max(minWidth, chipContent.implicitWidth + Theme.spacing.lg * 2)
    Layout.preferredHeight: chipHeight
    radius: Theme.rounding.full
    color: active ? activeColor : chipArea.containsMouse ? hoverColor : baseColor
    border.width: Theme.elevation.outlineWidth
    border.color: active ? Theme.colors.primary : Theme.colors.outlineVariant
    opacity: enabled ? 1 : Theme.elevation.disabledOpacity
    scale: chipArea.pressed ? Theme.elevation.pressedScale : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.animation.fast
            easing.type: Theme.animation.easing
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animation.fast
            easing.type: Theme.animation.easing
        }
    }

    RowLayout {
        id: chipContent
        anchors.centerIn: parent
        spacing: Theme.spacing.xs

        MaterialIcon {
            visible: root.icon.length > 0
            name: root.icon
            size: 17
            filled: root.active
            iconColor: root.textColor
        }

        StyledText {
            text: root.text
            font.pixelSize: Theme.font.xs
            font.weight: Font.DemiBold
            color: root.textColor
        }
    }

    MouseArea {
        id: chipArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
