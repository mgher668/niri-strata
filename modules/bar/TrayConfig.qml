import QtQuick

QtObject {
    id: root

    readonly property int maxVisibleItems: 6
    readonly property var pinnedItemTokens: [
        "blueman",
        "fcitx",
        "nm-applet",
        "networkmanager",
    ]
}
