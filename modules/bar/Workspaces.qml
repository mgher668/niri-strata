import QtQuick
import QtQuick.Layouts
import "../common/"

// DMS-inspired workspace pills with drag-to-reorder.
// Active = wide pill, inactive = circle. Drag a pill to reorder workspaces.
Item {
    id: root

    required property var state
    property string outputName: ""

    property var workspaces: outputName.length > 0
        ? state.workspaces.filter(workspace => workspace.output === outputName)
        : state.workspaces

    // Pill sizing
    readonly property real pillHeight: 22
    readonly property real activeWidth: 48
    readonly property real inactiveDiameter: pillHeight
    readonly property real pillSpacing: 4
    readonly property real pillRadius: 10
    readonly property int workspaceMotionDuration: 200
    readonly property int workspaceQuickMotionDuration: 120
    readonly property int workspaceDragPreviewDuration: 90
    readonly property int workspaceMotionCadenceMs: 260
    readonly property int workspaceMotionEasingType: Easing.InOutCubic

    // Drag reorder state
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property bool dragActive: false
    property bool dragPendingCommit: false
    property bool suppressTransformAnimation: false
    property bool quickMotion: false
    readonly property bool draggingActiveWorkspace: dragActive
        && dragSourceIndex >= 0
        && dragSourceIndex < workspaces.length
        && workspaces[dragSourceIndex].isActive
    readonly property int activeWorkspaceIndex: {
        const activeIndex = workspaces.findIndex(workspace => workspace.isActive);
        if (activeIndex >= 0)
            return activeIndex;
        return workspaces.findIndex(workspace => workspace.isFocused);
    }

    implicitWidth: Math.max(activeWidth, totalWorkspaceWidth(workspaces))
    implicitHeight: pillHeight

    onWorkspacesChanged: {
        noteWorkspaceMotionChange();
        if (dragActive || dragPendingCommit)
            resetDragState(true);
    }

    Timer {
        id: transformAnimationResetTimer
        interval: 80
        onTriggered: root.suppressTransformAnimation = false
    }

    Timer {
        id: dragWatchdogTimer
        interval: 5000
        onTriggered: root.resetDragState(true)
    }

    Timer {
        id: pendingCommitResetTimer
        interval: 900
        onTriggered: root.resetDragState(true)
    }

    Timer {
        id: motionCadenceTimer
        interval: root.workspaceMotionCadenceMs
        onTriggered: root.quickMotion = false
    }

    function noteWorkspaceMotionChange() {
        quickMotion = motionCadenceTimer.running;
        motionCadenceTimer.restart();
    }

    function workspaceMotionDurationForLayout() {
        return quickMotion ? workspaceQuickMotionDuration : workspaceMotionDuration;
    }

    function workspaceWidth(workspace) {
        return workspace && workspace.isActive && (!dragActive || draggingActiveWorkspace) ? activeWidth : inactiveDiameter;
    }

    function totalWorkspaceWidth(workspaceList) {
        if (!workspaceList || workspaceList.length === 0)
            return inactiveDiameter;

        var total = 0;
        for (var i = 0; i < workspaceList.length; i++)
            total += workspaceWidth(workspaceList[i]);

        return total + Math.max(0, workspaceList.length - 1) * pillSpacing;
    }

    function activeCapsuleX(index) {
        if (index < 0)
            return 0;

        var x = 0;
        for (var i = 0; i < index; i++)
            x += workspaceWidth(root.workspaces[i]) + root.pillSpacing;

        return (root.width - totalWorkspaceWidth(root.workspaces)) / 2 + x;
    }

    function activeCapsuleDragOffset() {
        if (!draggingActiveWorkspace)
            return 0;

        const item = workspaceRepeater.itemAt(dragSourceIndex);
        return item ? item.dragAxisOffset : 0;
    }

    function itemCenter(index) {
        const item = workspaceRepeater.itemAt(index);
        if (item)
            return item.x + item.width / 2;

        var center = 0;
        for (var i = 0; i < root.workspaces.length; i++) {
            const width = workspaceWidth(root.workspaces[i]);
            if (i === index)
                return center + width / 2;
            center += width + root.pillSpacing;
        }

        return 0;
    }

    function clampDragOffset(sourceIndex, offset) {
        if (sourceIndex < 0 || sourceIndex >= root.workspaces.length)
            return 0;

        const sourceCenter = itemCenter(sourceIndex);
        const minOffset = itemCenter(0) - sourceCenter;
        const maxOffset = itemCenter(root.workspaces.length - 1) - sourceCenter;
        return Math.max(minOffset, Math.min(maxOffset, offset));
    }

    function targetIndexForOffset(sourceIndex, offset) {
        if (sourceIndex < 0 || sourceIndex >= root.workspaces.length)
            return -1;

        const draggedCenter = itemCenter(sourceIndex) + offset;
        var closestIndex = sourceIndex;
        var closestDistance = Number.POSITIVE_INFINITY;

        for (var i = 0; i < root.workspaces.length; i++) {
            const distance = Math.abs(draggedCenter - itemCenter(i));
            if (distance < closestDistance) {
                closestDistance = distance;
                closestIndex = i;
            }
        }

        return closestIndex;
    }

    function commitWorkspaceDrag(sourceIndex, targetIndex) {
        if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex)
            return;

        const sourceWorkspace = root.workspaces[sourceIndex];
        const targetWorkspace = root.workspaces[targetIndex];
        if (!sourceWorkspace || !targetWorkspace)
            return;

        const targetNiriIndex = targetWorkspace.idx;
        if (targetNiriIndex === null || targetNiriIndex === undefined)
            return;

        root.state.moveWorkspaceToIndex(sourceWorkspace, targetNiriIndex);
    }

    function resetDragOffsets() {
        for (var i = 0; i < workspaceRepeater.count; i++) {
            const item = workspaceRepeater.itemAt(i);
            if (item)
                item.dragAxisOffset = 0;
        }
    }

    function resetDragState(suppressAnimation) {
        dragWatchdogTimer.stop();
        pendingCommitResetTimer.stop();

        if (suppressAnimation) {
            suppressTransformAnimation = true;
            transformAnimationResetTimer.restart();
        }

        dragActive = false;
        dragPendingCommit = false;
        dragSourceIndex = -1;
        dragTargetIndex = -1;
        resetDragOffsets();
    }

    function beginDrag(sourceIndex) {
        dragActive = true;
        dragPendingCommit = false;
        dragSourceIndex = sourceIndex;
        dragTargetIndex = sourceIndex;
        dragWatchdogTimer.restart();
    }

    function markDragMoved() {
        dragWatchdogTimer.restart();
    }

    function finishDrag(sourceIndex, targetIndex) {
        if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex) {
            resetDragState(true);
            return;
        }

        dragPendingCommit = true;
        pendingCommitResetTimer.restart();
        commitWorkspaceDrag(sourceIndex, targetIndex);
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.state.focusWorkspaceUp();
            else if (event.angleDelta.y < 0)
                root.state.focusWorkspaceDown();
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.pillSpacing

        Repeater {
            id: workspaceRepeater
            model: root.workspaces.length

            Item {
                id: delegate

                required property int index
                property int visualIndex: index
                property var workspace: root.workspaces[index] ?? ({})
                property bool isActive: workspace.isActive ?? false
                property bool isFocused: workspace.isFocused ?? false
                property bool isOccupied: workspace.occupied ?? false
                property bool isUrgent: workspace.isUrgent ?? false
                property bool isHovered: mouseArea.containsMouse && !isActive
                property bool isDragging: root.dragActive && root.dragSourceIndex === visualIndex
                property bool isDropTarget: root.dragTargetIndex === visualIndex
                property real dragAxisOffset: 0
                readonly property real slotWidth: isActive && (!root.dragActive || root.draggingActiveWorkspace) ? root.activeWidth : root.inactiveDiameter
                readonly property int layerZ: isDragging ? 1000
                    : isActive ? 100
                    : isFocused ? 90
                    : isDropTarget ? 80
                    : isHovered ? 10
                    : 1

                // Shift offset: other pills slide aside when dragging
                readonly property real shiftOffset: {
                    if (root.dragSourceIndex < 0 || visualIndex === root.dragSourceIndex)
                        return 0;
                    const dragIdx = root.dragSourceIndex;
                    const dropIdx = root.dragTargetIndex;
                    if (dropIdx < 0)
                        return 0;
                    const draggedWorkspace = root.workspaces[dragIdx];
                    const shiftAmount = root.workspaceWidth(draggedWorkspace) + root.pillSpacing;
                    if (dragIdx < dropIdx && visualIndex > dragIdx && visualIndex <= dropIdx)
                        return -shiftAmount;
                    if (dragIdx > dropIdx && visualIndex >= dropIdx && visualIndex < dragIdx)
                        return shiftAmount;
                    return 0;
                }

                width: slotWidth
                height: root.pillHeight
                z: layerZ

                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: root.inactiveDiameter
                    height: root.inactiveDiameter
                    radius: height / 2
                    color: delegate.isUrgent
                        ? Theme.colors.errorColor
                        : delegate.isOccupied
                            ? Theme.colors.secondaryContainer
                            : delegate.isHovered
                                ? Theme.colors.layer1Hover
                                : Qt.rgba(1, 1, 1, 0.06)

                    border.width: delegate.isDragging ? 1.5 : (delegate.isDropTarget ? 2 : 0)
                    border.color: delegate.isDragging ? Theme.colors.primary
                        : delegate.isDropTarget ? Theme.colors.primary
                        : Theme.colors.primary

                    opacity: delegate.isActive && (!root.dragActive || root.draggingActiveWorkspace) ? 0 : (delegate.isDragging ? 0.7 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animation.normal; easing.type: Theme.animation.emphasized } }
                    Behavior on border.width { NumberAnimation { duration: Theme.animation.normal; easing.type: Theme.animation.emphasized } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animation.fast; easing.type: Theme.animation.emphasized } }
                }

                transform: Translate {
                    id: dragTranslate
                    x: delegate.isDragging ? delegate.dragAxisOffset : delegate.shiftOffset

                    Behavior on x {
                        enabled: !delegate.isDragging && !root.suppressTransformAnimation
                        NumberAnimation {
                            duration: root.dragActive ? root.workspaceDragPreviewDuration : root.workspaceMotionDurationForLayout()
                            easing.type: root.workspaceMotionEasingType
                        }
                    }
                }

                Behavior on width {
                    enabled: !root.dragActive && !root.suppressTransformAnimation
                    NumberAnimation {
                        duration: root.workspaceMotionDurationForLayout()
                        easing.type: root.workspaceMotionEasingType
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    preventStealing: pressed || root.dragActive

                    property bool mousePressed: false
                    property real pressX: 0
                    readonly property real dragThreshold: 5

                    Timer {
                        id: lostReleaseResetTimer
                        interval: 100
                        onTriggered: {
                            if (mouseArea.mousePressed && !mouseArea.pressed && !root.dragPendingCommit)
                                mouseArea.resetDragState();
                        }
                    }

                    function pointerX(mouse) {
                        return delegate.mapToItem(row, mouse.x, mouse.y).x;
                    }

                    function resetDragState() {
                        mousePressed = false;
                        root.resetDragState(true);
                    }

                    onPressed: mouse => {
                        mousePressed = mouse.button === Qt.LeftButton;
                        if (!mousePressed)
                            return;

                        pressX = pointerX(mouse);
                        delegate.dragAxisOffset = 0;
                    }

                    onPositionChanged: mouse => {
                        if (!mousePressed)
                            return;

                        const rawOffset = pointerX(mouse) - pressX;
                        if (!root.dragActive) {
                            if (Math.abs(rawOffset) < dragThreshold)
                                return;

                            root.beginDrag(delegate.visualIndex);
                        }

                        if (root.dragSourceIndex !== delegate.visualIndex)
                            return;

                        root.markDragMoved();
                        delegate.dragAxisOffset = root.clampDragOffset(delegate.visualIndex, rawOffset);
                        const newIndex = root.targetIndexForOffset(delegate.visualIndex, delegate.dragAxisOffset);
                        if (newIndex !== root.dragTargetIndex)
                            root.dragTargetIndex = newIndex;
                    }

                    onReleased: mouse => {
                        const wasDragging = root.dragActive && root.dragSourceIndex === delegate.visualIndex;
                        const sourceIdx = root.dragSourceIndex;
                        const targetIdx = root.dragTargetIndex;

                        lostReleaseResetTimer.stop();
                        mousePressed = false;

                        if (wasDragging) {
                            root.finishDrag(sourceIdx, targetIdx);
                            return;
                        }

                        if (mouse.button === Qt.LeftButton)
                            root.state.focusWorkspace(delegate.workspace);
                    }

                    onCanceled: resetDragState()
                    onPressedChanged: {
                        if (!pressed && mousePressed && !root.dragPendingCommit)
                            lostReleaseResetTimer.restart();
                    }
                }
            }
        }
    }

    Rectangle {
        id: activeCapsule

        visible: root.activeWorkspaceIndex >= 0 && (!root.dragActive || root.draggingActiveWorkspace)
        x: root.activeCapsuleX(root.activeWorkspaceIndex) + root.activeCapsuleDragOffset()
        y: row.y
        width: root.activeWidth
        height: root.pillHeight
        radius: root.pillRadius
        color: Theme.colors.primary
        border.width: 1.5
        border.color: Theme.colors.primary
        z: 200

        Behavior on x {
            enabled: !root.suppressTransformAnimation && !root.draggingActiveWorkspace
            NumberAnimation {
                duration: root.workspaceMotionDurationForLayout()
                easing.type: root.workspaceMotionEasingType
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animation.fast
                easing.type: Theme.animation.emphasized
            }
        }
    }
}
