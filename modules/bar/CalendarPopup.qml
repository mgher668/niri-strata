import QtQuick
import QtQuick.Layouts
import "../common/"

Item {
    id: root

    required property var service

    implicitWidth: 268
    implicitHeight: popupColumn.implicitHeight

    readonly property date currentDate: service.date
    readonly property int currentYear: currentDate.getFullYear()
    readonly property int currentMonth: currentDate.getMonth()
    readonly property var weekdays: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var days: buildMonthDays(currentYear, currentMonth)

    function sameDay(left, right) {
        return left.getFullYear() === right.getFullYear()
            && left.getMonth() === right.getMonth()
            && left.getDate() === right.getDate();
    }

    function buildMonthDays(year, month) {
        const first = new Date(year, month, 1);
        const mondayOffset = (first.getDay() + 6) % 7;
        const start = new Date(year, month, 1 - mondayOffset);
        const result = [];

        for (let i = 0; i < 42; ++i) {
            const date = new Date(start);
            date.setDate(start.getDate() + i);
            result.push({
                day: date.getDate(),
                inMonth: date.getMonth() === month,
                today: sameDay(date, currentDate),
            });
        }

        return result;
    }

    ColumnLayout {
        id: popupColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Theme.spacing.lg

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.service.timeText
                color: Theme.colors.text
                font.family: Theme.font.familyMono
                font.pixelSize: Theme.font.xl
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                Layout.fillWidth: true
                text: root.service.fullDateText
                color: Theme.colors.mutedText
                font.pixelSize: Theme.font.sm
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.outline
            opacity: 0.7
        }

        StyledText {
            Layout.fillWidth: true
            text: Qt.formatDate(root.currentDate, "MMMM yyyy")
            color: Theme.colors.text
            font.pixelSize: Theme.font.md
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: Theme.spacing.xs
            columnSpacing: Theme.spacing.xs

            Repeater {
                model: root.weekdays

                StyledText {
                    required property string modelData

                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 18
                    text: modelData
                    color: Theme.colors.subtleText
                    font.pixelSize: Theme.font.xs
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Repeater {
                model: root.days

                Rectangle {
                    required property var modelData

                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 28
                    radius: Theme.rounding.sm
                    color: modelData.today ? Theme.colors.primary : Theme.colors.transparent
                    opacity: modelData.inMonth ? 1 : 0.42

                    StyledText {
                        anchors.centerIn: parent
                        text: String(modelData.day)
                        color: modelData.today ? Theme.colors.primaryText
                            : modelData.inMonth ? Theme.colors.text : Theme.colors.subtleText
                        font.pixelSize: Theme.font.sm
                        font.family: Theme.font.familyMono
                    }
                }
            }
        }
    }
}
