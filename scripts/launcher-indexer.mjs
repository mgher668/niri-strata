#!/usr/bin/env node
import { watch as watchDirectory } from "node:fs";
import { access, mkdir, readFile, readdir, rename, stat, writeFile } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { pathToFileURL } from "node:url";
import { spawn } from "node:child_process";

import {
  compactText,
  initialsText,
  normalizeDesktopEntries,
  normalizeText,
  parseDesktopEntry,
  searchPalette,
} from "../harness/lib/launcher-core.mjs";

export const launcherCacheSchemaVersion = 1;
export const defaultDebounceMs = 1200;

function nonEmpty(value) {
  return String(value ?? "").trim().length > 0;
}

export function defaultCachePath(env = process.env) {
  const cacheHome = nonEmpty(env.XDG_CACHE_HOME)
    ? env.XDG_CACHE_HOME
    : join(env.HOME || "/tmp", ".cache");

  return join(cacheHome, "niri-strata", "launcher-apps.json");
}

export function applicationDirectories(env = process.env) {
  const dataHome = nonEmpty(env.XDG_DATA_HOME)
    ? env.XDG_DATA_HOME
    : join(env.HOME || "/tmp", ".local", "share");

  const dataDirs = nonEmpty(env.XDG_DATA_DIRS)
    ? env.XDG_DATA_DIRS.split(":").filter(nonEmpty)
    : ["/usr/local/share", "/usr/share"];

  return [...new Set([
    join(dataHome, "applications"),
    ...dataDirs.map(directory => join(directory, "applications")),
  ])];
}

