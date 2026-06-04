export function audioPercent(volume) {
  const numeric = Number(volume ?? 0);
  return `${Math.round(Math.max(0, Math.min(1.5, numeric)) * 100)}%`;
}

export function audioNodeLabel(node) {
  return String(node?.nickname || node?.description || node?.properties?.["application.name"] || node?.name || "Audio")
    .replace(/^alsa_output\./, "")
    .replace(/^alsa_input\./, "")
    .replace(/^bluez_output\./, "")
    .replace(/^bluez_input\./, "")
    .replace(/\./g, " ")
    .trim();
}

export function filterAudioNodes(nodes, { sink, stream }) {
  return nodes.filter((node) => Boolean(node.audio) && Boolean(node.isSink) === sink && Boolean(node.isStream) === stream);
}
