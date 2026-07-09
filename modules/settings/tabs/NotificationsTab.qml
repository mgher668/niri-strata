import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// NotificationsTab — history + preview settings.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    // --- History section ---
    SettingsSectionHeader {
        title: "History"
    }

    SettingsSliderRow {
        label: "Max history count"
        value: root.settingsData.notificationMaxHistoryCount
        minValue: 0
        maxValue: 5000
        stepSize: 50
        unit: ""
        valueChangedCallback: (val) => root.settingsData.set("notificationMaxHistoryCount", val)
    }

    SettingsSliderRow {
        label: "Max per app"
        value: root.settingsData.notificationMaxHistoryPerApp
        minValue: 0
        maxValue: 2000
        stepSize: 10
        unit: ""
        valueChangedCallback: (val) => root.settingsData.set("notificationMaxHistoryPerApp", val)
    }

    // --- Preview section ---
    SettingsSectionHeader {
        title: "Preview"
    }

    SettingsSliderRow {
        label: "Preview count"
        value: root.settingsData.notificationPreviewCount
        minValue: 0
        maxValue: 20
        stepSize: 1
        unit: ""
        valueChangedCallback: (val) => root.settingsData.set("notificationPreviewCount", val)
    }

    SettingsSliderRow {
        label: "Expanded preview count"
        value: root.settingsData.notificationExpandedPreviewCount
        minValue: 0
        maxValue: 50
        stepSize: 1
        unit: ""
        valueChangedCallback: (val) => root.settingsData.set("notificationExpandedPreviewCount", val)
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}