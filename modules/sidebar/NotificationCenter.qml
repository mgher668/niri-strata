import QtQuick
import QtQuick.Layouts
import "../common/"

ColumnLayout {
    id: root

    required property var service

    spacing: Theme.spacing.md

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.md

        SectionHeader {
            icon: "notifications"
            title: "Notifications"
            subtitle: root.service.hasNotifications ? `${root.service.notifications.length} recent` : "All clear"
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

    Repeater {
        model: root.service.notifications

        DismissibleNotificationCard {
            required property var modelData

            Layout.fillWidth: true
            notification: modelData
            bodyLineCount: 3
            onDismissed: root.service.dismissNotification(modelData.notificationId)
        }
    }
}
