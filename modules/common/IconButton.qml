import QtQuick
import "."

Item {
    id: root

    signal clicked(var event)

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool filled: active
    property bool enabled: true
    property int size: Config.bar.iconButtonSize
    property int iconSize: 15
    property color baseColor: Theme.colors.transparent
    property color hoverColor: Theme.colors.surfaceContainerHigh
    property color activeColor: Theme.colors.primaryContainer
    property color iconColor: active ? Theme.colors.primaryContainerText : Theme.colors.text
    property color borderColor: active ? Theme.colors.primary : Theme.colors.outlineVariant
    property bool showBorder: false
    readonly property bool hovered: buttonArea.containsMouse
    readonly property bool pressed: buttonArea.pressed

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : Theme.elevation.disabledOpacity
    scale: pressed ? Theme.elevation.pressedScale : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animation.fast
            easing.type: Theme.animation.easing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.full
        color: root.active ? root.activeColor : root.hovered ? root.hoverColor : root.baseColor
        border.width: root.showBorder ? Theme.elevation.outlineWidth : 0
        border.color: root.borderColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.animation.fast
                easing.type: Theme.animation.easing
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        filled: root.filled
        iconColor: root.iconColor
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.clicked(event)
    }
}
