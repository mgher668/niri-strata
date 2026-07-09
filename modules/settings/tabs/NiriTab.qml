import QtQuick
import QtQuick.Layouts
import "../../common/"
import "../../services/"
import "../widgets/"

// NiriTab — manage niri layout fragment.
// Shows include status, setup/apply buttons, fragment preview, and error/success messages.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    NiriConfig {
        id: niriConfig
    }

    Component.onCompleted: niriConfig.check()

    function niriOpts() {
        return {
            gaps: root.settingsData.niriLayoutGaps,
            preset: root.settingsData.niriLayoutPreset,
            focusRingEnabled: root.settingsData.niriFocusRingEnabled,
            focusRingWidth: root.settingsData.niriFocusRingWidth,
            windowCornerRadius: root.settingsData.niriWindowCornerRadius,
            preferNoCsd: root.settingsData.niriPreferNoCsd
        };
    }

    // --- Layout Fragment ---
    SettingsSectionHeader {
        title: "Layout Fragment"
    }

    // Status row
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        spacing: 8

        MaterialIcon {
            name: niriConfig.includePresent ? "check_circle" : "warning"
            size: 18
            iconColor: niriConfig.includePresent ? Theme.colors.successColor : Theme.colors.warningColor
        }

        StyledText {
            Layout.fillWidth: true
            text: niriConfig.includePresent
                ? "Fragment include detected in config.kdl"
                : "No include found — setup needed"
            font.pixelSize: Theme.font.sm
            color: niriConfig.includePresent ? Theme.colors.mutedText : Theme.colors.warningColor
            wrapMode: Text.WordWrap
        }
    }

    // Setup button (only when include is missing)
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        Layout.preferredHeight: 36
        radius: Theme.rounding.sm
        color: setupMouse.containsMouse ? Theme.colors.layer1Hover : Theme.colors.layer1
        border.width: Theme.elevation.outlineWidth
        border.color: Theme.colors.outlineVariant
        visible: !niriConfig.includePresent

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                name: "build"
                size: 16
                iconColor: Theme.colors.primary
            }

            StyledText {
                text: "Setup fragment"
                font.pixelSize: Theme.font.sm
                color: Theme.colors.text
            }
        }

        MouseArea {
            id: setupMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: niriConfig.setup(niriOpts())
        }
    }

    // Settings controls
    SettingsToggleRow {
        label: "Manage niri layout"
        description: "Write a generated fragment to strata/layout.kdl"
        checked: root.settingsData.niriLayoutManaged
        toggleCallback: (val) => root.settingsData.set("niriLayoutManaged", val)
    }

    SettingsSliderRow {
        label: "Window gaps"
        value: root.settingsData.niriLayoutGaps
        minValue: 0
        maxValue: 64
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("niriLayoutGaps", val)
    }

    SettingsSegmentedRow {
        label: "Preset"
        value: root.settingsData.niriLayoutPreset
        options: [
            { label: "Center", value: "center-column" },
            { label: "Left", value: "left-column" },
            { label: "Right", value: "right-column" }
        ]
        selectedCallback: (val) => root.settingsData.set("niriLayoutPreset", val)
    }

    // --- Focus Ring ---
    SettingsSectionHeader {
        title: "Focus Ring"
    }

    SettingsToggleRow {
        label: "Show focus ring"
        description: "Draw a ring around the focused window"
        checked: root.settingsData.niriFocusRingEnabled
        toggleCallback: (val) => root.settingsData.set("niriFocusRingEnabled", val)
    }

    SettingsSliderRow {
        label: "Ring width"
        value: root.settingsData.niriFocusRingWidth
        minValue: 0
        maxValue: 20
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("niriFocusRingWidth", val)
    }

    // --- Window Appearance ---
    SettingsSectionHeader {
        title: "Window Appearance"
    }

    SettingsSliderRow {
        label: "Corner radius"
        value: root.settingsData.niriWindowCornerRadius
        minValue: 0
        maxValue: 30
        stepSize: 1
        unit: "px"
        valueChangedCallback: (val) => root.settingsData.set("niriWindowCornerRadius", val)
    }

    SettingsToggleRow {
        label: "Prefer no CSD"
        description: "Ask apps to omit client-side decorations"
        checked: root.settingsData.niriPreferNoCsd
        toggleCallback: (val) => root.settingsData.set("niriPreferNoCsd", val)
    }

    // Apply button (only when include is present and managed)
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        Layout.preferredHeight: 36
        radius: Theme.rounding.sm
        color: applyMouse.containsMouse ? Qt.lighter(Theme.colors.primary, 1.1) : Theme.colors.primary
        visible: niriConfig.includePresent && root.settingsData.niriLayoutManaged

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                name: "sync"
                size: 16
                iconColor: Theme.colors.primaryText
            }

            StyledText {
                text: "Apply to niri"
                font.pixelSize: Theme.font.sm
                color: Theme.colors.primaryText
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: applyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: niriConfig.apply(niriOpts())
        }
    }

    // Error message
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        Layout.preferredHeight: errorText.implicitHeight + 16
        radius: Theme.rounding.sm
        color: Theme.colors.errorContainer
        visible: niriConfig.lastError.length > 0

        StyledText {
            id: errorText
            anchors.fill: parent
            anchors.margins: 8
            text: niriConfig.lastError
            font.pixelSize: Theme.font.xs
            color: Theme.colors.errorColor
            wrapMode: Text.WordWrap
        }
    }

    // Success message
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        Layout.preferredHeight: statusText.implicitHeight + 16
        radius: Theme.rounding.sm
        color: Theme.colors.successContainer
        visible: niriConfig.lastStatus.length > 0

        StyledText {
            id: statusText
            anchors.fill: parent
            anchors.margins: 8
            text: niriConfig.lastStatus
            font.pixelSize: Theme.font.xs
            color: Theme.colors.successColor
            wrapMode: Text.WordWrap
        }
    }

    // Fragment preview
    SettingsSectionHeader {
        title: "Generated Fragment Preview"
        visible: niriConfig.fragmentPreview.length > 0
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        Layout.preferredHeight: Math.min(160, previewText.implicitHeight + 16)
        radius: Theme.rounding.sm
        color: Theme.colors.surfaceContainerLowest
        border.width: Theme.elevation.outlineWidth
        border.color: Theme.colors.outlineVariant
        visible: niriConfig.fragmentPreview.length > 0
        clip: true

        StyledText {
            id: previewText
            anchors.fill: parent
            anchors.margins: 12
            text: niriConfig.fragmentPreview
            font.family: Theme.font.familyMono
            font.pixelSize: Theme.font.xs
            color: Theme.colors.mutedText
            wrapMode: Text.NoWrap
        }
    }

    // Info text
    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.lg
        Layout.rightMargin: Theme.spacing.lg
        text: "Fragment is written to ~/.config/niri/strata/layout.kdl. Setup backs up config.kdl before inserting the include line."
        font.pixelSize: Theme.font.xs
        color: Theme.colors.subtleText
        wrapMode: Text.WordWrap
    }

    // Bottom spacer
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
    }
}