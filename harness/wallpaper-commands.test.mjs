import test from "node:test";
import assert from "node:assert/strict";

import {
  buildSwwwCommand,
  buildSwaybgCommand,
  buildSwwwDaemonStart,
  buildSwaybgKill,
  validFillModesForBackend,
  parseConflictProbe,
} from "./lib/wallpaper-commands.mjs";

import {
  buildScanCommand,
  parseFileList,
} from "./lib/wallpaper-scan.mjs";

// ── 1. swww command construction ──

test("swww command has path, transition-type fade, no -o when output empty", () => {
  const cmd = buildSwwwCommand("/path/to/wall.jpg", "", "");
  assert.deepEqual(cmd, ["swww", "img", "/path/to/wall.jpg", "--transition-type", "fade"]);
});

test("swww command includes -o when output specified", () => {
  const cmd = buildSwwwCommand("/path/to/wall.jpg", "DP-1", "");
  assert.deepEqual(cmd, ["swww", "img", "/path/to/wall.jpg", "--transition-type", "fade", "-o", "DP-1"]);
});

test("swww command includes --fill-color when provided", () => {
  const cmd = buildSwwwCommand("/path/to/wall.jpg", "", "#1a1a2e");
  assert.deepEqual(cmd, ["swww", "img", "/path/to/wall.jpg", "--transition-type", "fade", "--fill-color", "#1a1a2e"]);
});

test("swww command with both output and fill-color", () => {
  const cmd = buildSwwwCommand("/path/w.jpg", "HDMI-1", "#000000");
  assert.deepEqual(cmd, ["swww", "img", "/path/w.jpg", "--transition-type", "fade", "-o", "HDMI-1", "--fill-color", "#000000"]);
});

// ── 2. swaybg command construction ──

test("swaybg command has -i, -m, omits -o and -c when empty", () => {
  const cmd = buildSwaybgCommand("/path/w.jpg", "", "fill", "");
  assert.deepEqual(cmd, ["swaybg", "-i", "/path/w.jpg", "-m", "fill"]);
});

test("swaybg command includes -o when output specified", () => {
  const cmd = buildSwaybgCommand("/path/w.jpg", "DP-1", "fit", "");
  assert.deepEqual(cmd, ["swaybg", "-i", "/path/w.jpg", "-m", "fit", "-o", "DP-1"]);
});

test("swaybg command includes -c when bgColor provided", () => {
  const cmd = buildSwaybgCommand("/path/w.jpg", "", "center", "#2a2a3e");
  assert.deepEqual(cmd, ["swaybg", "-i", "/path/w.jpg", "-m", "center", "-c", "#2a2a3e"]);
});

test("swaybg command with all params", () => {
  const cmd = buildSwaybgCommand("/path/w.jpg", "HDMI-1", "tile", "#112233");
  assert.deepEqual(cmd, ["swaybg", "-i", "/path/w.jpg", "-m", "tile", "-o", "HDMI-1", "-c", "#112233"]);
});

test("swaybg defaults to fill when fillMode is empty", () => {
  const cmd = buildSwaybgCommand("/path/w.jpg", "", "", "");
  assert.deepEqual(cmd, ["swaybg", "-i", "/path/w.jpg", "-m", "fill"]);
});

// ── 3. daemon/kill commands ──

test("buildSwwwDaemonStart returns swww-daemon", () => {
  assert.deepEqual(buildSwwwDaemonStart(), ["swww-daemon"]);
});

test("buildSwaybgKill returns pkill -x swaybg", () => {
  assert.deepEqual(buildSwaybgKill(), ["pkill", "-x", "swaybg"]);
});

// ── 4. fill mode validation ──

test("validFillModesForBackend swww returns only fill", () => {
  assert.deepEqual(validFillModesForBackend("swww"), ["fill"]);
});

test("validFillModesForBackend swaybg returns all 5 modes", () => {
  assert.deepEqual(validFillModesForBackend("swaybg"), ["fill", "fit", "center", "tile", "stretch"]);
});

test("validFillModesForBackend unknown returns empty", () => {
  assert.deepEqual(validFillModesForBackend("feh"), []);
});

// ── 5. conflict parsing ──

test("parseConflictProbe empty returns empty array", () => {
  assert.deepEqual(parseConflictProbe(""), []);
  assert.deepEqual(parseConflictProbe("  \n  "), []);
});

test("parseConflictProbe detects single swww-daemon", () => {
  assert.deepEqual(parseConflictProbe("swww-daemon"), ["swww-daemon"]);
});

test("parseConflictProbe detects multiple processes", () => {
  assert.deepEqual(parseConflictProbe("swww-daemon\nhyprpaper\n"), ["swww-daemon", "hyprpaper"]);
});

// ── 6. scan command construction ──

test("buildScanCommand non-recursive uses ls with glob patterns", () => {
  const cmd = buildScanCommand("/home/user/wallpapers", false, "name");
  assert.equal(cmd[0], "ls");
  assert.equal(cmd[1], "-1");
  assert.ok(cmd.some(arg => arg.includes("*.jpg")));
  assert.ok(cmd.some(arg => arg.includes("/home/user/wallpapers/")));
});

test("buildScanCommand recursive uses find with -type f", () => {
  const cmd = buildScanCommand("/home/user/wallpapers", true, "name");
  assert.equal(cmd[0], "find");
  assert.ok(cmd.includes("-type"));
  assert.ok(cmd.includes("f"));
  assert.ok(cmd.includes("("));
  assert.ok(cmd.includes(")"));
});

test("buildScanCommand date sort uses -printf", () => {
  const cmd = buildScanCommand("/home/user/wallpapers", true, "date");
  assert.ok(cmd.includes("-printf"));
  assert.ok(cmd.some(arg => arg.includes("%T@")));
});

// ── 7. file list parsing ──

test("parseFileList name ascending sorts alphabetically", () => {
  const input = "/wallpapers/zebra.jpg\n/wallpapers/apple.png\n/wallpapers/mango.webp";
  const result = parseFileList(input, "name", "ascending");
  assert.equal(result[0], "/wallpapers/apple.png");
  assert.equal(result[1], "/wallpapers/mango.webp");
  assert.equal(result[2], "/wallpapers/zebra.jpg");
});

test("parseFileList name descending sorts reverse alphabetically", () => {
  const input = "/wallpapers/apple.png\n/wallpapers/zebra.jpg\n/wallpapers/mango.webp";
  const result = parseFileList(input, "name", "descending");
  assert.equal(result[0], "/wallpapers/zebra.jpg");
  assert.equal(result[2], "/wallpapers/apple.png");
});

test("parseFileList date ascending sorts oldest first", () => {
  const input = "1700000000.0 /w/new.jpg\n1600000000.0 /w/old.jpg\n1650000000.0 /w/mid.jpg";
  const result = parseFileList(input, "date", "ascending");
  assert.equal(result[0], "/w/old.jpg");
  assert.equal(result[1], "/w/mid.jpg");
  assert.equal(result[2], "/w/new.jpg");
});

test("parseFileList date descending sorts newest first", () => {
  const input = "1600000000.0 /w/old.jpg\n1700000000.0 /w/new.jpg\n1650000000.0 /w/mid.jpg";
  const result = parseFileList(input, "date", "descending");
  assert.equal(result[0], "/w/new.jpg");
  assert.equal(result[1], "/w/mid.jpg");
  assert.equal(result[2], "/w/old.jpg");
});

test("parseFileList empty input returns empty array", () => {
  assert.deepEqual(parseFileList("", "name", "ascending"), []);
  assert.deepEqual(parseFileList(null, "date", "descending"), []);
});