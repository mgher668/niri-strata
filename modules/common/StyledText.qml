import QtQuick
import "."

Text {
    id: root

    property bool muted: false
    property bool subtle: false

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    font {
        family: Theme.font.familyText
        pixelSize: Theme.font.md
    }

    color: subtle ? Theme.colors.subtleText : muted ? Theme.colors.mutedText : Theme.colors.text
}
