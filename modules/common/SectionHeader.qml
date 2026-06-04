import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    default property alias actions: actionRow.children

    Layout.fillWidth: true
    spacing: Theme.spacing.md

    Rectangle {
        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        radius: Theme.rounding.full
        color: root.active ? Theme.colors.primaryContainer : Theme.colors.surfaceContainerHighest

        MaterialIcon {
            anchors.centerIn: parent
            name: root.icon
            size: 22
            filled: root.active
            iconColor: root.active ? Theme.colors.primaryContainerText : Theme.colors.primary
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.font.lg
            font.weight: Font.DemiBold
            color: Theme.colors.text
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.subtitle.length > 0
            text: root.subtitle
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            elide: Text.ElideRight
        }
    }

    RowLayout {
        id: actionRow
        spacing: Theme.spacing.sm
    }
}
