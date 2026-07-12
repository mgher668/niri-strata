// Pure Node ESM core for niri-strata settings.
// Owns the 34-key spec, defaults, coercion, merging, migration,
// and generation of the niri layout.kdl fragment. No QML deps.

export const SETTINGS_SPEC = {
  configVersion: { type: "int", default: 1, min: 1 },
  themeMode: { type: "string", default: "dark", enum: ["dark", "light", "auto"] },
  themeId: { type: "string", default: "default", enum: ["default", "blue", "green", "rose", "amber", "neutral", "dynamic"] },
  accentColor: { type: "string", default: "", regex: /^#[0-9a-fA-F]{6}$/ },
  barPosition: { type: "string", default: "top", enum: ["top", "bottom"] },
  barStyle: { type: "string", default: "flush", enum: ["flush", "floating"] },
  barShowBackground: { type: "bool", default: true },
  barHeight: { type: "int", default: 34, min: 28, max: 60 },
  barIconButtonSize: { type: "int", default: 26, min: 20, max: 40 },
  barSideMargin: { type: "int", default: 10, min: 0, max: 40 },
  barGroupSpacing: { type: "int", default: 8, min: 0, max: 30 },
  barWingRadius: { type: "real", default: 8, min: 0, max: 20 },
  barBottomRadius: { type: "real", default: 12, min: 0, max: 30 },
  barFlattenOnMaximized: { type: "bool", default: true },
  sidebarWidth: { type: "int", default: 440, min: 320, max: 600 },
  sidebarWheelScrollFactor: { type: "real", default: 1.2, min: 0.1, max: 5.0 },
  workspaceDragReorder: { type: "bool", default: true },
  workspacePillHeight: { type: "int", default: 22, min: 16, max: 40 },
  workspaceActiveWidth: { type: "int", default: 48, min: 28, max: 80 },
  workspacePillSpacing: { type: "int", default: 4, min: 0, max: 16 },
  workspaceAnimationDuration: { type: "int", default: 200, min: 0, max: 800 },
  workspaceQuickAnimationDuration: { type: "int", default: 120, min: 0, max: 500 },
  workspaceDragPreviewDuration: { type: "int", default: 90, min: 0, max: 300 },
  notificationMaxHistoryCount: { type: "int", default: 500, min: 0, max: 5000 },
  notificationMaxHistoryPerApp: { type: "int", default: 200, min: 0, max: 2000 },
  notificationPreviewCount: { type: "int", default: 2, min: 0, max: 20 },
  notificationExpandedPreviewCount: { type: "int", default: 8, min: 0, max: 50 },
  recordingSaveDir: { type: "string", default: "" },
  recordingDefaultMode: { type: "string", default: "output", enum: ["output", "region"] },
  recordingAudioEnabled: { type: "bool", default: false },
  screenshotDefaultAction: { type: "string", default: "copy", enum: ["copy", "save"] },
  niriLayoutManaged: { type: "bool", default: false },
  niriLayoutGaps: { type: "int", default: 8, min: 0, max: 64 },
  niriLayoutPreset: { type: "string", default: "center-column", enum: ["center-column", "left-column", "right-column"] },
  motionSpeed: { type: "string", default: "normal", enum: ["slower", "normal", "faster"] },
  niriFocusRingEnabled: { type: "bool", default: true },
  niriFocusRingWidth: { type: "int", default: 4, min: 0, max: 20 },
  niriWindowCornerRadius: { type: "int", default: 0, min: 0, max: 30 },
  niriPreferNoCsd: { type: "bool", default: true },
  autoMode: { type: "string", default: "time", enum: ["time", "sun"] },
  autoTimeStart: { type: "string", default: "18:00" },
  autoTimeEnd: { type: "string", default: "06:00" },
  autoLat: { type: "real", default: 0.0, min: -90.0, max: 90.0 },
  autoLng: { type: "real", default: 0.0, min: -180.0, max: 180.0 },
  wallpaperPath: { type: "string", default: "" },
  systemThemeEnabled: { type: "bool", default: false },
  systemThemeGtkEnabled: { type: "bool", default: true },
  systemThemeQtEnabled: { type: "bool", default: true },
  systemThemeApplyOnModeChange: { type: "bool", default: true },
  wallpaperDirs: { type: "string", default: "[]" },
  wallpaperBackend: { type: "string", default: "swww", enum: ["swww", "swaybg"] },
  wallpaperFillMode: { type: "string", default: "fill", enum: ["fill", "fit", "center", "tile", "stretch"] },
  wallpaperBgColor: { type: "string", default: "#000000" },
  wallpaperPerMonitor: { type: "bool", default: false },
  wallpaperMonitorPaths: { type: "string", default: "{}" },
  wallpaperSortBy: { type: "string", default: "name", enum: ["name", "date"] },
  wallpaperSortOrder: { type: "string", default: "ascending", enum: ["ascending", "descending"] },
  wallpaperRecursive: { type: "bool", default: false },
};

const SPEC_KEYS = Object.keys(SETTINGS_SPEC);

export function defaultSettings() {
  const out = {};
  for (const key of SPEC_KEYS) {
    out[key] = SETTINGS_SPEC[key].default;
  }
  return out;
}

function clampNumber(num, spec) {
  let value = num;
  if (typeof spec.min === "number" && value < spec.min) {
    value = spec.min;
  }
  if (typeof spec.max === "number" && value > spec.max) {
    value = spec.max;
  }
  return value;
}

export function coerceValue(key, rawValue) {
  const spec = SETTINGS_SPEC[key];
  if (!spec) {
    return { value: undefined, ok: false };
  }

  switch (spec.type) {
    case "int": {
      if (typeof rawValue === "number" && Number.isFinite(rawValue) && Number.isInteger(rawValue)) {
        return { value: clampNumber(rawValue, spec), ok: true };
      }
      if (typeof rawValue === "string") {
        const parsed = Number.parseInt(rawValue, 10);
        if (Number.isFinite(parsed)) {
          return { value: clampNumber(parsed, spec), ok: true };
        }
      }
      return { value: spec.default, ok: false };
    }
    case "real": {
      if (typeof rawValue === "number" && Number.isFinite(rawValue)) {
        return { value: clampNumber(rawValue, spec), ok: true };
      }
      if (typeof rawValue === "string") {
        const parsed = Number.parseFloat(rawValue);
        if (Number.isFinite(parsed)) {
          return { value: clampNumber(parsed, spec), ok: true };
        }
      }
      return { value: spec.default, ok: false };
    }
    case "bool": {
      if (typeof rawValue === "boolean") {
        return { value: rawValue, ok: true };
      }
      if (typeof rawValue === "string") {
        const lower = rawValue.trim().toLowerCase();
        if (lower === "true") return { value: true, ok: true };
        if (lower === "false") return { value: false, ok: true };
      }
      return { value: spec.default, ok: false };
    }
    case "string": {
      if (typeof rawValue === "string") {
        if (spec.enum && !spec.enum.includes(rawValue)) {
          return { value: spec.default, ok: false };
        }
        if (spec.regex && rawValue !== spec.default && !spec.regex.test(rawValue)) {
          return { value: spec.default, ok: false };
        }
        return { value: rawValue, ok: true };
      }
      return { value: spec.default, ok: false };
    }
    default:
      return { value: spec.default, ok: false };
  }
}

export function mergeSettings(rawObj) {
  const out = defaultSettings();
  if (!rawObj || typeof rawObj !== "object") {
    return out;
  }
  for (const key of SPEC_KEYS) {
    if (Object.hasOwn(rawObj, key)) {
      const { value } = coerceValue(key, rawObj[key]);
      out[key] = value;
    }
  }
  return out;
}

export function migrateSettings(oldSettings, oldVersion) {
  // Version 1 is the current schema; no transformation needed beyond
  // ensuring every known key is present and valid.
  const base = defaultSettings();
  if (!oldSettings || typeof oldSettings !== "object") {
    base.configVersion = oldVersion ?? 1;
    return base;
  }
  for (const key of SPEC_KEYS) {
    if (Object.hasOwn(oldSettings, key)) {
      const { value } = coerceValue(key, oldSettings[key]);
      base[key] = value;
    }
  }
  base.configVersion = oldVersion ?? oldSettings.configVersion ?? 1;
  return base;
}

export function buildIncludeLine() {
  return 'include "strata/layout.kdl"';
}

export function detectInclude(configContent) {
  const text = String(configContent ?? "");
  if (text.length === 0) {
    return false;
  }
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (trimmed.length === 0 || trimmed.startsWith("//")) {
      continue;
    }
    const match = trimmed.match(/^include\s+"([^"]+)"/);
    if (match && match[1] === "strata/layout.kdl") {
      return true;
    }
  }
  return false;
}

