import QtQuick
import Quickshell.Io
import QtQuick.Layouts
import "../../common/"
import "../widgets/"

// AppearanceTab — theme + motion settings.

ColumnLayout {
    id: root

    required property var settingsData

    spacing: 16
    Layout.fillWidth: true

    // --- Theme ---
    SettingsSectionHeader {
        title: "Theme"
    }

    SettingsSegmentedRow {
        label: "Mode"
        value: root.settingsData.themeMode
        options: [
            { label: "Dark", value: "dark" },
            { label: "Light", value: "light" },
            { label: "Auto", value: "auto" }
        ]
        selectedCallback: (val) => root.settingsData.set("themeMode", val)
    }
        // Auto mode config — shown only when mode is "auto"
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.settingsData.themeMode === "auto"
            spacing: 12

            SettingsSegmentedRow {
                label: "Auto mode"
                value: root.settingsData.autoMode
                options: [
                    { label: "Time", value: "time" },
                    { label: "Sun", value: "sun" }
                ]
                selectedCallback: (val) => root.settingsData.set("autoMode", val)
            }

            // Time config
            ColumnLayout {
                visible: root.settingsData.autoMode === "time"
                spacing: 12

                TimeField {
                    label: "Dark from"
                    value: root.settingsData.autoTimeStart
                    onCommit: (v) => root.settingsData.set("autoTimeStart", v)
                }

                TimeField {
                    label: "Light from"
                    value: root.settingsData.autoTimeEnd
                    onCommit: (v) => root.settingsData.set("autoTimeEnd", v)
                }

                StyledText {
                    text: "Dark mode starts at the \"Dark from\" time and ends at the \"Light from\" time."
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.subtleText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // Sun config
            ColumnLayout {
                visible: root.settingsData.autoMode === "sun"
                spacing: 12

                TextField {
                    label: "Latitude"
                    value: root.settingsData.autoLat.toFixed(4)
                    onCommit: (v) => root.settingsData.set("autoLat", parseFloat(v) || 0)
                }

                TextField {
                    label: "Longitude"
                    value: root.settingsData.autoLng.toFixed(4)
                    onCommit: (v) => root.settingsData.set("autoLng", parseFloat(v) || 0)
                }

                StyledText {
                    text: "Enter your coordinates. The theme will switch at your local sunrise and sunset times. (0,0) falls back to Time mode."
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.subtleText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            StyledText {
                text: "Requires niri-strata-auto-theme daemon to be running."
                font.pixelSize: Theme.font.xs
                color: Theme.colors.warningColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // --- Time field component ---
        component TimeField: RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            property string label
            property string value
            signal commit(string v)

            StyledText {
                text: label
                font.pixelSize: Theme.font.sm
                color: Theme.colors.mutedText
                Layout.preferredWidth: 120
            }

            Rectangle {
                width: 64
                height: 28
                radius: Theme.rounding.xs
                color: Theme.colors.surfaceContainerHigh
                border.width: Theme.elevation.outlineWidth
                border.color: Theme.colors.outlineVariant

                TextInput {
                    id: timeInput
                    anchors.fill: parent
                    anchors.margins: 4
                    color: Theme.colors.text
                    font.family: Theme.font.familyMono
                    font.pixelSize: Theme.font.sm
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    maximumLength: 5
                    inputMask: "99:99"
                    activeFocusOnPress: true
                    autoScroll: true
                    Component.onCompleted: text = value
                    onAccepted: commit(text)
                }
            }
        }

        // --- Text field component ---
        component TextField: RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.md

            property string label
            property string value
            signal commit(string v)

            StyledText {
                text: label
                font.pixelSize: Theme.font.sm
                color: Theme.colors.mutedText
                Layout.preferredWidth: 120
            }

            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: Theme.rounding.xs
                color: Theme.colors.surfaceContainerHigh
                border.width: Theme.elevation.outlineWidth
                border.color: Theme.colors.outlineVariant
                clip: true

                TextInput {
                    id: textInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    color: Theme.colors.text
                    font.family: Theme.font.familyMono
                    font.pixelSize: Theme.font.sm
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    activeFocusOnPress: true
                    autoScroll: true
                    Component.onCompleted: text = value
                    onAccepted: commit(text)
                }
            }
        }

    SettingsSegmentedRow {
        label: "Preset"
        value: root.settingsData.themeId
        options: [
            { label: "Default", value: "default" },
            { label: "Blue", value: "blue" },
            { label: "Green", value: "green" },
            { label: "Rose", value: "rose" },
            { label: "Amber", value: "amber" },
            { label: "Neutral", value: "neutral" },
            { label: "Dynamic", value: "dynamic" }
        ]
        selectedCallback: (val) => root.settingsData.set("themeId", val)
    }

    // Dynamic mode config — shown only when preset is "dynamic"
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.settingsData.themeId === "dynamic"
        spacing: 12

        RowLayout {
            spacing: 8

            TextField {
                label: "Wallpaper"
                value: root.settingsData.wallpaperPath
                onCommit: (v) => root.settingsData.set("wallpaperPath", v)
                Layout.fillWidth: true
            }

            IconButton {
                icon: "folder_open"
                size: 28
                iconSize: 16
                onClicked: {
                    wallpaperPicker.command = [
                        "zenity", "--file-selection",
                        "--title=Select wallpaper",
                        "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp *.gif",
                    ];
                    wallpaperPicker.running = true;
                }
            }
        }

        RowLayout {
            spacing: 8

            IconButton {
                icon: "auto_awesome"
                size: 28
                iconSize: 16
                onClicked: {
                    if (typeof themeEngine !== "undefined") {
                        if (root.settingsData.wallpaperPath.length > 0)
                            themeEngine.generate(root.settingsData.wallpaperPath);
                        else
                            themeEngine.generateFromHex("#42a5f5");
                    }
                }
            }

            StyledText {
                text: {
                    if (typeof themeEngine === "undefined") return "ThemeEngine not available";
                    if (themeEngine.status === "generating") return "Generating...";
                    if (themeEngine.status === "ready") return "Palette ready";
                    if (themeEngine.status === "error") return "Error: " + themeEngine.errorMessage;
                    return "Click to generate palette";
                }
                font.pixelSize: Theme.font.xs
                color: {
                    if (typeof themeEngine === "undefined") return Theme.colors.errorColor;
                    if (themeEngine.status === "error") return Theme.colors.errorColor;
                    if (themeEngine.status === "ready") return Theme.colors.successColor;
                    return Theme.colors.subtleText;
                }
            }
        }

        StyledText {
            text: "Requires matugen. Enter a wallpaper path or leave empty to generate from the default blue accent."
            font.pixelSize: Theme.font.xs
            color: Theme.colors.subtleText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Process {
            id: wallpaperPicker
            command: []
            stdout: StdioCollector {
                onStreamFinished: {
                    var path = text.trim();
                    if (path.length > 0) {
                        root.settingsData.set("wallpaperPath", path);
                        if (typeof themeEngine !== "undefined")
                            themeEngine.generate(path);
                    }
                }
            }
        }
    }
    // ── Wallpaper manager ──
    SettingsSectionHeader {
        title: "Wallpaper"
    }

    // Backend selection
    SettingsSegmentedRow {
        label: "Backend"
        value: root.settingsData.wallpaperBackend
        options: {
            var opts = [];
            if (typeof wallpaperService !== "undefined" && wallpaperService.swwwAvailable)
                opts.push({ label: "swww", value: "swww" });
            if (typeof wallpaperService !== "undefined" && wallpaperService.swaybgAvailable)
                opts.push({ label: "swaybg", value: "swaybg" });
            if (opts.length === 0)
                opts.push({ label: "None", value: "none" });
            return opts;
        }
        selectedCallback: (val) => root.settingsData.set("wallpaperBackend", val)
    }

    // Fill mode
    SettingsSegmentedRow {
        label: "Fill mode"
        value: root.settingsData.wallpaperFillMode
        options: {
            var modes = ["fill", "fit", "center", "tile", "stretch"];
            if (root.settingsData.wallpaperBackend === "swww")
                modes = ["fill"];
            return modes.map(m => ({ label: m.charAt(0).toUpperCase() + m.slice(1), value: m }));
        }
        selectedCallback: (val) => root.settingsData.set("wallpaperFillMode", val)
    }

    // Background color swatches
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            text: "BG color"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            Layout.preferredWidth: 120
        }

        Repeater {
            model: ["#000000", "#1a1a2e", "#2d2d44", "#0f3460", "#16213e", "#ffffff"]

            Rectangle {
                required property var modelData
                width: 24
                height: 24
                radius: 12
                color: modelData
                border.width: root.settingsData.wallpaperBgColor === modelData ? 3 : 0
                border.color: Theme.colors.text

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsData.set("wallpaperBgColor", modelData)
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // Per-monitor toggle
    SettingsToggleRow {
        label: "Per-monitor"
        description: "Set independent wallpaper for each display"
        checked: root.settingsData.wallpaperPerMonitor
        toggleCallback: (val) => root.settingsData.set("wallpaperPerMonitor", val)
    }

    // Monitor selector (when per-monitor is on)
    SettingsSegmentedRow {
        visible: root.settingsData.wallpaperPerMonitor
        label: "Monitor"
        value: ""
        options: {
            if (typeof Quickshell === "undefined") return [];
            return Quickshell.screens.map(s => ({ label: s.name, value: s.name }));
        }
        selectedCallback: (val) => { root._selectedMonitor = val; }
    }

    property string _selectedMonitor: ""

    // Wallpaper folders list
    SettingsSectionHeader {
        title: "Folders"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: {
                try { return JSON.parse(root.settingsData.wallpaperDirs); }
                catch(e) { return []; }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: modelData
                    font.pixelSize: Theme.font.xs
                    color: Theme.colors.subtleText
                    Layout.fillWidth: true
                    elide: Text.ElideLeft
                }

                IconButton {
                    icon: "close"
                    size: 24
                    iconSize: 14
                    onClicked: {
                        var dirs = [];
                        try { dirs = JSON.parse(root.settingsData.wallpaperDirs); } catch(e) {}
                        dirs.splice(index, 1);
                        root.settingsData.set("wallpaperDirs", JSON.stringify(dirs));
                        root._rescanWallpapers();
                    }
                }
            }
        }

        RowLayout {
            spacing: 8

            IconButton {
                icon: "folder_open"
                size: 28
                iconSize: 16
                onClicked: {
                    folderPicker.command = [
                        "zenity", "--file-selection", "--directory",
                        "--title=Select wallpaper folder",
                    ];
                    folderPicker.running = true;
                }
            }

            StyledText {
                text: "Add folder"
                font.pixelSize: Theme.font.sm
                color: Theme.colors.subtleText
            }
        }

        Process {
            id: folderPicker
            command: []
            stdout: StdioCollector {
                onStreamFinished: {
                    var dir = text.trim();
                    if (dir.length > 0) {
                        var dirs = [];
                        try { dirs = JSON.parse(root.settingsData.wallpaperDirs); } catch(e) {}
                        if (dirs.indexOf(dir) < 0) {
                            dirs.push(dir);
                            root.settingsData.set("wallpaperDirs", JSON.stringify(dirs));
                            root._rescanWallpapers();
                        }
                    }
                }
            }
        }
    }

    // Wallpaper grid
    WallpaperGrid {
        id: wallpaperGrid
        Layout.fillWidth: true
        Layout.preferredHeight: 300
        sortBy: root.settingsData.wallpaperSortBy
        sortOrder: root.settingsData.wallpaperSortOrder
        recursive: root.settingsData.wallpaperRecursive
        selectedPath: root.settingsData.wallpaperPath

        onRescan: root._rescanWallpapers()
        onImageClicked: function(path) {
            root.settingsData.set("wallpaperPath", path);
            var output = root.settingsData.wallpaperPerMonitor ? root._selectedMonitor : "";
            if (typeof wallpaperService !== "undefined")
                wallpaperService.applyWallpaper(path, output);
            if (typeof themeEngine !== "undefined")
                themeEngine.generate(path);
        }
    }

    // Conflict warning
    StyledText {
        visible: typeof wallpaperService !== "undefined" && wallpaperService.detectedConflicts.length > 0
        text: "⚠ Detected running: " + (wallpaperService ? wallpaperService.detectedConflicts.join(", ") : "") + ". Stop them before applying."
        font.pixelSize: Theme.font.xs
        color: Theme.colors.warningColor
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    function _rescanWallpapers() {
        if (typeof wallpaperService === "undefined") return;
        var dirs = [];
        try { dirs = JSON.parse(root.settingsData.wallpaperDirs); } catch(e) {}
        wallpaperService.scanFolders(
            dirs,
            root.settingsData.wallpaperRecursive,
            root.settingsData.wallpaperSortBy,
            root.settingsData.wallpaperSortOrder
        );
    }

    Connections {
        target: typeof wallpaperService !== "undefined" ? wallpaperService : null
        function onImagesReady(paths) {
            // Update the grid's imageList
            wallpaperGrid.imageList = paths;
        }
    }

    // Accent color swatches
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 0
        spacing: 8

        StyledText {
            text: "Accent"
            font.pixelSize: Theme.font.sm
            color: Theme.colors.mutedText
            Layout.preferredWidth: 120
        }

        Repeater {
            model: [
                { hex: "", label: "Default" },
                { hex: "#42a5f5", label: "Blue" },
                { hex: "#66bb6a", label: "Green" },
                { hex: "#f48fb1", label: "Rose" },
                { hex: "#ffc870", label: "Amber" },
                { hex: "#ef5350", label: "Red" },
                { hex: "#ab47bc", label: "Purple" }
            ]

            Rectangle {
                required property var modelData
                width: 28
                height: 28
                radius: 14
                color: String(modelData.hex).length > 0 ? modelData.hex : Theme.colors.presetPrimary
                border.width: root.settingsData.accentColor === String(modelData.hex) ? 3 : 0
                border.color: Theme.colors.text

                Behavior on border.width {
                    NumberAnimation { duration: 120 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsData.set("accentColor", modelData.hex)
                }

                StyledText {
                    anchors.top: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 2
                    text: modelData.label
                    font.pixelSize: 9
                    color: Theme.colors.subtleText
                    visible: false // tooltip only — labels would overflow
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // --- System theme ---
    SettingsSectionHeader {
        title: "System Theme"
    }

    SettingsToggleRow {
        label: "Export to system apps"
        description: "Apply current Quickshell colors to GTK and Qt applications"
        checked: root.settingsData.systemThemeEnabled
        toggleCallback: (val) => root.settingsData.set("systemThemeEnabled", val)
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        visible: root.settingsData.systemThemeEnabled
        spacing: 12

        SettingsToggleRow {
            label: "GTK"
            checked: root.settingsData.systemThemeGtkEnabled
            toggleCallback: (val) => root.settingsData.set("systemThemeGtkEnabled", val)
        }

        SettingsToggleRow {
            label: "Qt"
            checked: root.settingsData.systemThemeQtEnabled
            toggleCallback: (val) => root.settingsData.set("systemThemeQtEnabled", val)
        }

        SettingsToggleRow {
            label: "Apply on mode change"
            description: "Re-export when light/dark mode switches"
            checked: root.settingsData.systemThemeApplyOnModeChange
            toggleCallback: (val) => root.settingsData.set("systemThemeApplyOnModeChange", val)
        }

        RowLayout {
            spacing: 8

            IconButton {
                icon: "sync"
                size: 28
                iconSize: 16
                onClicked: {
                    if (typeof themeExport !== "undefined")
                        themeExport.exportAll();
                }
            }

            StyledText {
                text: {
                    if (typeof themeExport === "undefined") return "ThemeExport not available";
                    if (themeExport.lastStatus === "exporting") return "Exporting...";
                    if (themeExport.lastStatus === "done") return "Export complete";
                    if (themeExport.lastStatus === "error") return "Error: " + themeExport.lastError;
                    return "Click to export now";
                }
                font.pixelSize: Theme.font.xs
                color: {
                    if (typeof themeExport === "undefined") return Theme.colors.errorColor;
                    if (themeExport.lastStatus === "error") return Theme.colors.errorColor;
                    if (themeExport.lastStatus === "done") return Theme.colors.successColor;
                    return Theme.colors.subtleText;
                }
            }
        }
    }
    // --- Motion ---
    SettingsSectionHeader {
        title: "Motion"
    }

    SettingsSegmentedRow {
        label: "Animation speed"
        value: root.settingsData.motionSpeed
        options: [
            { label: "Slower", value: "slower" },
            { label: "Normal", value: "normal" },
            { label: "Faster", value: "faster" }
        ]
        selectedCallback: (val) => root.settingsData.set("motionSpeed", val)
    }

    SettingsSliderRow {
        label: "Workspace animation duration"
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

    // Bottom spacer so the last row isn't flush against the card edge
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
    }
}