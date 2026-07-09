pragma Singleton

import QtQuick

QtObject {
    readonly property QtObject bar: QtObject {
        property string position: SettingsData.barPosition
        property string style: SettingsData.barStyle
        property bool showBackground: SettingsData.barShowBackground
        property int height: SettingsData.barHeight
        property int iconButtonSize: SettingsData.barIconButtonSize
        property int sideMargin: SettingsData.barSideMargin
        property int groupSpacing: SettingsData.barGroupSpacing
    }

    readonly property QtObject sidebar: QtObject {
        property int width: SettingsData.sidebarWidth
        property int margin: 14
        property int topMargin: 14
        property int bottomMargin: 14
        property int contentPadding: 20
        property int cardPadding: 16
        property int toggleHeight: 86
        property int iconButtonSize: 40
        property real wheelScrollFactor: SettingsData.sidebarWheelScrollFactor
    }

    readonly property QtObject notifications: QtObject {
        property int maxHistoryCount: SettingsData.notificationMaxHistoryCount
        property int maxHistoryPerApp: SettingsData.notificationMaxHistoryPerApp
        property int previewCount: SettingsData.notificationPreviewCount
        property int expandedPreviewCount: SettingsData.notificationExpandedPreviewCount
        property bool debugSeedNotifications: false
        property int debugSeedNotificationCount: 300
    }
}
