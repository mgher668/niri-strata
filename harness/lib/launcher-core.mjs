export const desktopEntryFields = [
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
];

export function normalizeText(value) {
  return String(value ?? "").trim().toLowerCase();
}

export function compactText(value) {
  return normalizeText(value).replace(/[^a-z0-9]+/g, "");
}

export function initialsText(value) {
  return normalizeText(value)
    .split(/[^a-z0-9]+/)
    .filter(Boolean)
    .map(part => part[0])
    .join("");
}

export function slugText(value) {
  return normalizeText(value)
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "item";
}

function parseDesktopBoolean(value) {
  return String(value ?? "").trim().toLowerCase() === "true";
}

function decodeDesktopString(value) {
  return String(value ?? "")
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\r/g, "\r")
    .replace(/\\s/g, " ")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\")
    .trim();
}

export function splitDesktopList(value) {
  if (Array.isArray(value))
    return value.map(item => String(item).trim()).filter(Boolean);

  return String(value ?? "")
    .split(";")
    .map(item => decodeDesktopString(item))
    .filter(Boolean);
}

export function parseDesktopEntry(text, source = "") {
  const entry = { source };
  let group = "";

  for (const rawLine of String(text ?? "").split("\n")) {
    const line = rawLine.trim();
    if (line.length === 0 || line.startsWith("#"))
      continue;

    const groupMatch = line.match(/^\[(.*)]$/);
    if (groupMatch) {
      group = groupMatch[1];
      continue;
    }

    if (group !== "Desktop Entry")
      continue;

    const separator = line.indexOf("=");
    if (separator < 1)
      continue;

    const key = line.slice(0, separator).trim();
    const value = decodeDesktopString(line.slice(separator + 1));

    if (key === "Type")
      entry.type = value;
    else if (key === "Name")
      entry.name = value;
    else if (key === "GenericName")
      entry.genericName = value;
    else if (key === "Comment")
      entry.comment = value;
    else if (key === "Icon")
      entry.icon = value;
    else if (key === "Exec")
      entry.command = value;
    else if (key === "Path")
      entry.workingDirectory = value;
    else if (key === "Terminal")
      entry.runInTerminal = parseDesktopBoolean(value);
    else if (key === "Categories")
      entry.categories = splitDesktopList(value);
    else if (key === "Keywords")
      entry.keywords = splitDesktopList(value);
    else if (key === "NoDisplay")
      entry.noDisplay = parseDesktopBoolean(value);
    else if (key === "Hidden")
      entry.hidden = parseDesktopBoolean(value);
  }

  return entry;
}

function firstString(...values) {
  for (const value of values) {
    const text = String(value ?? "").trim();
    if (text.length > 0)
      return text;
  }
  return "";
}

export function normalizeDesktopEntry(entry, options = {}) {
  const type = firstString(entry?.type, entry?.Type, "Application");
  const hidden = entry?.hidden === true || entry?.Hidden === true;
  const noDisplay = entry?.noDisplay === true || entry?.NoDisplay === true;

  if (type !== "Application")
    return null;
  if (!options.includeHidden && (hidden || noDisplay))
    return null;

  const title = firstString(entry?.name, entry?.Name);
  if (title.length === 0)
    return null;

  const rawId = firstString(entry?.id, entry?.desktopFile, entry?.source, title);
  const keywords = [
    ...splitDesktopList(entry?.keywords ?? entry?.Keywords),
    ...splitDesktopList(entry?.categories ?? entry?.Categories),
  ];

  return {
    id: `app:${rawId}`,
    appId: rawId,
    type: "app",
    title,
    subtitle: firstString(entry?.genericName, entry?.GenericName, entry?.comment, entry?.Comment),
    icon: firstString(entry?.icon, entry?.Icon, "apps"),
    keywords,
    command: firstString(entry?.command, entry?.Exec),
    workingDirectory: firstString(entry?.workingDirectory, entry?.Path),
    runInTerminal: entry?.runInTerminal === true || entry?.Terminal === true,
    defaultScore: 38,
  };
}

export function normalizeDesktopEntries(entries, options = {}) {
  const seen = new Set();
  const normalized = [];

  for (const entry of entries ?? []) {
    const app = normalizeDesktopEntry(entry, options);
    if (!app || seen.has(app.id))
      continue;

    seen.add(app.id);
    normalized.push(app);
  }

  return normalized;
}

export function commandPaletteActions() {
  return [
    {
      id: "command:open-control-center",
      type: "command",
      title: "Open control center",
      subtitle: "Show sidebar controls",
      icon: "tune",
      keywords: ["control", "center", "sidebar", "settings", "quick"],
      actionId: "controlCenter.open",
      defaultScore: 100,
    },
    {
      id: "command:screenshot",
      type: "command",
      title: "Take screenshot",
      subtitle: "Copy focused screen to clipboard",
      icon: "screenshot_region",
      keywords: ["screen", "capture", "clipboard", "shot"],
      actionId: "capture.screenshot",
      defaultScore: 92,
    },
    {
      id: "command:record",
      type: "command",
      title: "Toggle recording",
      subtitle: "Start or stop screen recording",
      icon: "radio_button_checked",
      keywords: ["record", "video", "screen", "capture"],
      actionId: "capture.record",
      defaultScore: 88,
    },
    {
      id: "command:lock",
      type: "command",
      title: "Lock screen",
      subtitle: "Start the lock screen",
      icon: "lock",
      keywords: ["lock", "session", "secure"],
      actionId: "session.lock",
      defaultScore: 72,
    },
    {
      id: "command:logout",
      type: "command",
      title: "Log out",
      subtitle: "End the current niri session",
      icon: "logout",
      keywords: ["quit", "exit", "session"],
      actionId: "session.logout",
      confirmation: { required: true, reason: "Ends the current session" },
      defaultScore: 20,
    },
    {
      id: "command:suspend",
      type: "command",
      title: "Suspend",
      subtitle: "Suspend this computer",
      icon: "bedtime",
      keywords: ["sleep", "power"],
      actionId: "session.suspend",
      confirmation: { required: true, reason: "Suspends this computer" },
      defaultScore: 18,
    },
    {
      id: "command:reboot",
      type: "command",
      title: "Reboot",
      subtitle: "Restart this computer",
      icon: "restart_alt",
      keywords: ["restart", "power"],
      actionId: "session.reboot",
      confirmation: { required: true, reason: "Restarts this computer" },
      defaultScore: 16,
    },
    {
      id: "command:shutdown",
      type: "command",
      title: "Shut down",
      subtitle: "Power off this computer",
      icon: "power_settings_new",
      keywords: ["poweroff", "power", "off"],
      actionId: "session.shutdown",
      confirmation: { required: true, reason: "Powers off this computer" },
      defaultScore: 14,
    },
  ];
}

