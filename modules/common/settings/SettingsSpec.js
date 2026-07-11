// pragma library

// SettingsSpec.js — QML-importable mirror of the settings spec.
// Source of truth for the 34 configuration keys, their defaults, and
// value coercion. Imported by QML components via:
//   import "settings/SettingsSpec.js" as SettingsSpec

var spec = {
    "configVersion": { "type": "int", "default": 1, "min": 1 },
    "themeMode": { "type": "string", "default": "dark", "enum": ["dark", "light", "auto"] },
    "themeId": { "type": "string", "default": "default", "enum": ["default", "blue", "green", "rose", "amber", "neutral", "dynamic"] },
    "accentColor": { "type": "string", "default": "", "regex": "^#[0-9a-fA-F]{6}$" },
    "barPosition": { "type": "string", "default": "top", "enum": ["top", "bottom"] },
    "barStyle": { "type": "string", "default": "flush", "enum": ["flush", "floating"] },
    "barShowBackground": { "type": "bool", "default": true },
    "barHeight": { "type": "int", "default": 34, "min": 28, "max": 60 },
    "barIconButtonSize": { "type": "int", "default": 26, "min": 20, "max": 40 },
    "barSideMargin": { "type": "int", "default": 10, "min": 0, "max": 40 },
    "barGroupSpacing": { "type": "int", "default": 8, "min": 0, "max": 30 },
    "barWingRadius": { "type": "real", "default": 8, "min": 0, "max": 20 },
    "barBottomRadius": { "type": "real", "default": 12, "min": 0, "max": 30 },
    "barFlattenOnMaximized": { "type": "bool", "default": true },
    "sidebarWidth": { "type": "int", "default": 440, "min": 320, "max": 600 },
    "sidebarWheelScrollFactor": { "type": "real", "default": 1.2, "min": 0.1, "max": 5.0 },
    "workspaceDragReorder": { "type": "bool", "default": true },
    "workspacePillHeight": { "type": "int", "default": 22, "min": 16, "max": 40 },
    "workspaceActiveWidth": { "type": "int", "default": 48, "min": 28, "max": 80 },
    "workspacePillSpacing": { "type": "int", "default": 4, "min": 0, "max": 16 },
    "workspaceAnimationDuration": { "type": "int", "default": 200, "min": 0, "max": 800 },
    "workspaceQuickAnimationDuration": { "type": "int", "default": 120, "min": 0, "max": 500 },
    "workspaceDragPreviewDuration": { "type": "int", "default": 90, "min": 0, "max": 300 },
    "notificationMaxHistoryCount": { "type": "int", "default": 500, "min": 0, "max": 5000 },
    "notificationMaxHistoryPerApp": { "type": "int", "default": 200, "min": 0, "max": 2000 },
    "notificationPreviewCount": { "type": "int", "default": 2, "min": 0, "max": 20 },
    "notificationExpandedPreviewCount": { "type": "int", "default": 8, "min": 0, "max": 50 },
    "recordingSaveDir": { "type": "string", "default": "" },
    "recordingDefaultMode": { "type": "string", "default": "output", "enum": ["output", "region"] },
    "recordingAudioEnabled": { "type": "bool", "default": false },
    "screenshotDefaultAction": { "type": "string", "default": "copy", "enum": ["copy", "save"] },
    "niriLayoutManaged": { "type": "bool", "default": false },
    "niriLayoutGaps": { "type": "int", "default": 8, "min": 0, "max": 64 },
    "niriLayoutPreset": { "type": "string", "default": "center-column", "enum": ["center-column", "left-column", "right-column"] },
    "motionSpeed": { "type": "string", "default": "normal", "enum": ["slower", "normal", "faster"] },
    "niriFocusRingEnabled": { "type": "bool", "default": true },
    "niriFocusRingWidth": { "type": "int", "default": 4, "min": 0, "max": 20 },
    "niriWindowCornerRadius": { "type": "int", "default": 0, "min": 0, "max": 30 },
    "niriPreferNoCsd": { "type": "bool", "default": true },
    "autoMode": { "type": "string", "default": "time", "enum": ["time", "sun"] },
    "autoTimeStart": { "type": "string", "default": "18:00" },
    "autoTimeEnd": { "type": "string", "default": "06:00" },
    "autoLat": { "type": "real", "default": 0.0, "min": -90.0, "max": 90.0 },
    "autoLng": { "type": "real", "default": 0.0, "min": -180.0, "max": 180.0 },
    "wallpaperPath": { "type": "string", "default": "" }
};

var keys = Object.keys(spec);

var defaults = (function () {
    var d = {};
    for (var i = 0; i < keys.length; i++) {
        d[keys[i]] = spec[keys[i]].default;
    }
    return d;
})();

// Manual check for the accentColor pattern ^#[0-9a-fA-F]{6}$.
// QML JS has no convenient RegExp literal path, so validate by hand.
function matchesHexColor(s) {
    if (typeof s !== "string" || s.length !== 7) {
        return false;
    }
    if (s.charAt(0) !== "#") {
        return false;
    }
    for (var i = 1; i < 7; i++) {
        var c = s.charAt(i);
        var ok = (c >= "0" && c <= "9") || (c >= "a" && c <= "f") || (c >= "A" && c <= "F");
        if (!ok) {
            return false;
        }
    }
    return true;
}

function clampInt(n, entry) {
    if (entry.hasOwnProperty("min") && n < entry.min) {
        return entry.min;
    }
    if (entry.hasOwnProperty("max") && n > entry.max) {
        return entry.max;
    }
    return n;
}

function clampReal(n, entry) {
    if (entry.hasOwnProperty("min") && n < entry.min) {
        return entry.min;
    }
    if (entry.hasOwnProperty("max") && n > entry.max) {
        return entry.max;
    }
    return n;
}

function inEnum(value, allowed) {
    for (var i = 0; i < allowed.length; i++) {
        if (allowed[i] === value) {
            return true;
        }
    }
    return false;
}

// Returns the coerced/clamped value for `key`, or the default if invalid.
// Unknown keys pass `rawValue` through unchanged.
function coerce(key, rawValue) {
    var entry = spec[key];
    if (!entry) {
        return rawValue;
    }

    var type = entry.type;

    if (type === "int") {
        var n = parseInt(rawValue, 10);
        if (isNaN(n)) {
            return entry.default;
        }
        return clampInt(n, entry);
    }

    if (type === "real") {
        var r = parseFloat(rawValue);
        if (isNaN(r)) {
            return entry.default;
        }
        return clampReal(r, entry);
    }

    if (type === "bool") {
        if (typeof rawValue === "boolean") {
            return rawValue;
        }
        if (typeof rawValue === "number") {
            return rawValue !== 0;
        }
        if (typeof rawValue === "string") {
            if (rawValue === "true" || rawValue === "1") {
                return true;
            }
            if (rawValue === "false" || rawValue === "0") {
                return false;
            }
        }
        return entry.default;
    }

    if (type === "string") {
        var s = (rawValue === null || rawValue === undefined) ? "" : String(rawValue);
        if (entry.hasOwnProperty("enum") && !inEnum(s, entry.enum)) {
            return entry.default;
        }
        if (entry.hasOwnProperty("regex") && !matchesHexColor(s)) {
            return entry.default;
        }
        return s;
    }

    return entry.default;
}