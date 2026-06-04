import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service

    visible: service.available
    implicitWidth: visible ? audioRow.implicitWidth : 0
    implicitHeight: 26

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.service.toggleMute()
        onWheel: event => {
            root.service.changeVolume(event.angleDelta.y > 0 ? 0.02 : -0.02);
            event.accepted = true;
        }
    }

    RowLayout {
        id: audioRow
        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        MaterialIcon {
            name: root.service.muted ? "volume_off" : root.service.volume >= 0.55 ? "volume_up" : "volume_down"
            size: 18
            filled: !root.service.muted
            iconColor: root.service.muted ? Theme.colors.subtleText : Theme.colors.primary
        }

        StyledText {
            Layout.preferredWidth: percentMetrics.width
            text: root.service.percentText
            color: root.service.muted ? Theme.colors.subtleText : Theme.colors.text
            font.pixelSize: Theme.font.xs
            font.family: Theme.font.familyMono
            horizontalAlignment: Text.AlignRight

            TextMetrics {
                id: percentMetrics
                text: "150%"
                font.family: Theme.font.familyMono
                font.pixelSize: Theme.font.xs
            }
        }
    }
}
