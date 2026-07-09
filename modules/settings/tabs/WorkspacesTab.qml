import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// WorkspacesTab — behavior, pill sizing, and animation settings.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    // --- Behavior ---
    SettingsSectionHeader {
        title: "Behavior"
    }

    SettingsToggleRow {
        label: "Drag to reorder"
        description: "Drag workspace pills to rearrange"
        checked: root.settingsData.workspaceDragReorder
        toggleCallback: (val) => root.settingsData.set("workspaceDragReorder", val)
    }

    // --- Pill Sizing ---
    SettingsSectionHeader {
        title: "Pill Sizing"
    }

    SettingsSliderRow {
        label: "Pill height"
        value: root.settingsData.workspacePillHeight
        minValue: 16
        maxValue: 40
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("workspacePillHeight", val)
    }

    SettingsSliderRow {
        label: "Active width"
        value: root.settingsData.workspaceActiveWidth
        minValue: 28
        maxValue: 80
        stepSize: 2
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("workspaceActiveWidth", val)
    }

    SettingsSliderRow {
        label: "Spacing"
        value: root.settingsData.workspacePillSpacing
        minValue: 0
        maxValue: 16
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("workspacePillSpacing", val)
    }

    // --- Animation ---
    SettingsSectionHeader {
        title: "Animation"
    }

    SettingsSliderRow {
        label: "Animation duration"
        value: root.settingsData.workspaceAnimationDuration
        minValue: 0
        maxValue: 800
        stepSize: 10
        unit: "ms"
        valueChangedCallback: (val) => root.settingsData.set("workspaceAnimationDuration", val)
    }

    SettingsSliderRow {
        label: "Quick switch duration"
        value: root.settingsData.workspaceQuickAnimationDuration
        minValue: 0
        maxValue: 500
        stepSize: 10
        unit: "ms"
        valueChangedCallback: (val) => root.settingsData.set("workspaceQuickAnimationDuration", val)
    }

    SettingsSliderRow {
        label: "Drag preview duration"
        value: root.settingsData.workspaceDragPreviewDuration
        minValue: 0
        maxValue: 300
        stepSize: 5
        unit: "ms"
        valueChangedCallback: (val) => root.settingsData.set("workspaceDragPreviewDuration", val)
    }

    // Bottom spacer
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
    }
}