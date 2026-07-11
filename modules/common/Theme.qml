pragma Singleton

import QtQuick
import "ThemePresets.js" as Presets

QtObject {
    id: root

    // --- Theme resolution ---
    // themeMode: user choice (dark/light/auto), NEVER changed by daemon.
    // _autoLight: runtime value from daemon, NOT persisted. Only used when themeMode == "auto".
    property bool _autoLight: {
        // Warm start: guess from local hour before daemon kicks in
        var h = new Date().getHours();
        return h >= 6 && h < 18;
    }

    readonly property bool _isLight: {
        if (typeof SettingsData === "undefined")
            return false;
        var mode = SettingsData.themeMode;
        if (mode === "auto")
            return root._autoLight;
        return mode === "light";
    }

    readonly property string _themeId: {
        if (typeof SettingsData === "undefined")
            return "default";
        return SettingsData.themeId || "default";
    }

    readonly property string _accentColor: {
        if (typeof SettingsData === "undefined")
            return "";
        return SettingsData.accentColor || "";
    }

    // Dynamic palette from matugen (set by ThemeEngine), or preset palette.
    // When themeId === "dynamic" and _dynamicPalette has content, use it;
    // otherwise fall back to "default" preset.
    readonly property var _basePalette: {
        if (_themeId === "dynamic" && _dynamicPalette) {
            return _isLight ? _dynamicPalette.light : _dynamicPalette.dark;
        }
        return Presets.getPreset(_themeId, _isLight);
    }

    // Set by ThemeEngine.paletteReady signal (via shell.qml wiring).
    // Null when no dynamic palette has been generated yet.
    property var _dynamicPalette: null

    readonly property var _palette: Presets.applyAccent(_basePalette, _accentColor)

    readonly property QtObject colors: QtObject {
        property color background: root._palette.background
        property color surface: root._palette.surface
        property color layer0: root._palette.layer0
        property color layer1: root._palette.layer1
        property color layer1Hover: root._palette.layer1Hover
        property color layer1Active: root._palette.layer1Active
        property color surfaceContainerLowest: root._palette.surfaceContainerLowest
        property color surfaceContainerLow: root._palette.surfaceContainerLow
        property color surfaceContainer: root._palette.surfaceContainer
        property color surfaceContainerHigh: root._palette.surfaceContainerHigh
        property color surfaceContainerHighest: root._palette.surfaceContainerHighest
        property color text: root._palette.text
        property color mutedText: root._palette.mutedText
        property color subtleText: root._palette.subtleText
        property color primary: root._palette.primary
        property color presetPrimary: root._basePalette.primary
        property color primaryText: root._palette.primaryText
        property color primaryContainer: root._palette.primaryContainer
        property color primaryContainerText: root._palette.primaryContainerText
        property color secondary: root._palette.secondary
        property color secondaryContainer: root._palette.secondaryContainer
        property color secondaryContainerText: root._palette.secondaryContainerText
        property color tertiary: root._palette.tertiary
        property color tertiaryContainer: root._palette.tertiaryContainer
        property color tertiaryContainerText: root._palette.tertiaryContainerText
        property color successColor: root._palette.successColor
        property color successContainer: root._palette.successContainer
        property color warningColor: root._palette.warningColor
        property color warningContainer: root._palette.warningContainer
        property color errorColor: root._palette.errorColor
        property color errorContainer: root._palette.errorContainer
        property color outline: root._palette.outline
        property color outlineVariant: root._palette.outlineVariant
        property color surfaceHover: root._isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
        property color buttonHover: root._isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)
        property color activeTabBg: root._isLight ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.16)
        property color scrim: "#000000"
        property color shadow: "#000000"
        property color transparent: "transparent"
    }

    readonly property QtObject rounding: QtObject {
        property int xs: 8
        property int sm: 12
        property int md: 18
        property int lg: 24
        property int xl: 30
        property int xxl: 36
        property int full: 999
    }

    readonly property QtObject font: QtObject {
        property string family: "Barlow Medium"
        property string familyText: "Barlow Medium"
        property string familyMono: "JetBrains Mono"
        property string familyIcon: "Material Symbols Rounded"
        property int xs: 11
        property int sm: 13
        property int md: 15
        property int lg: 17
        property int xl: 20
        property int xxl: 24
    }

    readonly property QtObject spacing: QtObject {
        property int xs: 4
        property int sm: 6
        property int md: 8
        property int lg: 12
        property int xl: 16
        property int xxl: 24
    }

    readonly property real _speedFactor: {
        if (typeof SettingsData === "undefined")
            return 1.0;
        if (SettingsData.motionSpeed === "slower")
            return 1.5;
        if (SettingsData.motionSpeed === "faster")
            return 0.6;
        return 1.0;
    }

    readonly property QtObject animation: QtObject {
        property int fast: Math.round(120 * root._speedFactor)
        property int normal: Math.round(220 * root._speedFactor)
        property int slow: Math.round(340 * root._speedFactor)
        property int easing: Easing.OutCubic
        property int emphasized: Easing.OutQuint
    }

    readonly property QtObject elevation: QtObject {
        property int outlineWidth: 1
        property real disabledOpacity: 0.42
        property real pressedScale: 0.97
    }
}