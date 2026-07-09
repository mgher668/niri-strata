import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

const root = dirname(fileURLToPath(import.meta.url));

async function read(rel) {
  return readFile(join(root, "..", rel), "utf8");
}

test("shell.qml instantiates the settings controller", async () => {
  const shell = await read("shell.qml");
  assert.match(shell, /SettingsController\s*\{\s*id:\s*settingsController/s);
});

test("shell.qml exposes the settings IPC target with toggle/open/close/showTab", async () => {
  const shell = await read("shell.qml");
  assert.match(shell, /IpcHandler\s*\{\s*target:\s*"settings"/s);
  assert.match(shell, /function\s+toggle\(\)/);
  assert.match(shell, /function\s+open\(\)/);
  assert.match(shell, /function\s+close\(\)/);
  assert.match(shell, /function\s+showTab\s*\(/);
});

test("shell.qml lazy-loads SettingsWindow bound to the controller and SettingsData", async () => {
  const shell = await read("shell.qml");
  assert.match(shell, /LazyLoader\s*\{\s*active:\s*settingsController\.open/s);
  assert.match(shell, /SettingsWindow\s*\{/);
  assert.match(shell, /controller:\s*settingsController/);
  assert.match(shell, /settingsData:\s*SettingsData/);
});

test("shell.qml does not instantiate a dead NiriConfig", async () => {
  const shell = await read("shell.qml");
  // NiriConfig is owned by NiriTab; a shell-level instance is dead code.
  assert.doesNotMatch(shell, /NiriConfig\s*\{\s*id:/);
});

test("CommandPalette routes the open-settings action to the settings controller", async () => {
  const cp = await read("modules/services/CommandPalette.qml");
  assert.match(cp, /required property var settingsController/);
  assert.match(cp, /command:open-settings/);
  assert.match(cp, /settingsController\.openSettings/);
});

test("SettingsData.qml uses atomicWrites and a self-write guard", async () => {
  const sd = await read("modules/common/SettingsData.qml");
  assert.match(sd, /atomicWrites:\s*true/);
  assert.match(sd, /watchChanges:\s*true/);
  assert.match(sd, /_selfWrite/);
  assert.match(sd, /if\s*\(\s*root\._selfWrite\s*\)/);
});

test("SettingsData.qml does not save while loading or after a parse error", async () => {
  const sd = await read("modules/common/SettingsData.qml");
  assert.match(sd, /if\s*\(\s*_loading\s*\|\|\s*_parseError\s*\)\s*return\s+false/);
  assert.match(sd, /if\s*\(\s*_loading\s*\|\|\s*!_hasLoaded\s*\)\s*return/);
});

test("Config.qml binds bar properties to SettingsData instead of hardcoding", async () => {
  const cfg = await read("modules/common/Config.qml");
  assert.match(cfg, /position:\s*SettingsData\.barPosition/);
  assert.match(cfg, /style:\s*SettingsData\.barStyle/);
  assert.match(cfg, /height:\s*SettingsData\.barHeight/);
  assert.match(cfg, /showBackground:\s*SettingsData\.barShowBackground/);
});

test("Config.qml binds sidebar and notification properties to SettingsData", async () => {
  const cfg = await read("modules/common/Config.qml");
  assert.match(cfg, /width:\s*SettingsData\.sidebarWidth/);
  assert.match(cfg, /wheelScrollFactor:\s*SettingsData\.sidebarWheelScrollFactor/);
  assert.match(cfg, /maxHistoryCount:\s*SettingsData\.notificationMaxHistoryCount/);
});

test("Theme.qml resolves palette from SettingsData themeId/themeMode/accentColor", async () => {
  const theme = await read("modules/common/Theme.qml");
  assert.match(theme, /SettingsData\.themeMode/);
  assert.match(theme, /SettingsData\.themeId/);
  assert.match(theme, /SettingsData\.accentColor/);
  assert.match(theme, /Presets\.getPreset/);
  assert.match(theme, /Presets\.applyAccent/);
  assert.match(theme, /presetPrimary:\s*root\._basePalette\.primary/);
});

test("Bar.qml binds canvas shape and flatten policy to SettingsData", async () => {
  const bar = await read("modules/bar/Bar.qml");
  assert.match(bar, /SettingsData\.barFlattenOnMaximized/);
  assert.match(bar, /wingRadius:\s*SettingsData\.barWingRadius/);
  assert.match(bar, /bottomRadius:\s*SettingsData\.barBottomRadius/);
});

test("Workspaces.qml binds pill sizing and durations to SettingsData", async () => {
  const ws = await read("modules/bar/Workspaces.qml");
  assert.match(ws, /pillHeight:\s*SettingsData\.workspacePillHeight/);
  assert.match(ws, /activeWidth:\s*SettingsData\.workspaceActiveWidth/);
  assert.match(ws, /pillSpacing:\s*SettingsData\.workspacePillSpacing/);
  assert.match(ws, /SettingsData\.workspaceDragReorder/);
  assert.match(ws, /workspaceMotionDuration:\s*SettingsData\.workspaceAnimationDuration/);
});

test("Capture.qml binds idle defaults from SettingsData without mutating active state", async () => {
  const cap = await read("modules/services/Capture.qml");
  assert.match(cap, /recordingMode:\s*SettingsData\.recordingDefaultMode/);
  assert.match(cap, /recordingAudioEnabled:\s*SettingsData\.recordingAudioEnabled/);
  assert.match(cap, /recordingSaveDir:\s*SettingsData\.recordingSaveDir/);
  assert.match(cap, /screenshotDefaultAction:\s*SettingsData\.screenshotDefaultAction/);
  assert.match(cap, /screenshotCommand\(\)/);
  assert.match(cap, /recordingSaveDir/);
});

test("AppearanceTab accent swatches use a non-color model key to avoid QML coercion", async () => {
  const tab = await read("modules/settings/tabs/AppearanceTab.qml");
  assert.match(tab, /hex:/);
  assert.doesNotMatch(tab, /\{\s*color:\s*"#/);
  assert.match(tab, /Theme\.colors\.presetPrimary/);
});

test("NiriConfig.qml backs up config.kdl before inserting the include", async () => {
  const nc = await read("modules/services/NiriConfig.qml");
  assert.match(nc, /backupPath/);
  assert.match(nc, /cp/);
  assert.match(nc, /strata\/layout\.kdl/);
  assert.match(nc, /"niri",\s*"validate"/);
  assert.match(nc, /"niri",\s*"msg",\s*"action",\s*"load-config-file"/);
});

test("SettingsSidebar exposes a two-click reset-all with confirmation timer", async () => {
  const sidebar = await read("modules/settings/SettingsSidebar.qml");
  assert.match(sidebar, /required property var settingsData/);
  assert.match(sidebar, /_resetConfirming/);
  assert.match(sidebar, /resetAll\(\)/);
  assert.match(sidebar, /Click to confirm/);
});

test("SettingsWindow passes settingsData to both sidebar and content", async () => {
  const win = await read("modules/settings/SettingsWindow.qml");
  // sidebar row
  assert.match(win, /SettingsSidebar\s*\{[\s\S]*settingsData:\s*window\.settingsData/);
  // content row
  assert.match(win, /SettingsContent\s*\{[\s\S]*settingsData:\s*window\.settingsData/);
});

test("SettingsSidebar supports arrow key navigation with keyboard index", async () => {
  const sidebar = await read("modules/settings/SettingsSidebar.qml");
  assert.match(sidebar, /_keyboardIndex/);
  assert.match(sidebar, /Keys\.onUpPressed/);
  assert.match(sidebar, /Keys\.onDownPressed/);
  assert.match(sidebar, /Keys\.onReturnPressed/);
  assert.match(sidebar, /index === sidebar\._keyboardIndex/);
  assert.match(sidebar, /sidebar\._keyboardIndex = index/);
});

test("AboutTab is registered in controller and wired in SettingsContent", async () => {
  const ctrl = await read("modules/settings/SettingsController.qml");
  const content = await read("modules/settings/SettingsContent.qml");
  const about = await read("modules/settings/tabs/AboutTab.qml");
  assert.match(ctrl, /id: "about"/);
  assert.match(content, /case "about": return 7/);
  assert.match(content, /AboutTab\s*\{/);
  assert.match(about, /niri-strata/);
  assert.match(about, /xdg-open/);
});