import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool includeHidden: false
    property bool cacheLoaded: false
    property bool fallbackCacheLoaded: false
    property bool refreshingCache: false
    property bool helperAvailable: true
    property bool helperSearchRunning: false
    property bool helperWatchStarted: false
    property string helperLastError: ""
    property string activeQuery: ""
    property var pendingQuery: null
    property var queryResults: ({})
    property var helperApps: []
    property var lastStableResults: []
    readonly property var applications: fallbackCacheLoaded ? DesktopEntries.applications.values : []
    property var appCache: []
    property int revision: 0

    readonly property string helperScriptUrl: String(Qt.resolvedUrl("../../scripts/launcher-indexer.mjs"))
    readonly property string helperScript: helperScriptUrl.startsWith("file://")
        ? decodeURIComponent(helperScriptUrl.slice(7))
        : helperScriptUrl

    onApplicationsChanged: {
        if (fallbackCacheLoaded && !refreshingCache)
            refreshCache();
    }
    onIncludeHiddenChanged: {
        if (fallbackCacheLoaded)
            refreshCache();
    }

    function helperCommand(args) {
        return ["node", helperScript].concat(args || []);
    }

    function startWatcher() {
        if (helperWatchStarted)
            return;

        helperWatchStarted = true;
        watcherProcess.exec(helperCommand(["watch", "--quiet"]));
    }

    function ensureCache() {
        startWatcher();
        requestSearch("");
    }

    function requestSearch(query) {
        const key = String(query ?? "");

        if (queryResults[key] !== undefined && pendingQuery === null)
            return;

        pendingQuery = key;
        runPendingSearch();
    }

    function runPendingSearch() {
        if (searchProcess.running || pendingQuery === null)
            return;

        activeQuery = String(pendingQuery);
        pendingQuery = null;
        helperSearchRunning = true;
        searchProcess.exec(helperCommand(["search", "--query", activeQuery]));
    }

    function applySearchPayload(payload) {
        if (!payload || !Array.isArray(payload.results))
            throw new Error("Invalid launcher helper payload");

        const key = String(payload.query ?? activeQuery);
        const next = Object.assign({}, queryResults);
        next[key] = payload.results;
        queryResults = next;
        if (key === "")
            helperApps = payload.results;
        lastStableResults = payload.results;
        helperAvailable = true;
        cacheLoaded = true;
        helperLastError = "";
        revision += 1;
    }

    function applySearchOutput(text) {
        const trimmed = String(text ?? "").trim();
        if (trimmed.length === 0)
            return;

        try {
            applySearchPayload(JSON.parse(trimmed));
        } catch (error) {
            helperAvailable = false;
            helperLastError = String(error);
            refreshCache();
        }
    }

    function handleSearchExit(exitCode) {
        helperSearchRunning = false;

        if (exitCode !== 0) {
            helperAvailable = false;
            refreshCache();
        }

        runPendingSearch();
    }

    function search(query, limit) {
        const key = String(query ?? "");
        let results = queryResults[key];

        if (results === undefined && !helperAvailable)
            results = fallbackSearch(key);
        else if (results === undefined && helperApps.length > 0)
            results = cachedSearch(key, helperApps, limit);
        else if (results === undefined && (helperSearchRunning || pendingQuery !== null))
            results = lastStableResults;
        else if (results === undefined)
            results = [];

        return Number.isFinite(limit) ? results.slice(0, limit) : results;
    }

    function launch(result) {
        if (!result || String(result.appId || "").length === 0)
            return false;

        launchProcess.exec(helperCommand(["launch", "--app-id", String(result.appId)]));
        return true;
    }

    function text(value) {
        return String(value ?? "").trim();
    }

    function normalizedText(value) {
        return text(value).toLowerCase();
    }

    function compactText(value) {
        return normalizedText(value).replace(/[^a-z0-9]+/g, "");
    }

    function initialsText(value) {
        return normalizedText(value)
            .split(/[^a-z0-9]+/)
            .filter(part => part.length > 0)
            .map(part => part[0])
            .join("");
    }

    function listValues(value) {
        if (value === undefined || value === null)
            return [];

        if (Array.isArray(value))
            return value.map(item => text(item)).filter(item => item.length > 0);

        if (typeof value === "object" && value.length !== undefined) {
            const items = [];
            for (let i = 0; i < value.length; i++) {
                const item = text(value[i]);
                if (item.length > 0)
                    items.push(item);
            }
            return items;
        }

        return String(value).split(";").map(item => text(item)).filter(item => item.length > 0);
    }

    function normalizeApplication(entry) {
        if (!entry)
            return null;
        if (!includeHidden && entry.noDisplay)
            return null;

        const title = text(entry.name);
        if (title.length === 0)
            return null;

        const rawId = text(entry.id).length > 0 ? text(entry.id) : title;
        const subtitle = text(entry.genericName).length > 0 ? text(entry.genericName) : text(entry.comment);

        return {
            id: "app:" + rawId,
            appId: rawId,
            type: "app",
            title,
            subtitle,
            icon: text(entry.icon).length > 0 ? text(entry.icon) : "apps",
            keywords: listValues(entry.keywords).concat(listValues(entry.categories)),
            command: text(entry.command),
            workingDirectory: text(entry.workingDirectory),
            runInTerminal: entry.runInTerminal === true,
            desktopEntry: entry,
            defaultScore: 38,
        };
    }

    function refreshCache() {
        refreshingCache = true;
        fallbackCacheLoaded = true;

        const seen = {};
        const apps = [];
        const source = DesktopEntries.applications.values || [];

        for (let i = 0; i < source.length; i++) {
            const app = normalizeApplication(source[i]);
            if (!app || seen[app.id])
                continue;

            seen[app.id] = true;
            apps.push(app);
        }

        appCache = apps;
        cacheLoaded = true;
        revision += 1;
        refreshingCache = false;
        return apps;
    }

    function normalizedApplications() {
        return appCache;
    }

    function queryTokens(query) {
        return normalizedText(query).split(/\s+/).filter(token => token.length > 0);
    }

    function subsequenceScore(value, token) {
        const candidate = compactText(value);
        const needle = compactText(token);
        if (candidate.length === 0 || needle.length === 0)
            return 0;

        let lastIndex = -1;
        let score = 0;
        for (const character of needle) {
            const nextIndex = candidate.indexOf(character, lastIndex + 1);
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

    function scoreText(value, token, exact, prefix, includes, acronymExact, acronymPrefix, fuzzy, fuzzyMax) {
        const candidate = normalizedText(value);
        if (candidate.length === 0)
            return 0;
        if (candidate === token)
            return exact;
        if (candidate.startsWith(token))
            return prefix;
        if (candidate.indexOf(token) >= 0)
            return includes;

        const initials = initialsText(candidate);
        if (initials === token)
            return acronymExact;
        if (initials.startsWith(token))
            return acronymPrefix;

        const fuzzyScore = subsequenceScore(candidate, token);
        if (fuzzyScore > 0)
            return Math.min(fuzzyMax, fuzzy + fuzzyScore);

        return 0;
    }

    function scoreApp(app, tokens) {
        if (tokens.length === 0)
            return app.defaultScore;

        let total = 8;
        for (let tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            const token = tokens[tokenIndex];
            let score = Math.max(
                scoreText(app.title, token, 160, 120, 80, 78, 62, 28, 64),
                scoreText(app.subtitle, token, 70, 55, 36, 34, 28, 14, 32),
                scoreText(app.command, token, 36, 28, 18, 20, 16, 8, 20)
            );

            for (const keyword of app.keywords)
                score = Math.max(score, scoreText(keyword, token, 90, 70, 44, 44, 34, 18, 40));

            if (score === 0)
                return 0;
            total += score;
        }

        return total;
    }

    function scoredApp(app, score) {
        return {
            id: app.id,
            appId: app.appId,
            type: app.type,
            title: app.title,
            subtitle: app.subtitle,
            icon: app.icon,
            keywords: app.keywords,
            command: app.command,
            workingDirectory: app.workingDirectory,
            runInTerminal: app.runInTerminal,
            desktopEntry: app.desktopEntry,
            defaultScore: app.defaultScore,
            score,
        };
    }

    function cachedSearch(query, apps, limit) {
        const tokens = queryTokens(query);
        const scored = [];

        for (const app of apps) {
            const score = scoreApp(app, tokens);
            if (score > 0)
                scored.push(scoredApp(app, score));
        }

        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.title.localeCompare(b.title);
        });

        return Number.isFinite(limit) ? scored.slice(0, limit) : scored;
    }

    function fallbackSearch(query, limit) {
        if (!fallbackCacheLoaded)
            refreshCache();

        return cachedSearch(query, normalizedApplications(), limit);
    }

    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: root.applySearchOutput(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.helperLastError = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => root.handleSearchExit(exitCode)
    }

    Process {
        id: launchProcess
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.helperLastError = message.split("\n")[0];
            }
        }
    }

    Process {
        id: watcherProcess
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.helperLastError = message.split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.helperAvailable = false;
        }
    }
}
