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
    readonly property bool canPlay: activePlayer?.canPlay ?? false
    readonly property bool canPause: activePlayer?.canPause ?? false
    readonly property bool canPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canToggle: activePlayer !== null && ((activePlayer?.canTogglePlaying ?? false) || (playing ? canPause : canPlay))
    readonly property bool canNext: activePlayer?.canGoNext ?? false

    function cleanTitle(value) {
        return String(value ?? "")
            .replace(/\s*-\s*(YouTube|Spotify|VLC media player)$/i, "")
            .trim();
    }

    function previous() {
        if (activePlayer !== null && canPrevious)
            activePlayer.previous();
    }

    function toggle() {
        if (activePlayer === null)
            return;

        if (playing && canPause) {
            activePlayer.pause();
            return;
        }

        if (!playing && canPlay) {
            activePlayer.play();
            return;
        }

        if (activePlayer.canTogglePlaying)
            activePlayer.togglePlaying();
    }

    function next() {
        if (activePlayer !== null && canNext)
            activePlayer.next();
    }
}
