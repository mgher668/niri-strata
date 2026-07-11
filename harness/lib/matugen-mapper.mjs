// Pure Node ESM mapper: matugen JSON output → ThemePresets palette shape.
// No QML deps. Used by harness tests AND mirrored as a QML .js file.
//
// matugen JSON structure:
//   { colors: { primary: { dark: { color: "#9dcbfb" }, light: { color: "#31628d" } } } }
//
// Our palette shape (per preset):
//   { dark: { primary: "#9bd4ff", surfaceContainerLow: "#171c20", ... }, light: { ... } }
//
// The mapping table translates matugen's snake_case names to our camelCase
// palette fields, picking the right semantic color for each slot.

// ── mapping table ───────────────────────────────────────────────
// key = matugen field name (snake_case)
// value = our palette field name (camelCase)
// Only fields we actually use are mapped; matugen outputs 50+ colors,
// we need 32.
const MATUGEN_MAP = {
  background: "background",
  surface: "surface",
  primary: "primary",
  on_primary: "primaryText",
  primary_container: "primaryContainer",
  on_primary_container: "primaryContainerText",
  secondary: "secondary",
  secondary_container: "secondaryContainer",
  on_secondary_container: "secondaryContainerText",
  tertiary: "tertiary",
  tertiary_container: "tertiaryContainer",
  on_tertiary_container: "tertiaryContainerText",
  error: "errorColor",
  error_container: "errorContainer",
  on_surface: "text",
  on_surface_variant: "mutedText",
  outline: "outline",
  outline_variant: "outlineVariant",
  surface_container_lowest: "surfaceContainerLowest",
  surface_container_low: "surfaceContainerLow",
  surface_container: "surfaceContainer",
  surface_container_high: "surfaceContainerHigh",
  surface_container_highest: "surfaceContainerHighest",
  shadow: "scrim",
  scrim: "scrim",
  surface_bright: null,      // no direct equivalent; derived if needed
  surface_dim: null,
  surface_variant: null,
  surface_tint: null,
};

// Fields that have no direct matugen equivalent — we derive them.
// layer0/layer1/layer1Hover/layer1Active are surface level overlays.
// subtleText is a dimmer version of mutedText.
// successColor/warningColor have no matugen match (Material has no success/warning role).
const DERIVED_FIELDS = {
  layer0: "surfaceContainerLowest",
  layer1: "surfaceContainerLow",
  layer1Hover: "surfaceContainer",
  layer1Active: "surfaceContainerHigh",
  subtleText: "mutedText",
  successColor: null,   // fallback to a hardcoded green
  successContainer: null,
  warningColor: null,  // fallback to a hardcoded amber
  warningContainer: null,
};

// Hardcoded fallbacks for colors matugen doesn't generate.
const HARDCODED = {
  successColor: { dark: "#9ed9b3", light: "#1a7a3a" },
  successContainer: { dark: "#1f5234", light: "#c4f0d4" },
  warningColor: { dark: "#f3cf7a", light: "#8a7a1a" },
  warningContainer: { dark: "#5a471b", light: "#fef8d8" },
};

/**
 * Extract a hex color string from a matugen color entry.
 * matugen format: { dark: { color: "#9dcbfb" }, light: { color: "#31628d" } }
 * Returns "#9dcbfb" or null if not found.
 */
function extractColor(entry, mode) {
  if (!entry || !entry[mode] || !entry[mode].color) return null;
  return entry[mode].color;
}

/**
 * Map a matugen JSON output to our palette shape.
 *
 * @param {Object} matugenJson - full matugen --json hex output
 * @returns {{ dark: Object, light: Object }} palette with 32 fields each
 */
export function mapMatugenToPalette(matugenJson) {
  if (!matugenJson || !matugenJson.colors) {
    throw new Error("Invalid matugen JSON: missing 'colors' key");
  }

  const colors = matugenJson.colors;
  const result = { dark: {}, light: {} };

  // 1. Direct mappings
  for (const [matugenName, paletteName] of Object.entries(MATUGEN_MAP)) {
    if (!paletteName) continue;  // skip null mappings
    const entry = colors[matugenName];
    if (!entry) continue;

    const darkVal = extractColor(entry, "dark");
    const lightVal = extractColor(entry, "light");

    if (darkVal) result.dark[paletteName] = darkVal;
    if (lightVal) result.light[paletteName] = lightVal;
  }

  // 2. Derived fields (layer0/layer1/etc copy from other palette fields)
  for (const [derivedName, sourceName] of Object.entries(DERIVED_FIELDS)) {
    if (sourceName && result.dark[sourceName]) {
      result.dark[derivedName] = result.dark[sourceName];
    }
    if (sourceName && result.light[sourceName]) {
      result.light[derivedName] = result.light[sourceName];
    }
  }

  // 3. Hardcoded fallbacks (success/warning colors)
  for (const [name, pair] of Object.entries(HARDCODED)) {
    if (!result.dark[name]) result.dark[name] = pair.dark;
    if (!result.light[name]) result.light[name] = pair.light;
  }

  // 4. Ensure all 32 fields are present; fill gaps from the other mode
  const ALL_FIELDS = [
    "background", "surface", "layer0", "layer1", "layer1Hover", "layer1Active",
    "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
    "surfaceContainerHigh", "surfaceContainerHighest",
    "text", "mutedText", "subtleText",
    "primary", "primaryText", "primaryContainer", "primaryContainerText",
    "secondary", "secondaryContainer", "secondaryContainerText",
    "tertiary", "tertiaryContainer", "tertiaryContainerText",
    "successColor", "successContainer",
    "warningColor", "warningContainer",
    "errorColor", "errorContainer",
    "outline", "outlineVariant",
  ];

  for (const field of ALL_FIELDS) {
    if (!result.dark[field] && result.light[field])
      result.dark[field] = result.light[field];
    if (!result.light[field] && result.dark[field])
      result.light[field] = result.dark[field];
  }

  return result;
}

/**
 * Validate that a palette object has all 32 required fields in both modes.
 * Returns { ok: true } or { ok: false, missing: string[] }.
 */
export function validatePalette(palette) {
  const REQUIRED = [
    "background", "surface", "layer0", "layer1", "layer1Hover", "layer1Active",
    "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
    "surfaceContainerHigh", "surfaceContainerHighest",
    "text", "mutedText", "subtleText",
    "primary", "primaryText", "primaryContainer", "primaryContainerText",
    "secondary", "secondaryContainer", "secondaryContainerText",
    "tertiary", "tertiaryContainer", "tertiaryContainerText",
    "successColor", "successContainer",
    "warningColor", "warningContainer",
    "errorColor", "errorContainer",
    "outline", "outlineVariant",
  ];

  const missing = [];
  for (const mode of ["dark", "light"]) {
    for (const field of REQUIRED) {
      if (!palette[mode] || !palette[mode][field])
        missing.push(`${mode}.${field}`);
    }
  }
  return missing.length === 0 ? { ok: true } : { ok: false, missing };
}