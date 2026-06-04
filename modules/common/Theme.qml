pragma Singleton

import QtQuick

QtObject {
    readonly property QtObject colors: QtObject {
        property color background: "#101418"
        property color surface: "#101418"
        property color layer0: "#171c20"
        property color layer1: "#1d2328"
        property color layer1Hover: "#283038"
        property color layer1Active: "#333d45"
        property color surfaceContainerLowest: "#0b0f12"
        property color surfaceContainerLow: "#171c20"
        property color surfaceContainer: "#1d2328"
        property color surfaceContainerHigh: "#273038"
        property color surfaceContainerHighest: "#323c45"
        property color text: "#e2e8ee"
        property color mutedText: "#bcc7d0"
        property color subtleText: "#89959f"
        property color primary: "#9bd4ff"
        property color primaryText: "#00344f"
        property color primaryContainer: "#164b68"
        property color primaryContainerText: "#cce7ff"
        property color secondary: "#c0c8d2"
        property color secondaryContainer: "#3f4850"
        property color secondaryContainerText: "#dce4ec"
        property color tertiary: "#dbc0ff"
        property color tertiaryContainer: "#55406f"
        property color tertiaryContainerText: "#eddcff"
        property color successColor: "#9ed9b3"
        property color successContainer: "#1f5234"
        property color warningColor: "#f3cf7a"
        property color warningContainer: "#5a471b"
        property color errorColor: "#ffb4ab"
        property color errorContainer: "#73342d"
        property color outline: "#414b54"
        property color outlineVariant: "#303941"
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

    readonly property QtObject animation: QtObject {
        property int fast: 120
        property int normal: 220
        property int slow: 340
        property int easing: Easing.OutCubic
        property int emphasized: Easing.OutQuint
    }

    readonly property QtObject elevation: QtObject {
        property int outlineWidth: 1
        property real disabledOpacity: 0.42
        property real pressedScale: 0.97
    }
}