const PRESET_FRAGMENTS = {
  "center-column": `    center-focused-column "always"`,
  "left-column": `    center-focused-column "never"`,
  "right-column": `    center-focused-column "on-overflow"`,
};

export function generateNiriFragment(opts) {
  const gaps = Math.max(0, Math.min(64, Number(opts.gaps) || 0));
  const presetKey = PRESET_FRAGMENTS[opts.preset] ? opts.preset : "center-column";
  const presetBlock = PRESET_FRAGMENTS[presetKey];
  const ringEnabled = opts.focusRingEnabled !== false;
  const ringWidth = Math.max(0, Math.min(20, Number(opts.focusRingWidth) || 0));
  const cornerRadius = Math.max(0, Math.min(30, Number(opts.windowCornerRadius) || 0));
  const preferNoCsd = opts.preferNoCsd !== false;

  let layout = `layout {\n    gaps ${gaps}\n${presetBlock}\n`;
  if (ringEnabled) {
    layout += `    focus-ring {\n        width ${ringWidth}\n    }\n`;
  } else {
    layout += `    focus-ring {\n        off\n    }\n`;
  }
  layout += `}\n`;

  let extra = "";
  if (cornerRadius > 0) {
    extra += `window-rule {\n    geometry-corner-radius ${cornerRadius}\n    clip-to-geometry true\n}\n`;
  }
  if (preferNoCsd) {
    extra += `prefer-no-csd\n`;
  }

  return `// Generated by niri-strata Settings.\n// Edit Settings, not this file. Manual changes may be overwritten.\n${layout}${extra}`;
}

// Insert the include line into config.kdl content if not already present.
// Returns { content, inserted } where inserted is true if the line was added.
export function insertInclude(configContent) {
  const text = String(configContent ?? "");
  if (detectInclude(text))
    return { content: text, inserted: false };
  const includeLine = buildIncludeLine();
  const newContent = text.trimEnd() + "\n\n" + includeLine + "\n";
  return { content: newContent, inserted: true };
}