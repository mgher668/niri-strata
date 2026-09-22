import QtQuick

// StyledScrollbar — lightweight vertical scrollbar for Flickable/GridView.
// Pure QtQuick (no QtQuick.Controls dependency, which Quickshell lacks).
// Computes the thumb from the target's viewport/content dimensions so it also
// behaves correctly when a layout reports a slightly out-of-range visibleArea.
// Shows on hover/move, auto-hides after 1.2s — mirrors DankMaterialShell's
// DankScrollbar.qml logic without the Controls.ScrollBar base type.

Item {
    id: root

    // The Flickable/GridView to track. Must be set by parent.
    property var targetFlickable: null

    readonly property bool _target: targetFlickable !== null
    readonly property bool _hasOverflow: _target && targetFlickable.contentHeight > targetFlickable.height + 1
    readonly property bool _isMoving: _target && (targetFlickable.moving || targetFlickable.flicking)
    readonly property bool _shouldShow: hoverArea.containsMouse || _isMoving || _scrollBarActive
    readonly property real _originY: _target ? targetFlickable.originY : 0
    readonly property real _scrollRange: _target
        ? Math.max(0, targetFlickable.contentHeight - targetFlickable.height)
        : 0
    readonly property real _scrollRatio: _scrollRange > 0
        ? Math.max(0, Math.min(1, (targetFlickable.contentY - _originY) / _scrollRange))
        : 0

    property bool _scrollBarActive: false

    // Keep the hit area alive while faded out so hovering the track can show it.
    visible: _hasOverflow
    width: 8
    z: 1000

    opacity: (_hasOverflow && _shouldShow) ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    // Thumb size follows viewport/content ratio; position follows contentY.
    Rectangle {
        id: thumb

        readonly property real _hRatio: root._target
            ? Math.min(1, Math.max(0, root.targetFlickable.height / Math.max(1, root.targetFlickable.contentHeight)))
            : 1

        x: 0
        width: parent.width
        radius: width / 2
        color: root._shouldShow ? Theme.colors.outline : Theme.colors.outlineVariant
        opacity: root._shouldShow ? 1.0 : 0.6

        height: Math.min(root.height, Math.max(24, root.height * _hRatio))
        y: Math.max(0, Math.min(root.height - height,
            (root.height - height) * root._scrollRatio))

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }
    }
    // Combined hover + drag area
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function setScrollFromPointer(pointerY) {
            if (!root._target) return;
            var trackLength = Math.max(0, root.height - thumb.height);
            var ratio = trackLength > 0
                ? Math.max(0, Math.min(1, (pointerY - thumb.height / 2) / trackLength))
                : 0;
            root.targetFlickable.contentY = root._originY + ratio * root._scrollRange;
        }
        onPressed: function(mouse) {
            setScrollFromPointer(mouse.y);
        }
        onPositionChanged: function(mouse) {
            if (!pressed) return;
            setScrollFromPointer(mouse.y);
        }
    }

    // Auto-hide timer
    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root._scrollBarActive = false
    }

    // React to target movement to activate show/hide cycle
    Connections {
        target: root._target ? root.targetFlickable : null
        enabled: root._target
        function onMovementStarted() {
            root._scrollBarActive = true;
            hideTimer.stop();
        }
        function onMovementEnded() {
            hideTimer.restart();
        }
    }
}
