import QtQuick
import Quickshell

SystemClock {
    id: root

    precision: SystemClock.Seconds

    readonly property string timeText: Qt.formatDateTime(root.date, "hh:mm:ss")
    readonly property string dateText: Qt.formatDateTime(root.date, "ddd, MMM d")
    readonly property string fullDateText: Qt.formatDateTime(root.date, "dddd, MMMM d, yyyy")
    readonly property string fullText: Qt.formatDateTime(root.date, "dddd, MMMM d, yyyy hh:mm:ss")
}
