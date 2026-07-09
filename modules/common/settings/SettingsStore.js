// pragma library

// SettingsStore.js — JSON parse/serialize/merge helpers for SettingsData.qml.
// File I/O (read/write/atomic write) lives in QML (SettingsData.qml); this
// library only handles structural transforms on plain JS objects.

// Recursively return a clone of `value` with object keys sorted
// alphabetically. Primitives and arrays pass through untouched (arrays keep
// order; their elements are still recursed so nested objects sort too).
function _sortKeys(value) {
    if (value === null || typeof value !== "object")
        return value;

    if (Array.isArray(value)) {
        var arr = [];
        for (var i = 0; i < value.length; ++i)
            arr.push(_sortKeys(value[i]));
        return arr;
    }

    var keys = Object.keys(value).sort();
    var sorted = {};
    for (var j = 0; j < keys.length; ++j)
        sorted[keys[j]] = _sortKeys(value[keys[j]]);
    return sorted;
}

// Serialize a settings object to a pretty JSON string: 2-space indentation,
// object keys sorted alphabetically (recursively).
function serialize(settingsObj) {
    return JSON.stringify(_sortKeys(settingsObj), null, 2);
}

// Parse a JSON string. Returns { ok: true, data: {...} } on success or
// { ok: false, error: "message" } when the string is not valid JSON.
function parse(jsonStr) {
    try {
        var data = JSON.parse(jsonStr);
        return { ok: true, data: data };
    } catch (e) {
        return { ok: false, error: String(e && e.message ? e.message : e) };
    }
}

// Merge rawObj over defaultsObj, keeping only keys that exist in defaultsObj.
// Unknown keys in rawObj are dropped. Missing keys fall back to the default.
// Shallow per-key overlay (settings are flat); nested objects are replaced,
// not deep-merged.
function mergeDefaults(rawObj, defaultsObj) {
    var result = {};
    var keys = Object.keys(defaultsObj);
    for (var i = 0; i < keys.length; ++i) {
        var key = keys[i];
        if (rawObj && Object.prototype.hasOwnProperty.call(rawObj, key))
            result[key] = rawObj[key];
        else
            result[key] = defaultsObj[key];
    }
    return result;
}

// atomicWrite(path, content) — NOT implemented in this JS library.
// Atomic file write (write temp + rename) is performed in QML via
// SettingsData.qml using Qt-labs file I/O, since JavaScript here has no
// filesystem access.