import QtQuick
import QtQuick.Layouts
import "../../common/"

// SettingsSectionHeader — bold section title separating setting groups.

RowLayout {
    id: root

    property string title: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 32
    Layout.bottomMargin: 8
    spacing: 0

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Theme.font.sm
        font.weight: Font.Bold
        color: Theme.colors.text
        horizontalAlignment: Text.AlignLeft
    }
}