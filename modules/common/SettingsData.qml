pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "settings/SettingsSpec.js" as Spec
import "settings/SettingsStore.js" as Store

// SettingsData — central persisted settings singleton.
// Uses FileView with atomicWrites for safe JSON persistence.
// Self-write guard prevents reload loops from our own writes.

Item {
    id: root

    // --- Parse / load state ---
    readonly property bool loading: _loading
    readonly property bool parseError: _parseError
    readonly property string parseErrorMessage: _parseErrorMessage

    property bool _loading: false
    property bool _parseError: false
    property string _parseErrorMessage: ""
    property bool _selfWrite: false
    property bool _hasLoaded: false

    // --- All 39 settings keys as live properties ---
    readonly property int settingsConfigVersion: _values.configVersion ?? 1
    readonly property string themeMode: _values.themeMode ?? "dark"
    readonly property string themeId: _values.themeId ?? "default"
    readonly property string accentColor: _values.accentColor ?? ""
    readonly property string barPosition: _values.barPosition ?? "top"
    readonly property string barStyle: _values.barStyle ?? "flush"
    readonly property bool barShowBackground: _values.barShowBackground ?? true
    readonly property int barHeight: _values.barHeight ?? 34
    readonly property int barIconButtonSize: _values.barIconButtonSize ?? 26
    readonly property int barSideMargin: _values.barSideMargin ?? 10
    readonly property int barGroupSpacing: _values.barGroupSpacing ?? 8
    readonly property real barWingRadius: _values.barWingRadius ?? 8
    readonly property real barBottomRadius: _values.barBottomRadius ?? 12
    readonly property bool barFlattenOnMaximized: _values.barFlattenOnMaximized ?? true
    readonly property int sidebarWidth: _values.sidebarWidth ?? 440
    readonly property real sidebarWheelScrollFactor: _values.sidebarWheelScrollFactor ?? 1.2
    readonly property bool workspaceDragReorder: _values.workspaceDragReorder ?? true
    readonly property int workspacePillHeight: _values.workspacePillHeight ?? 22
    readonly property int workspaceActiveWidth: _values.workspaceActiveWidth ?? 48
    readonly property int workspacePillSpacing: _values.workspacePillSpacing ?? 4
    readonly property int workspaceAnimationDuration: _values.workspaceAnimationDuration ?? 200
    readonly property int workspaceQuickAnimationDuration: _values.workspaceQuickAnimationDuration ?? 120
    readonly property int workspaceDragPreviewDuration: _values.workspaceDragPreviewDuration ?? 90
    readonly property int notificationMaxHistoryCount: _values.notificationMaxHistoryCount ?? 500
    readonly property int notificationMaxHistoryPerApp: _values.notificationMaxHistoryPerApp ?? 200
    readonly property int notificationPreviewCount: _values.notificationPreviewCount ?? 2
    readonly property int notificationExpandedPreviewCount: _values.notificationExpandedPreviewCount ?? 8
    readonly property string recordingSaveDir: _values.recordingSaveDir ?? ""
    readonly property string recordingDefaultMode: _values.recordingDefaultMode ?? "output"
    readonly property bool recordingAudioEnabled: _values.recordingAudioEnabled ?? false
    readonly property string screenshotDefaultAction: _values.screenshotDefaultAction ?? "copy"
    readonly property string settingsPath: settingsFile.path
    readonly property bool niriLayoutManaged: _values.niriLayoutManaged ?? false
    readonly property int niriLayoutGaps: _values.niriLayoutGaps ?? 8
    readonly property string niriLayoutPreset: _values.niriLayoutPreset ?? "center-column"
    readonly property bool niriFocusRingEnabled: _values.niriFocusRingEnabled ?? true
    readonly property int niriFocusRingWidth: _values.niriFocusRingWidth ?? 4
    readonly property int niriWindowCornerRadius: _values.niriWindowCornerRadius ?? 0
    readonly property bool niriPreferNoCsd: _values.niriPreferNoCsd ?? true
    readonly property string motionSpeed: _values.motionSpeed ?? "normal"

    property var _values: ({})

    // --- Core API ---

    function set(key, value) {
        if (_loading || _parseError)
            return false;
        var coerced = Spec.coerce(key, value);
        var newValues = Object.assign({}, _values);
        newValues[key] = coerced;
        _values = newValues;
        _saveSettings();
        return true;
    }

    function get(key) {
        return _values[key] ?? Spec.defaults[key];
    }

    function reload() {
        _loadSettings();
    }

    function reset(key) {
        set(key, Spec.defaults[key]);
    }

    function resetAll() {
        _values = Object.assign({}, Spec.defaults);
        _saveSettings();
    }

    // --- File I/O via FileView ---

    function _loadSettings() {
        _loading = true;
        _parseError = false;
        _parseErrorMessage = "";

        var txt = settingsFile.text();
        if (!txt || !txt.trim()) {
            // Empty or missing file — use defaults and write
            _values = Object.assign({}, Spec.defaults);
            _loading = false;
            _hasLoaded = true;
            _saveSettings();
            return;
        }

        var result = Store.parse(txt);
        if (!result.ok) {
            _parseError = true;
            _parseErrorMessage = result.error;
            _values = Object.assign({}, Spec.defaults);
            _loading = false;
            return;
        }

        var merged = Store.mergeDefaults(result.data, Spec.defaults);
        var coerced = {};
        for (var i = 0; i < Spec.keys.length; i++) {
            var key = Spec.keys[i];
            coerced[key] = Spec.coerce(key, merged[key]);
        }
        _values = coerced;
        _loading = false;
        _hasLoaded = true;
    }

    function _saveSettings() {
        if (_loading || !_hasLoaded)
            return;
        _selfWrite = true;
        settingsFile.setText(Store.serialize(_values));
    }

    // Debounce reload on external file change
    Timer {
        id: reloadDebounce
        interval: 300
        onTriggered: root._loadSettings()
    }

    FileView {
        id: settingsFile

        // Build path: $XDG_CONFIG_HOME/quickshell/niri-strata/settings.json
        // Fall back to ~/.config if XDG_CONFIG_HOME is unset
        path: {
            var xdg = Quickshell.env("XDG_CONFIG_HOME");
            var home = Quickshell.env("HOME");
            var configBase = (xdg && xdg.length > 0) ? xdg : (home + "/.config");
            return configBase + "/quickshell/niri-strata/settings.json";
        }
        atomicWrites: true
        watchChanges: true

        onLoaded: root._loadSettings()

        onFileChanged: {
            if (root._selfWrite) {
                root._selfWrite = false;
                return;
            }
            reloadDebounce.restart();
        }

        Component.onCompleted: {
            // Fallback: if onLoaded doesn't fire (e.g. file missing),
            // load after a short delay
            loadTimer.start();
        }
    }

    Timer {
        id: loadTimer
        interval: 100
        onTriggered: {
            if (!root._hasLoaded)
                root._loadSettings();
        }
    }
}
