import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    component NotificationEntry: QtObject {
        required property int notificationId
        required property var notification
        required property double createdAt
        property bool popup: false
        property Timer timer
        readonly property string appName: notification?.appName || "Application"
        readonly property string summary: notification?.summary || ""
        readonly property string body: notification?.body || ""
        readonly property string appIcon: notification?.appIcon || ""
        readonly property string image: notification?.image || ""
        readonly property string urgency: notification?.urgency?.toString() || "normal"
        readonly property var actions: notification?.actions ?? []
    }

    component PopupTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        repeat: false
        onTriggered: root.timeoutPopup(notificationId)
    }

    property bool doNotDisturb: false
    property list<NotificationEntry> notifications: []
    readonly property list<NotificationEntry> popupNotifications: notifications.filter(entry => entry.popup)
    readonly property int count: notifications.length
    readonly property int popupCount: popupNotifications.length
    readonly property bool hasNotifications: count > 0

    function addNotification(notification) {
        notification.tracked = true;

        const existingIndex = notifications.findIndex(entry => entry.notificationId === notification.id);
        if (existingIndex >= 0)
            removeEntryAt(existingIndex, false);

        const entry = notificationComponent.createObject(root, {
            notificationId: notification.id,
            notification,
            createdAt: Date.now(),
            popup: !doNotDisturb,
        });

        if (entry.popup) {
            const timeout = notification.expireTimeout && notification.expireTimeout > 0
                ? notification.expireTimeout
                : 10000;
            entry.timer = popupTimerComponent.createObject(root, {
                notificationId: entry.notificationId,
                interval: timeout,
            });
        }

        notifications = [entry, ...notifications];
    }

    function dismissServerNotification(notificationId) {
        const tracked = notificationServer.trackedNotifications?.values ?? [];
        const serverNotification = tracked.find(notification => notification.id === notificationId);

        if (!serverNotification || typeof serverNotification.dismiss !== "function")
            return;

        try {
            serverNotification.dismiss();
        } catch (error) {
            console.warn("Failed to dismiss notification:", notificationId, error);
        }
    }

    function removeEntryAt(index, dismissServer) {
        const entry = notifications[index];
        if (!entry)
            return;

        if (entry.timer)
            entry.timer.destroy();

        notifications = notifications.filter((_, entryIndex) => entryIndex !== index);
        if (dismissServer)
            dismissServerNotification(entry.notificationId);
        entry.destroy();
    }

    function dismissNotification(notificationId) {
        const index = notifications.findIndex(entry => entry.notificationId === notificationId);
        removeEntryAt(index, true);
    }

    function clearAll() {
        const current = [...notifications];
        notifications = [];
        for (const entry of current) {
            if (entry.timer)
                entry.timer.destroy();
            dismissServerNotification(entry.notificationId);
            entry.destroy();
        }
    }

    function timeoutPopup(notificationId) {
        const entry = notifications.find(item => item.notificationId === notificationId);
        if (!entry)
            return;

        entry.popup = false;
        if (entry.timer) {
            entry.timer.destroy();
            entry.timer = null;
        }
        notifications = [...notifications];
    }

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
        if (doNotDisturb) {
            for (const entry of notifications)
                entry.popup = false;
            notifications = [...notifications];
        }
    }

    Component {
        id: notificationComponent
        NotificationEntry {}
    }

    Component {
        id: popupTimerComponent
        PopupTimer {}
    }

    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => root.addNotification(notification)
    }
}
