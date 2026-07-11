import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  mapMatugenToPalette,
  validatePalette,
} from "./lib/matugen-mapper.mjs";

const root = dirname(fileURLToPath(import.meta.url));

function loadFixture(name) {
  return JSON.parse(readFileSync(join(root, "fixtures", name), "utf8"));
}

// ── 1. Structure: real matugen output maps to 32-field palette ──

test("mapMatugenToPalette produces all 32 fields in both dark and light from real matugen JSON", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  const result = validatePalette(palette);
  assert.ok(result.ok, `Missing fields: ${result.missing?.join(", ")}`);
});

// ── 2. Direct mappings produce correct hex values ──

test("primary maps from matugen colors.primary and differs between dark/light", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.ok(palette.dark.primary.startsWith("#"), "dark.primary must be hex");
  assert.ok(palette.light.primary.startsWith("#"), "light.primary must be hex");
  assert.notEqual(palette.dark.primary, palette.light.primary,
    "dark and light primary should differ (matugen generates different shades)");
});

test("text maps from on_surface, mutedText maps from on_surface_variant", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.equal(palette.dark.text, matugen.colors.on_surface.dark.color);
  assert.equal(palette.light.text, matugen.colors.on_surface.light.color);
  assert.equal(palette.dark.mutedText, matugen.colors.on_surface_variant.dark.color);
  assert.equal(palette.light.mutedText, matugen.colors.on_surface_variant.light.color);
});

test("errorColor maps from error, not from error_container", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.equal(palette.dark.errorColor, matugen.colors.error.dark.color);
  assert.equal(palette.dark.errorContainer, matugen.colors.error_container.dark.color);
  assert.notEqual(palette.dark.errorColor, palette.dark.errorContainer,
    "errorColor and errorContainer must be different colors");
});

test("surfaceContainer maps from surface_container, not surface", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.equal(palette.dark.surfaceContainer, matugen.colors.surface_container.dark.color);
  assert.equal(palette.dark.surface, matugen.colors.surface.dark.color);
  assert.notEqual(palette.dark.surface, palette.dark.surfaceContainer,
    "surface and surfaceContainer should be different levels");
});

// ── 3. Derived fields copy from the correct source ──

test("layer0 copies from surfaceContainerLowest, layer1 from surfaceContainerLow", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.equal(palette.dark.layer0, palette.dark.surfaceContainerLowest);
  assert.equal(palette.light.layer0, palette.light.surfaceContainerLowest);
  assert.equal(palette.dark.layer1, palette.dark.surfaceContainerLow);
  assert.equal(palette.light.layer1, palette.light.surfaceContainerLow);
});

test("layer1Hover copies from surfaceContainer, layer1Active from surfaceContainerHigh", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.equal(palette.dark.layer1Hover, palette.dark.surfaceContainer);
  assert.equal(palette.dark.layer1Active, palette.dark.surfaceContainerHigh);
});

test("subtleText copies from mutedText (no direct matugen equivalent)", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.equal(palette.dark.subtleText, palette.dark.mutedText);
  assert.equal(palette.light.subtleText, palette.light.mutedText);
});

// ── 4. Hardcoded fallbacks for success/warning ──

test("successColor and warningColor use hardcoded fallbacks (matugen has no success/warning role)", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  assert.ok(palette.dark.successColor, "dark.successColor must exist");
  assert.ok(palette.dark.warningColor, "dark.warningColor must exist");
  assert.ok(palette.light.successColor, "light.successColor must exist");
  assert.ok(palette.light.warningColor, "light.warningColor must exist");
  assert.ok(palette.dark.successContainer, "dark.successContainer must exist");
  assert.ok(palette.dark.warningContainer, "dark.warningContainer must exist");
});

// ── 5. Different source colors produce different palettes ──

test("blue and red source colors produce different primary values", () => {
  const blueMatugen = loadFixture("matugen-blue.json");
  const redMatugen = loadFixture("matugen-red.json");
  const bluePalette = mapMatugenToPalette(blueMatugen);
  const redPalette = mapMatugenToPalette(redMatugen);

  assert.notEqual(bluePalette.dark.primary, redPalette.dark.primary,
    "different source colors should produce different primary colors");
  assert.notEqual(bluePalette.light.primary, redPalette.light.primary);
});

// ── 6. Error handling ──

test("mapMatugenToPalette throws on missing colors key", () => {
  assert.throws(
    () => mapMatugenToPalette({}),
    /missing 'colors' key/,
  );
});

test("mapMatugenToPalette throws on null input", () => {
  assert.throws(
    () => mapMatugenToPalette(null),
    /missing 'colors' key/,
  );
});

test("validatePalette catches missing fields", () => {
  const incomplete = { dark: { primary: "#fff" }, light: { primary: "#000" } };
  const result = validatePalette(incomplete);
  assert.equal(result.ok, false);
  assert.ok(result.missing.length > 30, "should report many missing fields");
});

// ── 7. All hex values are valid 7-char hex strings ──

test("all palette values are valid #RRGGBB hex strings", () => {
  const matugen = loadFixture("matugen-blue.json");
  const palette = mapMatugenToPalette(matugen);

  const hexRe = /^#[0-9a-fA-F]{6}$/;
  for (const mode of ["dark", "light"]) {
    for (const [key, val] of Object.entries(palette[mode])) {
      assert.match(val, hexRe, `${mode}.${key} = "${val}" is not valid hex`);
    }
  }
});