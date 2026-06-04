import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property int updateInterval: 3000
    readonly property int historyLimit: 40

    property real memoryTotalKb: 1
    property real memoryAvailableKb: 0
    property real memoryUsedKb: Math.max(0, memoryTotalKb - memoryAvailableKb)
    property real memoryUsage: clamp01(memoryUsedKb / memoryTotalKb)
    property real swapTotalKb: 0
    property real swapFreeKb: 0
    property real swapUsedKb: Math.max(0, swapTotalKb - swapFreeKb)
    property real swapUsage: swapTotalKb > 0 ? clamp01(swapUsedKb / swapTotalKb) : 0
    property real cpuUsage: 0
    property var previousCpuStats: null
    property list<real> cpuHistory: []
    property list<real> memoryHistory: []
    property list<real> swapHistory: []

    readonly property string cpuText: percentText(cpuUsage)
    readonly property string memoryText: percentText(memoryUsage)
    readonly property string swapText: percentText(swapUsage)
    readonly property string memoryTotalText: kbToGbText(memoryTotalKb)
    readonly property string swapTotalText: kbToGbText(swapTotalKb)

    function clamp01(value) {
        if (!Number.isFinite(value))
            return 0;
        return Math.max(0, Math.min(1, value));
    }

    function percentText(ratio) {
        return `${Math.round(clamp01(ratio) * 100)}%`;
    }

    function kbToGbText(kb) {
        if (!Number.isFinite(kb) || kb <= 0)
            return "--";
        return `${(kb / (1024 * 1024)).toFixed(1)} GB`;
    }

    function readKb(text, key, fallback) {
        const match = text.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"));
        return match ? Number(match[1]) : fallback;
    }

    function parseMeminfo(text) {
        const total = readKb(text, "MemTotal", 1);
        const available = readKb(text, "MemAvailable", readKb(text, "MemFree", 0));
        const swapTotal = readKb(text, "SwapTotal", 0);
        const swapFree = readKb(text, "SwapFree", 0);

        memoryTotalKb = total;
        memoryAvailableKb = available;
        swapTotalKb = swapTotal;
        swapFreeKb = swapFree;
    }

    function parseCpuStat(text) {
        const line = text.match(/^cpu\s+(.+)$/m)?.[1];
        if (!line)
            return null;

        const values = line.trim().split(/\s+/).map(Number);
        const idle = (values[3] ?? 0) + (values[4] ?? 0);
        const total = values.reduce((sum, value) => sum + (Number.isFinite(value) ? value : 0), 0);
        return { idle, total };
    }

    function calculateCpuUsage(previous, current) {
        if (!previous || !current)
            return 0;

        const totalDiff = current.total - previous.total;
        const idleDiff = current.idle - previous.idle;
        return totalDiff > 0 ? clamp01(1 - idleDiff / totalDiff) : 0;
    }

    function pushHistory(history, value) {
        const next = [...history, clamp01(value)];
        if (next.length > historyLimit)
            next.shift();
        return next;
    }

    function refresh() {
        fileMeminfo.reload();
        fileStat.reload();

        parseMeminfo(fileMeminfo.text());

        const currentCpuStats = parseCpuStat(fileStat.text());
        cpuUsage = calculateCpuUsage(previousCpuStats, currentCpuStats);
        previousCpuStats = currentCpuStats;

        memoryHistory = pushHistory(memoryHistory, memoryUsage);
        swapHistory = pushHistory(swapHistory, swapUsage);
        cpuHistory = pushHistory(cpuHistory, cpuUsage);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: root.updateInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    FileView {
        id: fileStat
        path: "/proc/stat"
        blockLoading: true
    }
}
