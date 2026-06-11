import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

import {
  commandPaletteActions,
  desktopEntryFields,
  normalizeDesktopEntries,
  normalizeDesktopEntry,
  parseDesktopEntry,
  searchPalette,
} from "./lib/launcher-core.mjs";

const root = dirname(fileURLToPath(import.meta.url));

test("documents and normalizes Quickshell desktop entry fields", () => {
  assert.deepEqual(desktopEntryFields, [
    "id",
    "name",
    "genericName",
    "comment",
    "icon",
    "command",
    "workingDirectory",
    "runInTerminal",
    "categories",
    "keywords",
    "actions",
    "noDisplay",
  ]);

  const entry = normalizeDesktopEntry({
    id: "org.example.Terminal.desktop",
    name: "Example Terminal",
    genericName: "Terminal Emulator",
    comment: "Run a shell",
    icon: "utilities-terminal",
    command: "example-terminal",
    workingDirectory: "/tmp",
    runInTerminal: false,
    categories: ["System", "TerminalEmulator"],
    keywords: ["shell", "console"],
    noDisplay: false,
  });

  assert.deepEqual(entry, {
    id: "app:org.example.Terminal.desktop",
    appId: "org.example.Terminal.desktop",
    type: "app",
    title: "Example Terminal",
    subtitle: "Terminal Emulator",
    icon: "utilities-terminal",
    keywords: ["shell", "console", "System", "TerminalEmulator"],
    command: "example-terminal",
    workingDirectory: "/tmp",
    runInTerminal: false,
    defaultScore: 38,
  });
});

test("parses fallback desktop files and filters hidden entries", () => {
  const parsed = parseDesktopEntry(`
[Desktop Entry]
Type=Application
Name=Hidden Tool
GenericName=Utility
Comment=Should not show
Icon=tool
Exec=hidden-tool --flag
Path=/opt/hidden
Terminal=true
Categories=Utility;System;
Keywords=diagnostics;tools;
NoDisplay=true
`);

  assert.equal(normalizeDesktopEntry(parsed), null);
  assert.equal(normalizeDesktopEntry({ ...parsed, noDisplay: false })?.title, "Hidden Tool");
  assert.equal(normalizeDesktopEntry({ type: "Link", name: "Website" }), null);
});

test("deduplicates app IDs while preserving first visible entry", () => {
  const apps = normalizeDesktopEntries([
    { id: "a.desktop", name: "Alpha", command: "alpha" },
    { id: "a.desktop", name: "Alpha Duplicate", command: "alpha2" },
    { id: "b.desktop", name: "Beta", noDisplay: true },
    { id: "c.desktop", name: "Gamma", command: "gamma" },
  ]);

  assert.deepEqual(apps.map(app => app.title), ["Alpha", "Gamma"]);
});

test("defines stable command palette actions with confirmation metadata", () => {
  const actions = commandPaletteActions();
  assert.deepEqual(actions.slice(0, 4).map(action => action.actionId), [
    "controlCenter.open",
    "capture.screenshot",
    "capture.record",
    "session.lock",
  ]);

  for (const actionId of ["session.logout", "session.suspend", "session.reboot", "session.shutdown"]) {
    const action = actions.find(item => item.actionId === actionId);
    assert.equal(action?.confirmation?.required, true);
  }
});

test("search ranks exact app matches above command and keyword matches", () => {
  const apps = normalizeDesktopEntries([
    {
      id: "org.example.Settings.desktop",
      name: "System Settings",
      comment: "Terminal preferences",
      keywords: ["preferences"],
    },
    {
      id: "org.example.Terminal.desktop",
      name: "Terminal",
      genericName: "Shell",
      keywords: ["console"],
    },
  ]);

  const results = searchPalette("terminal", apps, commandPaletteActions(), { limit: 5 });

  assert.equal(results[0].id, "app:org.example.Terminal.desktop");
  assert.ok(results.some(result => result.actionId === "capture.record") === false);
});

