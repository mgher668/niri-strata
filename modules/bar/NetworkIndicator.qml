import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service

    visible: service.available
    implicitWidth: visible ? networkRow.implicitWidth : 0
    implicitHeight: 26

    RowLayout {
        id: networkRow
        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        MaterialIcon {
            name: root.service.label === "WI" ? "wifi" : "lan"
            size: 18
            filled: root.service.connected
            iconColor: root.service.limited ? Theme.colors.warningColor : Theme.colors.primary
        }

        StyledText {
            Layout.maximumWidth: 120
            text: root.service.nameText
            color: root.service.limited ? Theme.colors.warningColor : Theme.colors.text
            font.pixelSize: Theme.font.xs
            elide: Text.ElideRight
        }

        StyledText {
            text: root.service.detailText
            color: root.service.limited ? Theme.colors.warningColor : Theme.colors.subtleText
            font.pixelSize: Theme.font.xs
            font.family: Theme.font.familyMono
        }
    }
}
