import QtQuick
import QtQuick.Layouts
import "../common/"

SurfaceCard {
    id: root

    required property var batteryService
    required property var actions

    function batteryIcon() {
        if (!batteryService.present)
            return "power";
        if (batteryService.charging)
            return "battery_charging_full";
        if (batteryService.percent >= 95)
            return "battery_full";
        if (batteryService.percent >= 60)
            return "battery_5_bar";
        if (batteryService.percent >= 35)
            return "battery_3_bar";
        if (batteryService.percent >= 15)
            return "battery_1_bar";
        return "battery_alert";
    }

    RowLayout {
        id: powerContent
        width: parent.width
        spacing: Theme.spacing.lg

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: Theme.rounding.full
            color: batteryService.low ? Theme.colors.warningContainer : Theme.colors.secondaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                name: root.batteryIcon()
                size: 23
                filled: batteryService.present
                iconColor: batteryService.low ? Theme.colors.warningColor : Theme.colors.secondaryContainerText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.xs

            StyledText {
                Layout.fillWidth: true
                text: "Power"
                font.pixelSize: Theme.font.lg
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }

            StyledText {
                Layout.fillWidth: true
                text: batteryService.present ? `${batteryService.percentText} ${batteryService.stateText}` : "AC power"
                font.pixelSize: Theme.font.sm
                color: batteryService.low ? Theme.colors.warningColor : Theme.colors.mutedText
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 132
            spacing: Theme.spacing.xs

            StyledText {
                Layout.fillWidth: true
                text: "Profile"
                font.pixelSize: Theme.font.xs
                color: Theme.colors.subtleText
                horizontalAlignment: Text.AlignRight
            }

            StyledText {
                Layout.fillWidth: true
                text: actions.powerProfileStatus
                font.pixelSize: Theme.font.sm
                color: actions.powerProfileAvailable ? Theme.colors.text : Theme.colors.subtleText
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }
}