test("empty query returns useful default actions deterministically", () => {
  const apps = normalizeDesktopEntries([
    { id: "browser.desktop", name: "Browser", command: "browser" },
  ]);
  const results = searchPalette("", apps, commandPaletteActions());

  assert.deepEqual(results.slice(0, 5).map(result => result.id), [
    "command:open-control-center",
    "command:screenshot",
    "command:record",
    "command:lock",
    "app:browser.desktop",
  ]);
});

test("fuzzy search matches initials and subsequences", () => {
  const apps = normalizeDesktopEntries([
    { id: "firefox.desktop", name: "Firefox", command: "firefox" },
    { id: "chrome.desktop", name: "Google Chrome", command: "google-chrome" },
    { id: "files.desktop", name: "Files", command: "nautilus" },
  ]);

  assert.equal(searchPalette("ff", apps, [], { limit: 3 })[0].id, "app:firefox.desktop");
  assert.equal(searchPalette("gc", apps, [], { limit: 3 })[0].id, "app:chrome.desktop");
});

test("unlimited search returns every sorted match by default", () => {
  const apps = normalizeDesktopEntries([
    { id: "libreoffice.desktop", name: "LibreOffice", command: "libreoffice" },
    { id: "libreoffice-writer.desktop", name: "LibreOffice Writer", command: "libreoffice --writer" },
    { id: "sniffnet.desktop", name: "Sniffnet", command: "sniffnet" },
    { id: "freshrss.desktop", name: "FreshRSS feed aggregator", command: "brave --app-id=ffdgod" },
    { id: "firefox.desktop", name: "Firefox", command: "firefox" },
    { id: "freeoffice.desktop", name: "FreeOffice", command: "freeoffice" },
    { id: "fontforge.desktop", name: "FontForge", command: "fontforge" },
    { id: "foo-fighters.desktop", name: "Foo Fighters", command: "foo-fighters" },
    { id: "fast-file.desktop", name: "Fast File", command: "fast-file" },
    { id: "file-finder.desktop", name: "File Finder", command: "file-finder" },
  ]);

  const results = searchPalette("ff", apps, []);

  assert.ok(results.length > 8);
  assert.ok(results.find(result => result.id === "app:firefox.desktop"));
  assert.deepEqual(
    results.map(result => result.score),
    [...results].map(result => result.score).sort((a, b) => b - a),
  );
});

test("pinned and recent items shape empty-query defaults and boost searches", () => {
  const apps = normalizeDesktopEntries([
    { id: "browser.desktop", name: "Browser", command: "browser" },
    { id: "terminal.desktop", name: "Terminal", command: "terminal" },
  ]);

  const emptyResults = searchPalette("", apps, commandPaletteActions(), {
    limit: 5,
    pinnedIds: ["app:terminal.desktop"],
    recentIds: ["app:browser.desktop"],
  });

  assert.deepEqual(emptyResults.slice(0, 2).map(result => ({
    id: result.id,
    pinned: result.pinned,
    recent: result.recent,
  })), [
    { id: "app:terminal.desktop", pinned: true, recent: false },
    { id: "app:browser.desktop", pinned: false, recent: true },
  ]);

  const boostedResults = searchPalette("screen", apps, commandPaletteActions(), {
    limit: 3,
    pinnedIds: ["command:record"],
  });

  assert.equal(boostedResults[0].id, "command:record");
  assert.equal(boostedResults[0].pinned, true);
});

