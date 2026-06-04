import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    property int paddingX: 10
    property int paddingY: 4
    property bool hovered: mouseArea.containsMouse
    property color baseColor: Theme.colors.surfaceContainer
    property color hoverColor: Theme.colors.surfaceContainerHigh
    default property alias content: contentLayout.children

    implicitWidth: contentLayout.implicitWidth + paddingX * 2
    implicitHeight: Config.bar.height - Theme.spacing.sm
    radius: Theme.rounding.full
    color: hovered ? hoverColor : baseColor

    Behavior on color {
        ColorAnimation {
            duration: Theme.animation.fast
            easing.type: Theme.animation.easing
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: contentLayout
        anchors {
            fill: parent
            leftMargin: root.paddingX
            rightMargin: root.paddingX
            topMargin: root.paddingY
            bottomMargin: root.paddingY
        }
        spacing: Theme.spacing.sm
    }
}
