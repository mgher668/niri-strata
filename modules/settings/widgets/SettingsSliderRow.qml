import QtQuick
import QtQuick.Layouts
import "../../common/"

// SettingsSliderRow — label on the left, custom slider + value display on the right.
// onValueChanged is invoked with the new real value when the slider is moved.
Item {
    id: root

    property string label: ""
    property real value: 0
    property real minValue: 0
    property real maxValue: 1
    property real stepSize: 0
    property string unit: ""
    property var valueChangedCallback: null

    Layout.fillWidth: true
    Layout.preferredHeight: 48
    implicitHeight: 48

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.sm
        color: "transparent"
        z: -1
    }

    readonly property real range: maxValue - minValue
    readonly property real ratio: range === 0 ? 0 : Math.max(0, Math.min(1, (value - minValue) / range))

    function clamp(input, lo, hi) {
        return Math.max(lo, Math.min(hi, input));
    }

    function normalize(input) {
        if (stepSize <= 0)
            return input;
        return Math.round(input / stepSize) * stepSize;
    }

    function valueFromPosition(position) {
        var nextRatio = clamp(position / Math.max(1, sliderTrack.width), 0, 1);
        return clamp(normalize(minValue + nextRatio * range), Math.min(minValue, maxValue), Math.max(minValue, maxValue));
    }

    function updateValue(mouse) {
        var newValue = valueFromPosition(mouse.x);
        if (newValue !== root.value && root.valueChangedCallback)
            root.valueChangedCallback(newValue);
    }

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

        // Right: slider + value display
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacing.md

            // Custom slider track
            Item {
                id: sliderTrack
                Layout.preferredWidth: 160
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter

                // Track background
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 6
                    radius: Theme.rounding.full
                    color: Theme.colors.surfaceContainerLow

                    // Filled portion
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(parent.height, parent.width * root.ratio)
                        radius: Theme.rounding.full
                        color: root.enabled ? Theme.colors.primary : Theme.colors.subtleText
                    }
                }

                // Handle
                Rectangle {
                    id: handle
                    width: dragArea.pressed ? 18 : dragArea.containsMouse ? 17 : 16
                    height: width
                    radius: Theme.rounding.full
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.clamp(root.ratio * sliderTrack.width - width / 2, 0, Math.max(0, sliderTrack.width - width))
                    color: Theme.colors.primaryContainerText
                    border.width: Theme.elevation.outlineWidth
                    border.color: Theme.colors.primary

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
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => root.updateValue(mouse)
                    onPositionChanged: mouse => {
                        if (pressed)
                            root.updateValue(mouse);
                    }
                }
            }

            // Value display
            StyledText {
                Layout.preferredWidth: 60
                Layout.alignment: Qt.AlignVCenter
                text: root.value + root.unit
                font.pixelSize: Theme.font.sm
                color: Theme.colors.mutedText
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }
}