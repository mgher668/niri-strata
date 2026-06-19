import QtQuick
import Quickshell.Services.Notifications
import "../common/"

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
    property int maxHistoryCount: Config.notifications.maxHistoryCount
    property int maxHistoryPerApp: Config.notifications.maxHistoryPerApp
    property int previewCount: Config.notifications.previewCount
    property int expandedPreviewCount: Config.notifications.expandedPreviewCount
    property bool debugSeedNotifications: Config.notifications.debugSeedNotifications
    readonly property int debugSeedNotificationCount: Config.notifications.debugSeedNotificationCount
    property list<NotificationEntry> notifications: []
    readonly property list<NotificationEntry> popupNotifications: notifications.filter(entry => entry.popup)
    readonly property int count: notifications.length
    readonly property int popupCount: popupNotifications.length
    readonly property bool hasNotifications: count > 0
    readonly property var groupsByAppName: groupsForList(notifications)
    readonly property var popupGroupsByAppName: groupsForList(popupNotifications)
    readonly property list<string> appNameList: appNameListForGroups(groupsByAppName)
    readonly property list<string> popupAppNameList: appNameListForGroups(popupGroupsByAppName)
    readonly property int groupCount: appNameList.length

    function appNameForEntry(entry) {
        return entry?.appName?.length > 0 ? entry.appName : "Application";
    }

    function groupsForList(source) {
        const groups = {};

        for (const entry of source) {
            const appName = appNameForEntry(entry);

            if (!groups[appName]) {
                groups[appName] = {
                    appName,
                    appIcon: entry.appIcon,
                    latestTime: entry.createdAt,
                    count: 0,
                    critical: false,
                    notifications: [],
                    previewNotifications: [],
                };
            }

            const group = groups[appName];
            group.notifications.push(entry);
            group.count = group.notifications.length;
            group.latestTime = Math.max(group.latestTime, entry.createdAt);
            group.critical = group.critical || entry.urgency === "critical";

            if (!group.appIcon && entry.appIcon)
                group.appIcon = entry.appIcon;
        }

        for (const appName of Object.keys(groups)) {
            const group = groups[appName];
            group.previewNotifications = group.notifications.slice(0, previewCount);
        }

        return groups;
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((left, right) => {
            const leftGroup = groups[left];
            const rightGroup = groups[right];
            const timeDelta = rightGroup.latestTime - leftGroup.latestTime;

            if (timeDelta !== 0)
                return timeDelta;

            if (leftGroup.critical && !rightGroup.critical)
                return -1;
            if (!leftGroup.critical && rightGroup.critical)
                return 1;

            return left.localeCompare(right);
        });
    }

    function groupForApp(appName) {
        return groupsByAppName[appName] ?? null;
    }

    function popupGroupForApp(appName) {
        return popupGroupsByAppName[appName] ?? null;
    }

    function cleanupEntry(entry, dismissServer) {
        if (!entry)
            return;

        if (entry.timer)
            entry.timer.destroy();

        if (dismissServer)
            dismissServerNotification(entry.notificationId);

        entry.destroy();
    }

    function cappedEntries(entries, dismissDropped) {
        const kept = [];
        const dropped = [];
        const perAppCounts = {};

        for (const entry of entries) {
            const appName = appNameForEntry(entry);
            const appCount = perAppCounts[appName] ?? 0;
            const withinGlobalLimit = maxHistoryCount <= 0 || kept.length < maxHistoryCount;
            const withinAppLimit = maxHistoryPerApp <= 0 || appCount < maxHistoryPerApp;

            if (withinGlobalLimit && withinAppLimit) {
                kept.push(entry);
                perAppCounts[appName] = appCount + 1;
            } else {
                dropped.push(entry);
            }
        }

        for (const entry of dropped)
            cleanupEntry(entry, dismissDropped);

        return kept;
    }

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

        notifications = cappedEntries([entry, ...notifications], true);
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

        notifications = notifications.filter((_, entryIndex) => entryIndex !== index);
        cleanupEntry(entry, dismissServer);
    }

    function dismissNotification(notificationId) {
        const index = notifications.findIndex(entry => entry.notificationId === notificationId);
        removeEntryAt(index, true);
    }

    function clearAll() {
        const current = [...notifications];
        notifications = [];
        for (const entry of current)
            cleanupEntry(entry, true);
    }

    function dismissAppNotifications(appName) {
        const ids = notifications
            .filter(entry => appNameForEntry(entry) === appName)
            .map(entry => entry.notificationId);

        for (const id of ids)
            dismissNotification(id);
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

    function seedDebugNotifications() {
        if (!debugSeedNotifications || notifications.length > 0)
            return;

        const seeded = [];
        const now = Date.now();

        for (let index = 0; index < debugSeedNotificationCount; index++) {
            const messageNumber = debugSeedNotificationCount - index;
            const notification = {
                id: -(index + 1),
                appName: "Telegram",
                summary: `Telegram test message ${messageNumber}`,
                body: `This is seeded notification ${messageNumber} for testing long notification list rendering in Control Center.`,
                appIcon: "telegram",
                image: "",
                urgency: index % 37 === 0 ? "critical" : "normal",
                actions: [],
            };

            const entry = notificationComponent.createObject(root, {
                notificationId: notification.id,
                notification,
                createdAt: now - index * 60000,
                popup: false,
            });
            seeded.push(entry);
        }

        notifications = cappedEntries(seeded, false);
        console.info(`[Notifications] Seeded ${notifications.length} debug notifications across ${Object.keys(groupsForList(notifications)).length} app groups`);
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

    Component.onCompleted: seedDebugNotifications()
}
