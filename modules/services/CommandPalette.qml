import QtQuick

Item {
    id: root

    required property var appSearch
    required property var systemActions
    required property var sidebarController
    required property var settingsController

    property bool open: false
    property string inputQuery: ""
    property string query: ""
    property int searchDebounceMs: 45
    property int selectedIndex: 0
    property string pendingActionId: ""
    property string confirmingActionId: ""
    property var pinnedIds: ["command:open-control-center", "command:screenshot", "command:record"]
    property var recentIds: []
    property bool keyboardNavigationActive: false
    property int usageRevision: 0

    readonly property var commands: commandItems()
    readonly property int appSearchRevision: appSearch.revision
    readonly property var results: open ? searchResults(query, appSearchRevision, usageRevision) : []

    onInputQueryChanged: {
        selectedIndex = 0;
        clearConfirmation();

        if (open)
            searchDebounceTimer.restart();
        else
            commitInputQuery();
    }
    onQueryChanged: {
        selectedIndex = 0;
        clearConfirmation();
        if (open)
            appSearch.requestSearch(query);
    }
    onResultsChanged: clampSelection()

    function commandItems() {
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
                id: "command:open-settings",
                type: "command",
                title: "Open settings",
                subtitle: "Configure shell appearance and behavior",
                icon: "settings",
                keywords: ["settings", "config", "preferences", "configure"],
                actionId: "settings.open",
                defaultScore: 96,
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

    function normalizedText(value) {
        return String(value ?? "").trim().toLowerCase();
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

    function queryTokens(value) {
        return normalizedText(value).split(/\s+/).filter(token => token.length > 0);
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

    function scoreCommand(command, tokens) {
        if (tokens.length === 0)
            return command.defaultScore;

        let total = 0;
        for (let tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            const token = tokens[tokenIndex];
            let score = Math.max(
                scoreText(command.title, token, 160, 120, 80, 78, 62, 28, 64),
                scoreText(command.subtitle, token, 70, 55, 36, 34, 28, 14, 32),
                scoreText(command.actionId, token, 42, 30, 20, 22, 18, 8, 20)
            );

            for (const keyword of command.keywords)
                score = Math.max(score, scoreText(keyword, token, 90, 70, 44, 44, 34, 18, 40));

            if (score === 0)
                return 0;
            total += score;
        }

        return total;
    }

    function scoredCommand(command, score) {
        return {
            id: command.id,
            type: command.type,
            title: command.title,
            subtitle: command.subtitle,
            icon: command.icon,
            keywords: command.keywords,
            actionId: command.actionId,
            confirmation: command.confirmation,
            defaultScore: command.defaultScore,
            score,
        };
    }

    function idIndex(ids, id) {
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === id)
                return i;
        }
        return -1;
    }

    function isPinned(id) {
        return idIndex(pinnedIds, id) >= 0;
    }

    function isRecent(id) {
        return idIndex(recentIds, id) >= 0;
    }

    function togglePinned(id) {
        if (!id || id.length === 0)
            return;

        const next = [];
        const currentlyPinned = isPinned(id);
        if (!currentlyPinned)
            next.push(id);

        for (const pinnedId of pinnedIds) {
            if (pinnedId !== id)
                next.push(pinnedId);
        }

        pinnedIds = next;
        usageRevision += 1;
        clearConfirmation();
    }

    function recordUsage(id) {
        if (!id || id.length === 0)
            return;

        const next = [id];
        for (const recentId of recentIds) {
            if (recentId !== id)
                next.push(recentId);
            if (next.length >= 6)
                break;
        }

        recentIds = next;
        usageRevision += 1;
    }

    function usageAdjustedResult(result, tokens) {
        const pinnedIndex = idIndex(pinnedIds, result.id);
        const recentIndex = idIndex(recentIds, result.id);
        const pinned = pinnedIndex >= 0;
        const recent = recentIndex >= 0;
        let score = result.score;

        if (tokens.length > 0) {
            if (pinned)
                score += 18;
            if (recent)
                score += Math.max(2, 12 - recentIndex);
        }

        return {
            id: result.id,
            appId: result.appId,
            type: result.type,
            title: result.title,
            subtitle: result.subtitle,
            icon: result.icon,
            keywords: result.keywords,
            command: result.command,
            workingDirectory: result.workingDirectory,
            runInTerminal: result.runInTerminal,
            desktopEntry: result.desktopEntry,
            actionId: result.actionId,
            confirmation: result.confirmation,
            defaultScore: result.defaultScore,
            baseScore: result.score,
            score,
            pinned,
            pinnedIndex: pinned ? pinnedIndex : 999999,
            recent,
            recentIndex: recent ? recentIndex : 999999,
        };
    }

    function usagePriority(result) {
        if (result.pinned)
            return 2;
        if (result.recent)
            return 1;
        return 0;
    }

    function compareResults(a, b, tokens) {
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

    function requiresResultConfirmation(result) {
        return result?.confirmation?.required === true;
    }

    function clearConfirmation() {
        confirmingActionId = "";
        confirmTimer.stop();
    }

    function setInputQuery(value) {
        const nextQuery = String(value ?? "");
        if (inputQuery === nextQuery)
            return;

        inputQuery = nextQuery;
    }

    function commitInputQuery() {
        searchDebounceTimer.stop();

        if (query !== inputQuery)
            query = inputQuery;
        else
            clampSelection();
    }

    function resetSearch() {
        inputQuery = "";
        query = "";
        selectedIndex = 0;
        searchDebounceTimer.stop();
        clearConfirmation();
    }

    function searchResults(value, appRevision, usageVersion, limit) {
        const dependencyRevision = appRevision + usageVersion;
        const tokens = queryTokens(value);
        const appResults = appSearch.search(value);
        const commandResults = [];

        for (const command of commands) {
            const score = scoreCommand(command, tokens);
            if (score > 0)
                commandResults.push(scoredCommand(command, score));
        }

        const adjustedResults = [];
        for (const result of appResults.concat(commandResults))
            adjustedResults.push(usageAdjustedResult(result, tokens));

        const results = adjustedResults
            .sort((a, b) => compareResults(a, b, tokens));

        return Number.isFinite(limit) ? results.slice(0, limit) : results;
    }

    function openPalette() {
        resetSearch();
        open = true;
        appSearch.ensureCache();
        appSearch.requestSearch(query);
    }

    function close() {
        open = false;
        resetSearch();
        keyboardNavigationActive = false;
    }

    function toggle() {
        if (open)
            close();
        else
            openPalette();
    }

    function clampSelection() {
        if (results.length === 0) {
            selectedIndex = 0;
            return;
        }
        selectedIndex = Math.max(0, Math.min(selectedIndex, results.length - 1));
    }

    function moveSelection(delta) {
        commitInputQuery();
        if (results.length === 0)
            return;

        clearConfirmation();
        keyboardNavigationActive = true;
        keyboardNavigationResetTimer.restart();
        selectedIndex = (selectedIndex + delta + results.length) % results.length;
    }

    function executeSelected() {
        commitInputQuery();

        if (results.length === 0)
            return;

        executeResult(results[selectedIndex]);
    }

    function executeResult(result) {
        if (!result)
            return;

        if (requiresResultConfirmation(result)) {
            if (confirmingActionId !== result.actionId) {
                confirmingActionId = result.actionId;
                confirmTimer.restart();
                return;
            }

            clearConfirmation();
        } else {
            clearConfirmation();
        }

        recordUsage(result.id);

        if (result.type === "app" && result.desktopEntry) {
            close();
            result.desktopEntry.execute();
            return;
        }

        if (result.type === "app" && appSearch.launch(result)) {
            close();
            return;
        }

        pendingActionId = result.actionId || "";
        close();

        if (pendingActionId.length > 0)
            actionTimer.restart();
    }

    function runPendingAction() {
        const actionId = pendingActionId;
        pendingActionId = "";
        if (actionId === "settings.open") {
            settingsController.openSettings("");
            return;
        }

        if (actionId === "controlCenter.open") {
            sidebarController.openForOutput("");
            return;
        }
        if (actionId === "capture.screenshot") {
            systemActions.takeScreenshot();
            return;
        }
        if (actionId === "capture.record") {
            systemActions.toggleRecording();
            return;
        }
        if (actionId.startsWith("session.")) {
            const sessionAction = actionId.slice("session.".length);
            systemActions.runConfirmedSessionAction(sessionAction);
        }
    }

    Timer {
        id: confirmTimer
        interval: 4000
        repeat: false
        onTriggered: root.confirmingActionId = ""
    }

    Timer {
        id: searchDebounceTimer
        interval: root.searchDebounceMs
        repeat: false
        onTriggered: root.commitInputQuery()
    }

    Timer {
        id: keyboardNavigationResetTimer
        interval: 90
        repeat: false
        onTriggered: root.keyboardNavigationActive = false
    }

    Timer {
        id: actionTimer
        interval: 120
        repeat: false
        onTriggered: root.runPendingAction()
    }
}
