import QtQuick
import Quickshell
import Quickshell.Widgets
import "."

Item {
    id: root

    property string appIcon: ""
    property string image: ""
    property string summary: ""
    property string urgency: "normal"
    property int size: 38
    property bool imageLoadFailed: false

    readonly property bool hasAppIcon: appIcon.length > 0
    readonly property bool hasImage: image.length > 0
    readonly property bool showImage: hasImage && !imageLoadFailed
    readonly property bool critical: urgency === "critical"

    function fallbackIcon() {
        const text = summary.toLowerCase();
        if (critical)
            return "priority_high";
        if (text.includes("music") || text.includes("media"))
            return "music_note";
        if (text.includes("download"))
            return "download";
        if (text.includes("battery") || text.includes("power"))
            return "battery_full";
        if (text.includes("bluetooth"))
            return "bluetooth";
        if (text.includes("wifi") || text.includes("network"))
            return "wifi";
        return "notifications";
    }

    implicitWidth: size
    implicitHeight: size

    onImageChanged: imageLoadFailed = false

    Rectangle {
        id: iconFrame

        anchors.fill: parent
        radius: Theme.rounding.full
        color: root.critical ? Theme.colors.errorContainer : Theme.colors.secondaryContainer
        border.width: Theme.elevation.outlineWidth
        border.color: root.critical ? Theme.colors.errorColor : Theme.colors.outlineVariant
        clip: true

        Image {
            anchors.fill: parent
            visible: root.showImage
            source: root.showImage ? root.image : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            onStatusChanged: {
                if (status === Image.Ready) {
                    root.imageLoadFailed = false;
                } else if (status === Image.Error) {
                    root.imageLoadFailed = true;
                }
            }
        }

        IconImage {
            anchors.centerIn: parent
            visible: root.hasAppIcon && !root.showImage
            width: root.size * 0.66
            height: width
            source: root.hasAppIcon ? Quickshell.iconPath(root.appIcon, "image-missing") : ""
            asynchronous: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !root.hasAppIcon && !root.showImage
            name: root.fallbackIcon()
            size: root.size * 0.52
            filled: root.critical
            iconColor: root.critical ? Theme.colors.errorColor : Theme.colors.secondaryContainerText
        }
    }

    Rectangle {
        visible: root.showImage && root.hasAppIcon
        anchors {
            right: parent.right
            bottom: parent.bottom
        }
        width: root.size * 0.46
        height: width
        radius: Theme.rounding.full
        color: Theme.colors.surfaceContainerHighest
        border.width: Theme.elevation.outlineWidth
        border.color: Theme.colors.outlineVariant

        IconImage {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: width
            source: root.hasAppIcon ? Quickshell.iconPath(root.appIcon, "image-missing") : ""
            asynchronous: true
        }
    }
}
