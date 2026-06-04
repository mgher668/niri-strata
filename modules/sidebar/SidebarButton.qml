import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var controller
    required property string outputName

    readonly property bool active: (controller?.open ?? false) && controller.targetOutputName === outputName
    implicitWidth: Config.bar.iconButtonSize
    implicitHeight: Config.bar.iconButtonSize

    IconButton {
        anchors.fill: parent
        icon: "dashboard_customize"
        label: "Control Center"
        active: root.active
        filled: root.active
        iconSize: 21
        showBorder: !root.active
        onClicked: root.controller.toggleForOutput(root.outputName)
    }
}
