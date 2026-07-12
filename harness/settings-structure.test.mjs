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

test("auto theme bridge is mounted and writes daemon state into Theme", async () => {
  const shell = await read("shell.qml");
  const bridge = await read("modules/services/AutoThemeBridge.qml");
  assert.match(shell, /AutoThemeBridge\s*\{\s*id:\s*autoThemeBridge/s);
  assert.match(bridge, /import\s+"\.\.\/common\/"/);
  assert.match(bridge, /blockLoading:\s*true/);
  assert.match(bridge, /watchChanges:\s*true/);
  assert.match(bridge, /stateFile\.reload\(\)/);
  assert.match(bridge, /auto-theme-state\.json/);
  assert.match(bridge, /Theme\._autoLight\s*=/);
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

test("ThemeEngine.qml has matugen process and palette mapping", async () => {
  const te = await read("modules/services/ThemeEngine.qml");
  assert.match(te, /property bool matugenAvailable/);
  assert.match(te, /function generate\(/);
  assert.match(te, /function generateFromHex\(/);
  assert.match(te, /signal paletteReady/);
  assert.match(te, /function _mapToPalette/);
  assert.match(te, /surface_container_low.*surfaceContainerLow/);
  assert.match(te, /matugen.*--json.*hex/);
});

test("Theme.qml supports dynamic palette via _dynamicPalette", async () => {
  const theme = await read("modules/common/Theme.qml");
  assert.match(theme, /property var _dynamicPalette/);
  assert.match(theme, /themeId === "dynamic" \&\& _dynamicPalette/);
});

test("shell.qml instantiates ThemeEngine and wires paletteReady to Theme._dynamicPalette", async () => {
  const shell = await read("shell.qml");
  assert.match(shell, /ThemeEngine\s*\{[\s\S]*onPaletteReady/);
  assert.match(shell, /Theme\._dynamicPalette = palette/);
});

test("AppearanceTab includes Dynamic preset option and wallpaper field", async () => {
  const tab = await read("modules/settings/tabs/AppearanceTab.qml");
  assert.match(tab, /\{ label: "Dynamic", value: "dynamic" \}/);
  assert.match(tab, /wallpaperPath/);
  assert.match(tab, /themeEngine\.generate/);
});

test("SettingsSpec includes wallpaperPath key and dynamic in themeId enum", async () => {
  const spec = await read("modules/common/settings/SettingsSpec.js");
  assert.match(spec, /"wallpaperPath"/);
  assert.match(spec, /"dynamic"/);
});

test("ThemeExport.qml has GTK and Qt export functions", async () => {
  const te = await read("modules/services/ThemeExport.qml");
  assert.match(te, /function exportAll\(/);
  assert.match(te, /function exportGtk\(/);
  assert.match(te, /function exportQt\(/);
  assert.match(te, /function _renderGtkCss/);
  assert.match(te, /function _renderQtScheme/);
  assert.match(te, /NiriStrata/);
  assert.match(te, /niri-strata-colors\.css/);
  assert.match(te, /niri-strata-import-start/);
});

test("shell.qml instantiates ThemeExport", async () => {
  const shell = await read("shell.qml");
  assert.match(shell, /ThemeExport\s*\{/);
});

test("AppearanceTab has system theme section with master toggle and GTK/Qt sub-toggles", async () => {
  const tab = await read("modules/settings/tabs/AppearanceTab.qml");
  assert.match(tab, /systemThemeEnabled/);
  assert.match(tab, /systemThemeGtkEnabled/);
  assert.match(tab, /systemThemeQtEnabled/);
  assert.match(tab, /themeExport\.exportAll/);
  assert.match(tab, /System Theme/);
});

test("SettingsSpec includes systemTheme keys", async () => {
  const spec = await read("modules/common/settings/SettingsSpec.js");
  assert.match(spec, /systemThemeEnabled/);
  assert.match(spec, /systemThemeGtkEnabled/);
  assert.match(spec, /systemThemeQtEnabled/);
  assert.match(spec, /systemThemeApplyOnModeChange/);
});

test("theme-render.mjs renders GTK CSS and Qt color scheme", async () => {
  const render = await read("scripts/theme-render.mjs");
  assert.match(render, /export function renderGtk/);
  assert.match(render, /export function renderQt/);
  assert.match(render, /export function insertGtk4Import/);
  assert.match(render, /NiriStrata/);
  assert.match(render, /niri-strata-colors/);
});

test("ThemeExport has portal and niri export functions", async () => {
  const te = await read("modules/services/ThemeExport.qml");
  assert.match(te, /function exportPortal/);
  assert.match(te, /gsettings.*color-scheme/);
  assert.match(te, /function exportNiri/);
  assert.match(te, /function _renderNiriKdl/);
  assert.match(te, /colors\.kdl/);
});

test("theme-render.mjs has portal command and niri renderer", async () => {
  const render = await read("scripts/theme-render.mjs");
  assert.match(render, /export function portalCommand/);
  assert.match(render, /export function portalDconfCommand/);
  assert.match(render, /export function renderNiri/);
});

test("WallpaperService.qml has backend probe, scan, and apply functions", async () => {
  const ws = await read("modules/services/WallpaperService.qml");
  assert.match(ws, /property bool swwwAvailable/);
  assert.match(ws, /property bool swaybgAvailable/);
  assert.match(ws, /function probeBackends/);
  assert.match(ws, /function probeConflicts/);
  assert.match(ws, /function scanFolders/);
  assert.match(ws, /function applyWallpaper/);
  assert.match(ws, /swww.*img/);
  assert.match(ws, /swaybg.*-i/);
});

test("WallpaperGrid.qml has GridView with async Image delegates", async () => {
  const wg = await read("modules/settings/widgets/WallpaperGrid.qml");
  assert.match(wg, /GridView/);
  assert.match(wg, /Image\.PreserveAspectCrop/);
  assert.match(wg, /asynchronous: true/);
  assert.match(wg, /cache: true/);
  assert.match(wg, /sourceSize/);
  assert.match(wg, /cacheBuffer/);
  assert.match(wg, /imageClicked/);
});

test("AppearanceTab has wallpaper backend, fill mode, and folders UI", async () => {
  const tab = await read("modules/settings/tabs/AppearanceTab.qml");
  assert.match(tab, /wallpaperBackend/);
  assert.match(tab, /wallpaperFillMode/);
  assert.match(tab, /wallpaperBgColor/);
  assert.match(tab, /wallpaperPerMonitor/);
  assert.match(tab, /wallpaperDirs/);
  assert.match(tab, /WallpaperGrid/);
  assert.match(tab, /folderPicker/);
});

test("shell.qml instantiates WallpaperService", async () => {
  const shell = await read("shell.qml");
  assert.match(shell, /WallpaperService\s*\{/);
});

test("SettingsSpec has all 9 new wallpaper keys", async () => {
  const spec = await read("modules/common/settings/SettingsSpec.js");
  assert.match(spec, /wallpaperDirs/);
  assert.match(spec, /wallpaperBackend/);
  assert.match(spec, /wallpaperFillMode/);
  assert.match(spec, /wallpaperBgColor/);
  assert.match(spec, /wallpaperPerMonitor/);
  assert.match(spec, /wallpaperMonitorPaths/);
  assert.match(spec, /wallpaperSortBy/);
  assert.match(spec, /wallpaperSortOrder/);
  assert.match(spec, /wallpaperRecursive/);
});
