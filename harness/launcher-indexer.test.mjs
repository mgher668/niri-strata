import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import test from "node:test";
import assert from "node:assert/strict";

import {
  addSearchFields,
  applicationCacheIsFresh,
  buildLaunchCommand,
  createApplicationCache,
  defaultDebounceMs,
  readApplicationCache,
  rebuildApplicationCache,
  searchApplications,
  writeApplicationCache,
} from "../scripts/launcher-indexer.mjs";

async function writeDesktopFile(root, relativePath, content) {
  const path = join(root, relativePath);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, content, "utf8");
  return path;
}

test("builds launcher cache from XDG desktop files", async () => {
  const root = await mkdtemp(join(tmpdir(), "niri-strata-launcher-"));
  const userApps = join(root, "user", "applications");
  const systemApps = join(root, "system", "applications");
  const cachePath = join(root, "cache", "launcher-apps.json");

  await writeDesktopFile(userApps, "org.example.Terminal.desktop", `
[Desktop Entry]
Type=Application
Name=Example Terminal
GenericName=Terminal Emulator
Comment=Run a shell
Icon=utilities-terminal
Exec=example-terminal --new-window %U
Path=/tmp
Terminal=false
Categories=System;TerminalEmulator;
Keywords=shell;console;
`);

  await writeDesktopFile(systemApps, "org.example.Terminal.desktop", `
[Desktop Entry]
Type=Application
Name=System Terminal Duplicate
Exec=duplicate-terminal
`);

  await writeDesktopFile(systemApps, "hidden.desktop", `
[Desktop Entry]
Type=Application
Name=Hidden Tool
Exec=hidden-tool
NoDisplay=true
`);

  await writeDesktopFile(systemApps, "Utilities/org.example.Files.desktop", `
[Desktop Entry]
Type=Application
Name=Files
Comment=Browse folders
Icon=org.example.Files
Exec=files
Categories=Utility;
`);

  const cache = await rebuildApplicationCache({
    cachePath,
    directories: [userApps, systemApps],
  });

  assert.equal(cache.schemaVersion, 1);
  assert.equal(cache.appCount, 2);
  assert.deepEqual(cache.apps.map(app => app.title), ["Example Terminal", "Files"]);

  const terminal = cache.apps[0];
  assert.equal(terminal.id, "app:org.example.Terminal.desktop");
  assert.equal(terminal.appId, "org.example.Terminal.desktop");
  assert.equal(terminal.command, "example-terminal --new-window %U");
  assert.deepEqual(terminal.keywords, ["shell", "console", "System", "TerminalEmulator"]);
  assert.equal(terminal.search.title, "example terminal");
  assert.equal(terminal.search.compact.includes("exampleterminal"), true);

  const written = await readApplicationCache(cachePath);
  assert.equal(written.appCount, 2);
  assert.equal(await applicationCacheIsFresh(cachePath, [userApps, systemApps]), true);
});

test("searches every matching app in deterministic ranked order", async () => {
  const apps = [
    addSearchFields({
      id: "app:firefox.desktop",
      appId: "firefox.desktop",
      type: "app",
      title: "Firefox",
      subtitle: "Web Browser",
      icon: "firefox",
      keywords: ["internet"],
      command: "firefox",
      workingDirectory: "",
      runInTerminal: false,
      defaultScore: 38,
    }),
    addSearchFields({
      id: "app:foo-fighters.desktop",
      appId: "foo-fighters.desktop",
      type: "app",
      title: "Foo Fighters",
      subtitle: "",
      icon: "audio",
      keywords: ["music"],
      command: "foo-fighters",
      workingDirectory: "",
      runInTerminal: false,
      defaultScore: 38,
    }),
    addSearchFields({
      id: "app:file-finder.desktop",
      appId: "file-finder.desktop",
      type: "app",
      title: "File Finder",
      subtitle: "",
      icon: "files",
      keywords: ["files"],
      command: "file-finder",
      workingDirectory: "",
      runInTerminal: false,
      defaultScore: 38,
    }),
  ];

  const results = searchApplications("f", apps);

  assert.equal(results.length, 3);
  assert.ok(results.some(result => result.id === "app:firefox.desktop"));
  assert.deepEqual(
    results.map(result => result.score),
    [...results].map(result => result.score).sort((a, b) => b - a),
  );
});

test("writes and reads a stable launcher cache schema", async () => {
  const root = await mkdtemp(join(tmpdir(), "niri-strata-launcher-cache-"));
  const cachePath = join(root, "launcher-apps.json");
  const apps = [
    addSearchFields({
      id: "app:browser.desktop",
      appId: "browser.desktop",
      type: "app",
      title: "Browser",
      subtitle: "",
      icon: "browser",
      keywords: [],
      command: "browser",
      workingDirectory: "",
      runInTerminal: false,
      defaultScore: 38,
    }),
  ];
  const cache = createApplicationCache(apps, { directories: [join(root, "applications")] });

  await writeApplicationCache(cache, cachePath);

  const text = await readFile(cachePath, "utf8");
  assert.match(text, /"schemaVersion": 1/);
  assert.match(text, /"appCount": 1/);

  const parsed = await readApplicationCache(cachePath);
  assert.equal(parsed.apps[0].search.title, "browser");
});

test("normalizes desktop Exec field codes for helper launch", () => {
  assert.equal(
    buildLaunchCommand({ command: "firefox %U --name %%literal" }),
    "firefox --name %literal",
  );
  assert.equal(
    buildLaunchCommand({ command: "editor %f", runInTerminal: true }, { TERMINAL: "foot" }),
    "foot -e 'editor'",
  );
});

test("keeps watch debounce behavior explicit in the helper", async () => {
  const source = await readFile(join(process.cwd(), "scripts/launcher-indexer.mjs"), "utf8");

  assert.equal(defaultDebounceMs, 1200);
  assert.match(source, /watchDirectory/);
  assert.match(source, /setTimeout/);
  assert.match(source, /debounceMs/);
  assert.match(source, /last good cache|ensureApplicationCache|rebuildApplicationCache/);
});
