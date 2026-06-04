export function cleanTrackTitle(title) {
  return String(title ?? "")
    .replace(/\s*-\s*(YouTube|Spotify|VLC media player)$/i, "")
    .trim();
}

export function playerLabel(player) {
  return String(player?.identity || player?.desktopEntry || "Media");
}

export function activePlayer(players) {
  return players.find((player) => player.isPlaying) ?? players[0] ?? null;
}
