import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var activePlayer: players.find(player => player.isPlaying) ?? players[0] ?? null
    readonly property bool available: activePlayer !== null
    readonly property string playerName: activePlayer?.identity || activePlayer?.desktopEntry || "Media"
    readonly property string title: cleanTitle(activePlayer?.trackTitle) || "No media"
    readonly property string artist: activePlayer?.trackArtist || activePlayer?.trackAlbum || ""
    readonly property string artUrl: activePlayer?.trackArtUrl || ""
    readonly property bool playing: activePlayer?.isPlaying ?? false
    readonly property bool canPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canToggle: activePlayer?.canTogglePlaying ?? false
    readonly property bool canNext: activePlayer?.canGoNext ?? false

    function cleanTitle(value) {
        return String(value ?? "")
            .replace(/\s*-\s*(YouTube|Spotify|VLC media player)$/i, "")
            .trim();
    }

    function previous() {
        if (canPrevious)
            activePlayer.previous();
    }

    function toggle() {
        if (canToggle)
            activePlayer.togglePlaying();
    }

    function next() {
        if (canNext)
            activePlayer.next();
    }
}
