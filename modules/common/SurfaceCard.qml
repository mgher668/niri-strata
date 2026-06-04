import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    property int padding: Config.sidebar.cardPadding
    property color baseColor: Theme.colors.surfaceContainer
    property color outlineColor: Theme.colors.outlineVariant
    default property alias content: contentItem.data

    Layout.fillWidth: true
    implicitHeight: contentItem.implicitHeight + padding * 2
    radius: Theme.rounding.lg
    color: baseColor
    border.width: Theme.elevation.outlineWidth
    border.color: outlineColor

    Item {
        id: contentItem
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.padding
        }
        implicitHeight: childrenRect.height
    }
}
