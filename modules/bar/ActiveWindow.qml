import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var state

    property var window: state.focusedWindow
    property var workspace: state.focusedWorkspace ?? state.activeWorkspace
    readonly property bool hasWindow: window !== null && window !== undefined && window.title !== ""

    implicitWidth: 360
    implicitHeight: titleColumn.implicitHeight

    ColumnLayout {
        id: titleColumn
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: -2

        StyledText {
            Layout.fillWidth: true
            text: root.hasWindow ? root.window.appId : "Desktop"
            muted: true
            font.pixelSize: Theme.font.xs
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: root.hasWindow ? root.window.title : (root.workspace ? `Workspace ${root.workspace.label}` : "Workspace")
            font.pixelSize: Theme.font.sm
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