export function queryTokens(query) {
  return normalizeText(query).split(/\s+/).filter(Boolean);
}

function subsequenceScore(text, token) {
  const value = compactText(text);
  const needle = compactText(token);
  if (value.length === 0 || needle.length === 0)
    return 0;

  let lastIndex = -1;
  let score = 0;

  for (const character of needle) {
    const nextIndex = value.indexOf(character, lastIndex + 1);
    if (nextIndex < 0)
      return 0;

    if (nextIndex === 0 && lastIndex < 0)
      score += 12;
    else if (nextIndex === lastIndex + 1)
      score += 10;
    else
      score += Math.max(3, 8 - (nextIndex - lastIndex - 1));

    lastIndex = nextIndex;
  }

  return score;
}

function textScore(text, token, weights) {
  const value = normalizeText(text);
  if (value.length === 0)
    return 0;
  if (value === token)
    return weights.exact;
  if (value.startsWith(token))
    return weights.prefix;
  if (value.includes(token))
    return weights.includes;

  const initials = initialsText(value);
  if (initials === token)
    return weights.acronymExact;
  if (initials.startsWith(token))
    return weights.acronymPrefix;

  const fuzzy = subsequenceScore(value, token);
  if (fuzzy > 0)
    return Math.min(weights.fuzzyMax, weights.fuzzy + fuzzy);

  return 0;
}

function itemScore(item, tokens) {
  if (tokens.length === 0)
    return item.defaultScore ?? 0;

  let total = item.type === "app" ? 8 : 0;

  for (const token of tokens) {
    const score = Math.max(
      textScore(item.title, token, { exact: 160, prefix: 120, includes: 80, acronymExact: 78, acronymPrefix: 62, fuzzy: 28, fuzzyMax: 64 }),
      textScore(item.subtitle, token, { exact: 70, prefix: 55, includes: 36, acronymExact: 34, acronymPrefix: 28, fuzzy: 14, fuzzyMax: 32 }),
      ...(item.keywords ?? []).map(keyword => textScore(keyword, token, { exact: 90, prefix: 70, includes: 44, acronymExact: 44, acronymPrefix: 34, fuzzy: 18, fuzzyMax: 40 })),
      textScore(item.command, token, { exact: 36, prefix: 28, includes: 18, acronymExact: 20, acronymPrefix: 16, fuzzy: 8, fuzzyMax: 20 }),
      textScore(item.actionId, token, { exact: 42, prefix: 30, includes: 20, acronymExact: 22, acronymPrefix: 18, fuzzy: 8, fuzzyMax: 20 }),
    );

    if (score === 0)
      return 0;
    total += score;
  }

  return total;
}

function usageIndex(ids, id) {
  return (ids ?? []).indexOf(id);
}

function decorateUsage(item, tokens, options) {
  const pinnedIndex = usageIndex(options.pinnedIds, item.id);
  const recentIndex = usageIndex(options.recentIds, item.id);
  const pinned = pinnedIndex >= 0;
  const recent = recentIndex >= 0;
  const baseScore = itemScore(item, tokens);
  let score = baseScore;

  if (tokens.length > 0) {
    if (pinned)
      score += 18;
    if (recent)
      score += Math.max(2, 12 - recentIndex);
  }

  return {
    ...item,
    baseScore,
    pinned,
    pinnedIndex: pinned ? pinnedIndex : Number.MAX_SAFE_INTEGER,
    recent,
    recentIndex: recent ? recentIndex : Number.MAX_SAFE_INTEGER,
    score,
  };
}

function usagePriority(item) {
  if (item.pinned)
    return 2;
  if (item.recent)
    return 1;
  return 0;
}

function comparePaletteItems(a, b, tokens) {
  if (tokens.length === 0) {
    const priority = usagePriority(b) - usagePriority(a);
    if (priority !== 0)
      return priority;
    if (a.pinnedIndex !== b.pinnedIndex)
      return a.pinnedIndex - b.pinnedIndex;
    if (a.recentIndex !== b.recentIndex)
      return a.recentIndex - b.recentIndex;
  }

  if (b.score !== a.score)
    return b.score - a.score;
  if (a.type !== b.type)
    return a.type === "app" ? -1 : 1;
  return a.title.localeCompare(b.title);
}

export function searchPalette(query, apps = [], commands = commandPaletteActions(), options = {}) {
  const tokens = queryTokens(query);
  const limit = options.limit;
  const items = [...apps, ...commands];

  const results = items
    .map(item => decorateUsage(item, tokens, options))
    .filter(item => item.score > 0)
    .sort((a, b) => comparePaletteItems(a, b, tokens));

  return Number.isFinite(limit) ? results.slice(0, limit) : results;
}
