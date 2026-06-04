pragma Singleton

import QtQuick

QtObject {
    readonly property QtObject bar: QtObject {
        property string position: "top"
        property string style: "floating"
        property bool showBackground: true
        property int height: 46
        property int margin: 8
        property int sideMargin: 14
        property int groupSpacing: 10
        property int iconButtonSize: 34
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
}
