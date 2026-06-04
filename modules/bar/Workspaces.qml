import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var state
    property string outputName: ""

    property var workspaces: outputName.length > 0
        ? state.workspaces.filter(workspace => workspace.output === outputName)
        : state.workspaces
    readonly property int itemSize: 28
    readonly property int itemSpacing: 4
    implicitWidth: Math.max(1, workspaces.length) * itemSize + Math.max(0, workspaces.length - 1) * itemSpacing
    implicitHeight: itemSize

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
        spacing: root.itemSpacing

        Repeater {
            model: root.workspaces

            Rectangle {
                id: workspaceButton

                required property var modelData
                property bool active: modelData.isActive
                property bool focused: modelData.isFocused
                property bool occupied: modelData.occupied
                property bool urgent: modelData.isUrgent
                property bool hovered: mouseArea.containsMouse

                width: root.itemSize
                height: root.itemSize
                radius: Theme.rounding.full
                color: active
                    ? Theme.colors.primary
                    : urgent
                        ? Theme.colors.errorColor
                        : occupied
                            ? Theme.colors.primaryContainer
                            : hovered
                                ? Theme.colors.layer1Hover
                                : Theme.colors.transparent
                border.width: focused && !active ? 1 : 0
                border.color: Theme.colors.primary

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animation.fast
                        easing.type: Theme.animation.easing
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animation.normal
                        easing.type: Theme.animation.easing
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: Theme.font.sm
                    horizontalAlignment: Text.AlignHCenter
                    color: active ? Theme.colors.primaryText
                        : occupied ? Theme.colors.primaryContainerText
                        : Theme.colors.mutedText
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.state.focusWorkspace(modelData)
                }
            }
        }
    }
}
