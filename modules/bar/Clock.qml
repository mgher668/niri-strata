import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service
    property bool popupOpen: false

    implicitWidth: clockRow.implicitWidth
    implicitHeight: 26

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popupOpen = !root.popupOpen
    }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        MaterialIcon {
            name: "schedule"
            size: 18
            iconColor: Theme.colors.primary
        }

        StyledText {
            text: root.service.timeText
            color: Theme.colors.text
            font.family: Theme.font.familyMono
            font.pixelSize: Theme.font.md
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 12
            radius: 1
            color: Theme.colors.outline
            opacity: 0.7
        }

        StyledText {
            text: root.service.dateText
            color: Theme.colors.mutedText
            font.pixelSize: Theme.font.sm
        }
    }

    PanelPopup {
        open: root.popupOpen
        target: clickArea

        CalendarPopup {
            service: root.service
        }
    }
}
