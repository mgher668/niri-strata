import QtQuick
import Quickshell

Item {
    id: root

    property bool includeHidden: false
    property bool cacheLoaded: false
    property bool refreshingCache: false
    readonly property var applications: cacheLoaded ? DesktopEntries.applications.values : []
    property var appCache: []
    property int revision: 0

    onApplicationsChanged: {
        if (cacheLoaded && !refreshingCache)
            refreshCache();
    }
    onIncludeHiddenChanged: {
        if (cacheLoaded)
            refreshCache();
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

    function ensureCache() {
        if (!cacheLoaded)
            refreshCache();
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

    function search(query, limit) {
        ensureCache();

        const tokens = queryTokens(query);
        const scored = [];
        const apps = normalizedApplications();

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
}
