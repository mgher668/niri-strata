pragma Singleton

import QtQuick

QtObject {
    readonly property QtObject bar: QtObject {
        property string position: "top"
        property string style: "floating"
        property bool showBackground: true
        property int height: 34
        property int iconButtonSize: 26
        property int sideMargin: 10
        property int groupSpacing: 8
    }

    readonly property QtObject sidebar: QtObject {
        property int width: 440
        property int margin: 14
        property int topMargin: 14
        property int bottomMargin: 14
        property int contentPadding: 20
        property int cardPadding: 16
        property int toggleHeight: 86
        property int iconButtonSize: 40
        property real wheelScrollFactor: 1.2
    }

    readonly property QtObject notifications: QtObject {
        property int maxHistoryCount: 500
        property int maxHistoryPerApp: 200
        property int previewCount: 2
        property int expandedPreviewCount: 8
        property bool debugSeedNotifications: false
        property int debugSeedNotificationCount: 300
    }
}