test("wires launcher services and overlay through shell", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const appSearch = await readFile(join(root, "../modules/services/AppSearch.qml"), "utf8");
  const commandPalette = await readFile(join(root, "../modules/services/CommandPalette.qml"), "utf8");
  const launcher = await readFile(join(root, "../modules/launcher/Launcher.qml"), "utf8");
  const row = await readFile(join(root, "../modules/launcher/SearchResultRow.qml"), "utf8");
  const actions = await readFile(join(root, "../modules/services/SystemActions.qml"), "utf8");

  assert.match(shell, /import "\.\/modules\/launcher\/"/);
  assert.match(shell, /AppSearch\s*\{\s*id:\s*appSearch/s);
  assert.match(shell, /CommandPalette\s*\{[\s\S]*appSearch:\s*appSearch[\s\S]*systemActions:\s*systemActions[\s\S]*sidebarController:\s*sidebarState/);
  assert.match(shell, /Launcher\s*\{[\s\S]*palette:\s*commandPalette[\s\S]*niriState:\s*niriState/);
  assert.match(shell, /IpcHandler\s*\{[\s\S]*target:\s*"launcher"[\s\S]*function toggle\(\): void \{ commandPalette\.toggle\(\); \}/);

  assert.match(appSearch, /import Quickshell/);
  assert.match(appSearch, /DesktopEntries\.applications\.values/);
  assert.match(appSearch, /property var appCache:\s*\[\]/);
  assert.match(appSearch, /property int revision:\s*0/);
  assert.match(appSearch, /Component\.onCompleted:\s*refreshCache\(\)/);
  assert.match(appSearch, /onApplicationsChanged:\s*refreshCache\(\)/);
  assert.match(appSearch, /function refreshCache\(\)/);
  assert.match(appSearch, /appCache = apps/);
  assert.match(appSearch, /revision \+= 1/);
  assert.match(appSearch, /function search\(query, limit\)/);
  assert.match(appSearch, /noDisplay/);

  assert.match(commandPalette, /required property var appSearch/);
  assert.match(commandPalette, /property string inputQuery:\s*""/);
  assert.match(commandPalette, /property string query:\s*""/);
  assert.match(commandPalette, /property int searchDebounceMs:\s*45/);
  assert.match(commandPalette, /readonly property var results:/);
  assert.match(commandPalette, /property var pinnedIds:/);
  assert.match(commandPalette, /property var recentIds:/);
  assert.match(commandPalette, /property bool keyboardNavigationActive:\s*false/);
  assert.match(commandPalette, /readonly property int appSearchRevision:\s*appSearch\.revision/);
  assert.match(commandPalette, /readonly property var results:\s*searchResults\(query,\s*appSearchRevision,\s*usageRevision\)/);
  assert.match(commandPalette, /const appResults = appSearch\.search\(value\)/);
  assert.match(commandPalette, /return Number\.isFinite\(limit\) \? results\.slice\(0, limit\) : results/);
  assert.match(commandPalette, /property string confirmingActionId:\s*""/);
  assert.match(commandPalette, /function setInputQuery\(value\)/);
  assert.match(commandPalette, /function commitInputQuery\(\)/);
  assert.match(commandPalette, /function resetSearch\(\)/);
  assert.match(commandPalette, /id:\s*searchDebounceTimer[\s\S]*interval:\s*root\.searchDebounceMs[\s\S]*root\.commitInputQuery\(\)/);
  assert.match(commandPalette, /function moveSelection\(delta\)\s*\{[\s\S]*commitInputQuery\(\);[\s\S]*if \(results\.length === 0\)/);
  assert.match(commandPalette, /function executeSelected\(\)\s*\{[\s\S]*commitInputQuery\(\);[\s\S]*if \(results\.length === 0\)/);
  assert.match(commandPalette, /function togglePinned\(id\)/);
  assert.match(commandPalette, /function recordUsage\(id\)/);
  assert.match(commandPalette, /keyboardNavigationActive = true/);
  assert.match(commandPalette, /id:\s*keyboardNavigationResetTimer[\s\S]*interval:\s*90[\s\S]*keyboardNavigationActive = false/);
  assert.match(commandPalette, /function executeSelected\(\)/);
  assert.match(commandPalette, /systemActions\.takeScreenshot\(\)/);
  assert.match(commandPalette, /systemActions\.toggleRecording\(\)/);
  assert.match(commandPalette, /systemActions\.runConfirmedSessionAction\(sessionAction\)/);
  assert.match(commandPalette, /confirmingActionId = result\.actionId/);
  assert.doesNotMatch(commandPalette, /\["systemctl"|\["niri", "msg"|\["swaylock"|Quickshell\.execDetached/);

  assert.match(actions, /function runConfirmedSessionAction\(action\)/);
  assert.match(actions, /Quickshell\.execDetached\(command\)/);

  assert.match(launcher, /PanelWindow\s*\{/);
  assert.match(launcher, /WlrLayershell\.namespace:\s*"quickshell:launcher"/);
  assert.match(launcher, /WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.OnDemand/);
  assert.match(launcher, /TextInput\s*\{/);
  assert.match(launcher, /text:\s*root\.palette\.inputQuery/);
  assert.match(launcher, /onTextEdited:\s*root\.palette\.setInputQuery\(text\)/);
  assert.match(launcher, /searchField\.forceActiveFocus\(\)/);
  assert.match(launcher, /Keys\.onPressed:\s*function\(event\)/);
  assert.match(launcher, /Qt\.Key_Escape/);
  assert.match(launcher, /Qt\.Key_Return|Qt\.Key_Enter/);
  assert.match(launcher, /Qt\.Key_Down/);
  assert.match(launcher, /Qt\.Key_Up/);
  assert.match(launcher, /model:\s*root\.palette\.results/);
  assert.match(launcher, /onCurrentIndexChanged:[\s\S]*positionViewAtIndex\(currentIndex,\s*ListView\.Contain\)/);
  assert.match(launcher, /function scrollBy\(delta\)/);
  assert.match(launcher, /WheelHandler\s*\{[\s\S]*Config\.sidebar\.wheelScrollFactor/);
  assert.match(launcher, /SearchResultRow\s*\{/);
  assert.match(launcher, /pinned:\s*root\.palette\.isPinned\(modelData\.id\)/);
  assert.match(launcher, /recent:\s*root\.palette\.isRecent\(modelData\.id\)/);
  assert.match(launcher, /immediateSelection:\s*root\.palette\.keyboardNavigationActive/);
  assert.match(launcher, /confirming:\s*root\.palette\.confirmingActionId === \(modelData\.actionId \|\| ""\)/);
  assert.match(launcher, /confirmationRequired:\s*root\.palette\.requiresResultConfirmation\(modelData\)/);
  assert.match(launcher, /onPinToggled:\s*root\.palette\.togglePinned\(modelData\.id\)/);

  assert.match(row, /import Quickshell/);
  assert.match(row, /Quickshell\.iconPath\(result\.icon,\s*"application-x-executable"\)/);
  assert.match(row, /property bool pinned:\s*false/);
  assert.match(row, /property bool recent:\s*false/);
  assert.match(row, /property bool immediateSelection:\s*false/);
  assert.match(row, /property bool confirmationRequired:\s*false/);
  assert.match(row, /property bool confirming:\s*false/);
  assert.match(row, /readonly property bool rowHovered:\s*rowHover\.hovered \|\| pinButton\.hovered/);
  assert.match(row, /readonly property bool showPinButton:\s*root\.selected \|\| root\.rowHovered \|\| root\.pinned/);
  assert.match(row, /HoverHandler\s*\{[\s\S]*id:\s*rowHover/);
  assert.match(row, /signal pinToggled\(\)/);
  assert.match(row, /text:\s*root\.confirming \? "Confirm again" : "Confirm"/);
  assert.match(row, /id:\s*pinButton/);
  assert.match(row, /icon:\s*root\.pinned \? "keep" : "keep_off"/);
  assert.match(row, /opacity:\s*root\.showPinButton \? 1 : 0/);
  assert.match(row, /enabled:\s*root\.showPinButton/);
  assert.match(row, /Behavior on opacity/);
  assert.doesNotMatch(row, /visible:\s*root\.selected \|\| rowArea\.containsMouse \|\| root\.pinned/);
  assert.match(row, /Behavior on color\s*\{[\s\S]*enabled:\s*!root\.immediateSelection/);
  assert.match(row, /Image\s*\{[\s\S]*source:\s*root\.appIconSource[\s\S]*sourceSize\.width:\s*width[\s\S]*sourceSize\.height:\s*height/);
  assert.match(row, /MaterialIcon\s*\{[\s\S]*visible:\s*!root\.appResult \|\| root\.appIconSource\.length === 0/);
  assert.doesNotMatch(row, /Quickshell\.execDetached|DesktopEntries/);
});