async function pathExists(path) {
  try {
    await access(path, fsConstants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function collectDesktopFilesFromDirectory(directory, base = directory, files = []) {
  let entries = [];
  try {
    entries = await readdir(directory, { withFileTypes: true });
  } catch (error) {
    if (error?.code === "ENOENT" || error?.code === "ENOTDIR" || error?.code === "EACCES")
      return files;
    throw error;
  }

  entries.sort((a, b) => a.name.localeCompare(b.name));

  for (const entry of entries) {
    const path = join(directory, entry.name);

    if (entry.isDirectory()) {
      await collectDesktopFilesFromDirectory(path, base, files);
      continue;
    }

    if (!entry.isFile() || !entry.name.endsWith(".desktop"))
      continue;

    const relativePath = relative(base, path);
    files.push({
      path,
      desktopFileId: relativePath.split(sep).join("-"),
    });
  }

  return files;
}

export async function collectDesktopFiles(directories = applicationDirectories()) {
  const files = [];

  for (const directory of directories)
    await collectDesktopFilesFromDirectory(directory, directory, files);

  return files;
}

export function addSearchFields(app) {
  const keywords = app.keywords ?? [];
  const searchText = [
    app.title,
    app.subtitle,
    app.command,
    ...keywords,
  ].filter(nonEmpty).join(" ");

  return {
    ...app,
    search: {
      title: normalizeText(app.title),
      subtitle: normalizeText(app.subtitle),
      command: normalizeText(app.command),
      keywords: keywords.map(keyword => normalizeText(keyword)),
      text: normalizeText(searchText),
      compact: compactText(searchText),
      initials: initialsText(searchText),
    },
  };
}

export async function scanApplications(options = {}) {
  const directories = options.directories ?? applicationDirectories(options.env);
  const files = await collectDesktopFiles(directories);
  const entries = [];

  for (const file of files) {
    let text = "";
    try {
      text = await readFile(file.path, "utf8");
    } catch (error) {
      if (error?.code === "ENOENT" || error?.code === "EACCES")
        continue;
      throw error;
    }

    const entry = parseDesktopEntry(text, file.path);
    entries.push({
      ...entry,
      id: file.desktopFileId,
      desktopFile: file.desktopFileId,
      source: file.path,
    });
  }

  return normalizeDesktopEntries(entries, { includeHidden: options.includeHidden })
    .map(addSearchFields);
}

export function createApplicationCache(apps, options = {}) {
  return {
    schemaVersion: launcherCacheSchemaVersion,
    generatedAt: new Date().toISOString(),
    desktopDirectories: options.directories ?? applicationDirectories(options.env),
    appCount: apps.length,
    apps,
  };
}

export async function writeApplicationCache(cache, cachePath = defaultCachePath()) {
  await mkdir(dirname(cachePath), { recursive: true });

  const temporaryPath = `${cachePath}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(temporaryPath, `${JSON.stringify(cache, null, 2)}\n`, "utf8");
  await rename(temporaryPath, cachePath);
}

export async function readApplicationCache(cachePath = defaultCachePath()) {
  const text = await readFile(cachePath, "utf8");
  const cache = JSON.parse(text);

  if (cache?.schemaVersion !== launcherCacheSchemaVersion)
    throw new Error(`Unsupported launcher cache schema: ${cache?.schemaVersion ?? "missing"}`);
  if (!Array.isArray(cache.apps))
    throw new Error("Launcher cache is missing apps array");

  return cache;
}

export async function applicationCacheIsFresh(cachePath, directories) {
  let cacheInfo = null;
  try {
    cacheInfo = await stat(cachePath);
  } catch {
    return false;
  }

  const files = await collectDesktopFiles(directories);
  for (const file of files) {
    try {
      const fileInfo = await stat(file.path);
      if (fileInfo.mtimeMs > cacheInfo.mtimeMs)
        return false;
    } catch (error) {
      if (error?.code === "ENOENT" || error?.code === "EACCES")
        continue;
      throw error;
    }
  }

  return true;
}

export async function rebuildApplicationCache(options = {}) {
  const directories = options.directories ?? applicationDirectories(options.env);
  const apps = await scanApplications({ ...options, directories });
  const cache = createApplicationCache(apps, { ...options, directories });

  await writeApplicationCache(cache, options.cachePath ?? defaultCachePath(options.env));
  return cache;
}

export async function ensureApplicationCache(options = {}) {
  const cachePath = options.cachePath ?? defaultCachePath(options.env);
  const directories = options.directories ?? applicationDirectories(options.env);

  if (await pathExists(cachePath) && await applicationCacheIsFresh(cachePath, directories)) {
    try {
      return await readApplicationCache(cachePath);
    } catch {
      return rebuildApplicationCache({ ...options, cachePath, directories });
    }
  }

  return rebuildApplicationCache({ ...options, cachePath, directories });
}

export function searchApplications(query, apps, options = {}) {
  return searchPalette(query, apps, [], options);
}

function stripDesktopFieldCodes(command) {
  return String(command ?? "")
    .replace(/%%/g, "\u0000")
    .replace(/%[fFuUdDnNickvm]/g, "")
    .replace(/\u0000/g, "%")
    .replace(/\s+/g, " ")
    .trim();
}

function quoteShell(value) {
  return `'${String(value).replace(/'/g, "'\\''")}'`;
}

export function buildLaunchCommand(app, env = process.env) {
  const command = stripDesktopFieldCodes(app?.command);
  if (!nonEmpty(command))
    throw new Error(`No launch command for ${app?.id ?? "application"}`);

  if (app?.runInTerminal) {
    const terminal = env.TERMINAL || "xterm";
    return `${terminal} -e ${quoteShell(command)}`;
  }

  return command;
}

export async function launchApplication(appId, options = {}) {
  const cache = await ensureApplicationCache(options);
  const app = cache.apps.find(candidate => candidate.appId === appId || candidate.id === appId);

  if (!app)
    throw new Error(`Application not found: ${appId}`);

  const command = buildLaunchCommand(app, options.env);
  const child = spawn("sh", ["-c", command], {
    cwd: nonEmpty(app.workingDirectory) ? app.workingDirectory : undefined,
    detached: true,
    stdio: "ignore",
  });

  child.unref();
  return { appId: app.appId, command };
}

async function collectWatchDirectories(directories) {
  const watched = [];

  async function collect(directory) {
    let entries = [];
    try {
      const info = await stat(directory);
      if (!info.isDirectory())
        return;
      entries = await readdir(directory, { withFileTypes: true });
    } catch (error) {
      if (error?.code === "ENOENT" || error?.code === "ENOTDIR" || error?.code === "EACCES")
        return;
      throw error;
    }

    watched.push(directory);
    entries.sort((a, b) => a.name.localeCompare(b.name));

    for (const entry of entries) {
      if (entry.isDirectory())
        await collect(join(directory, entry.name));
    }
  }

  for (const directory of directories)
    await collect(directory);

  return [...new Set(watched)];
}

export async function watchApplicationCache(options = {}) {
  const debounceMs = Number.isFinite(options.debounceMs)
    ? options.debounceMs
    : defaultDebounceMs;
  const directories = options.directories ?? applicationDirectories(options.env);
  let watchers = [];
  let debounceTimer = null;
  let rebuilding = false;
  let rebuildAgain = false;

  function closeWatchers() {
    for (const watcher of watchers)
      watcher.close();
    watchers = [];
  }

  async function installWatchers() {
    closeWatchers();
    const watchDirectories = await collectWatchDirectories(directories);

    for (const directory of watchDirectories) {
      try {
        watchers.push(watchDirectory(directory, { persistent: true }, scheduleRebuild));
      } catch {
        // A directory can disappear between collection and watch setup.
      }
    }
  }

  async function rebuild() {
    if (rebuilding) {
      rebuildAgain = true;
      return;
    }

    rebuilding = true;
    try {
      const cache = await rebuildApplicationCache({ ...options, directories });
      await installWatchers();
      if (!options.quiet) {
        process.stdout.write(JSON.stringify({
          type: "cache-rebuilt",
          appCount: cache.appCount,
          generatedAt: cache.generatedAt,
        }) + "\n");
      }
    } finally {
      rebuilding = false;
      if (rebuildAgain) {
        rebuildAgain = false;
        scheduleRebuild();
      }
    }
  }

  function scheduleRebuild() {
    if (debounceTimer !== null)
      clearTimeout(debounceTimer);

    debounceTimer = setTimeout(() => {
      debounceTimer = null;
      rebuild().catch(error => {
        process.stderr.write(`${error.stack || error.message}\n`);
      });
    }, debounceMs);
  }

  await rebuild();

  return {
    close() {
      if (debounceTimer !== null)
        clearTimeout(debounceTimer);
      closeWatchers();
    },
  };
}

function parseArgs(argv) {
  const args = { _: [] };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === "--cache") {
      args.cachePath = argv[++i];
    } else if (arg === "--query") {
      args.query = argv[++i] ?? "";
    } else if (arg === "--app-id") {
      args.appId = argv[++i] ?? "";
    } else if (arg === "--debounce-ms") {
      args.debounceMs = Number(argv[++i]);
    } else if (arg === "--pretty") {
      args.pretty = true;
    } else if (arg === "--quiet") {
      args.quiet = true;
    } else {
      args._.push(arg);
    }
  }

  return args;
}

