import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// BarTab — bar layout, sizing, and canvas shape settings.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    // --- Layout ---
    SettingsSectionHeader {
        title: "Layout"
    }

    SettingsSegmentedRow {
        label: "Position"
        value: root.settingsData.barPosition
        options: [
            { label: "Top", value: "top" },
            { label: "Bottom", value: "bottom" }
        ]
        selectedCallback: (val) => root.settingsData.set("barPosition", val)
    }

    SettingsToggleRow {
        label: "Show background"
        checked: root.settingsData.barShowBackground
        toggleCallback: (val) => root.settingsData.set("barShowBackground", val)
    }

    // --- Sizing ---
    SettingsSectionHeader {
        title: "Sizing"
    }

    SettingsSliderRow {
        label: "Height"
        value: root.settingsData.barHeight
        minValue: 28
        maxValue: 60
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("barHeight", val)
    }

    SettingsSliderRow {
        label: "Icon button size"
        value: root.settingsData.barIconButtonSize
        minValue: 20
        maxValue: 40
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("barIconButtonSize", val)
    }

    SettingsSliderRow {
        label: "Side margin"
        value: root.settingsData.barSideMargin
        minValue: 0
        maxValue: 40
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("barSideMargin", val)
    }

    SettingsSliderRow {
        label: "Group spacing"
        value: root.settingsData.barGroupSpacing
        minValue: 0
        maxValue: 30
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("barGroupSpacing", val)
    }

    // --- Canvas Shape ---
    SettingsSectionHeader {
        title: "Canvas Shape"
    }

    SettingsSliderRow {
        label: "Wing radius"
        value: root.settingsData.barWingRadius
        minValue: 0
        maxValue: 20
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("barWingRadius", val)
    }

    SettingsSliderRow {
        label: "Bottom radius"
        value: root.settingsData.barBottomRadius
        minValue: 0
        maxValue: 30
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("barBottomRadius", val)
    }

    SettingsToggleRow {
        label: "Flatten on maximized"
        checked: root.settingsData.barFlattenOnMaximized
        toggleCallback: (val) => root.settingsData.set("barFlattenOnMaximized", val)
    }

    // Bottom spacer
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
    }
}