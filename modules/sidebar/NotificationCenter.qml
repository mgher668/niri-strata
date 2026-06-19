import QtQuick
import QtQuick.Layouts
import "../common/"

ColumnLayout {
    id: root

    required property var service

    spacing: Theme.spacing.md

    RowLayout {
        id: headerRow

        Layout.fillWidth: true
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "notifications"
            title: "Notifications"
            subtitle: root.service.hasNotifications ? `${root.service.count} recent in ${root.service.groupCount} apps` : "All clear"
            active: root.service.doNotDisturb

            ActionChip {
                text: root.service.doNotDisturb ? "DND on" : "DND off"
                icon: "notifications_off"
                active: root.service.doNotDisturb
                onTriggered: root.service.toggleDoNotDisturb()
            }

            ActionChip {
                text: "Clear"
                icon: "clear_all"
                enabled: root.service.hasNotifications
                onTriggered: root.service.clearAll()
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !root.service.hasNotifications
        text: "No notifications"
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.font.sm
        color: Theme.colors.subtleText
    }

    ListView {
        id: notificationsView

        Layout.fillWidth: true
        implicitHeight: contentHeight
        visible: root.service.hasNotifications
        spacing: Theme.spacing.md
        model: root.service.appNameList
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 180

        delegate: NotificationGroupCard {
            required property string modelData

            width: ListView.view.width
            service: root.service
            notificationGroup: root.service.groupForApp(modelData)
        }
    }
}