function writeJson(value, pretty = false) {
  process.stdout.write(`${JSON.stringify(value, null, pretty ? 2 : 0)}\n`);
}

export async function runCli(argv = process.argv.slice(2), env = process.env) {
  const args = parseArgs(argv);
  const command = args._[0] || "search";
  const options = {
    cachePath: args.cachePath ?? defaultCachePath(env),
    debounceMs: args.debounceMs,
    quiet: args.quiet,
    env,
  };

  if (command === "scan") {
    const cache = await rebuildApplicationCache(options);
    writeJson({
      cachePath: options.cachePath,
      generatedAt: cache.generatedAt,
      appCount: cache.appCount,
    }, args.pretty);
    return;
  }

  if (command === "search") {
    const cache = await ensureApplicationCache(options);
    const query = args.query ?? args._.slice(1).join(" ");
    writeJson({
      query,
      cachePath: options.cachePath,
      generatedAt: cache.generatedAt,
      appCount: cache.appCount,
      results: searchApplications(query, cache.apps),
    }, args.pretty);
    return;
  }

  if (command === "launch") {
    const result = await launchApplication(args.appId ?? args._[1], options);
    writeJson(result, args.pretty);
    return;
  }

  if (command === "watch") {
    await watchApplicationCache(options);
    return await new Promise(() => {});
  }

  throw new Error(`Unknown launcher-indexer command: ${command}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli().catch(error => {
    process.stderr.write(`${error.stack || error.message}\n`);
    process.exitCode = 1;
  });
}
