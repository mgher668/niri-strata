import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    signal setValue(real value)

    property real from: 0
    property real to: 1
    property real value: from
    property real stepSize: 0
    property string size: "regular"
    property int trackHeight: size === "compact" ? 6 : 9
    property int handleSize: size === "compact" ? 14 : 18

    readonly property real range: to - from
    readonly property real ratio: range === 0 ? 0 : clamp((value - from) / range, 0, 1)

    implicitHeight: Math.max(trackHeight, handleSize) + Theme.spacing.sm
    Layout.preferredHeight: implicitHeight
    opacity: enabled ? 1 : Theme.elevation.disabledOpacity

    function clamp(input, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, input));
    }

    function normalize(input) {
        if (stepSize <= 0)
            return input;

        return Math.round(input / stepSize) * stepSize;
    }

    function valueFromPosition(position) {
        const nextRatio = clamp(position / Math.max(1, width), 0, 1);
        return clamp(normalize(from + nextRatio * range), Math.min(from, to), Math.max(from, to));
    }

    Rectangle {
        id: track

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        height: root.trackHeight
        radius: Theme.rounding.full
        color: Theme.colors.surfaceContainerLow

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width: Math.max(parent.height, parent.width * root.ratio)
            radius: Theme.rounding.full
            color: root.enabled ? Theme.colors.primary : Theme.colors.subtleText
        }
    }

    Rectangle {
        id: handle

        x: root.clamp(root.width * root.ratio - width / 2, 0, Math.max(0, root.width - width))
        anchors.verticalCenter: parent.verticalCenter
        width: dragArea.pressed ? root.handleSize + 2 : dragArea.containsMouse ? root.handleSize + 1 : root.handleSize
        height: width
        radius: Theme.rounding.full
        color: root.enabled ? Theme.colors.primaryContainerText : Theme.colors.surfaceContainerHighest
        border.width: Theme.elevation.outlineWidth
        border.color: root.enabled ? Theme.colors.primary : Theme.colors.outlineVariant

        Behavior on width {
            NumberAnimation {
                duration: Theme.animation.fast
                easing.type: Theme.animation.easing
            }
        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function update(mouse) {
            root.setValue(root.valueFromPosition(mouse.x));
        }

        onPressed: mouse => update(mouse)
        onPositionChanged: mouse => {
            if (pressed)
                update(mouse);
        }
    }
}
