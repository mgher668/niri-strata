import QtQuick

QtObject {
    id: root

    property bool barIconsVisible: true
    property var outputStats: ({})

    function toggleBarIcons() {
        barIconsVisible = !barIconsVisible;
        return barIconsVisible;
    }

    function showBarIcons() {
        barIconsVisible = true;
        return barIconsVisible;
    }

    function hideBarIcons() {
        barIconsVisible = false;
        return barIconsVisible;
    }

    function updateOutputStats(outputName, totalCount, visibleCount, hiddenCount) {
        const key = outputName || "unknown";
        const next = Object.assign({}, outputStats);
        next[key] = {
            total: totalCount,
            visible: visibleCount,
            hidden: hiddenCount,
        };
        outputStats = next;
    }

    function debugSummary() {
        return JSON.stringify({
            barIconsVisible,
            outputs: outputStats,
        });
    }
}
