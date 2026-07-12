// Pure Node ESM: wallpaper backend command construction.
// No side effects. Testable without Quickshell.

/**
 * Build swww img command argv.
 * @param {string} path - wallpaper file path
 * @param {string} output - output name (empty = all outputs)
 * @param {string} fillColor - hex color for uncovered areas (empty = omit)
 * @returns {string[]} argv array
 */
export function buildSwwwCommand(path, output, fillColor) {
  const cmd = ["swww", "img", path, "--transition-type", "fade"];
  if (output && output.length > 0)
    cmd.push("-o", output);
  if (fillColor && fillColor.length > 0)
    cmd.push("--fill-color", fillColor);
  return cmd;
}

/**
 * Build swaybg command argv.
 * @param {string} path - wallpaper file path
 * @param {string} output - output name (empty = all outputs)
 * @param {string} fillMode - fill/fit/center/tile/stretch
 * @param {string} bgColor - hex color for uncovered areas (empty = omit)
 * @returns {string[]} argv array
 */
export function buildSwaybgCommand(path, output, fillMode, bgColor) {
  const cmd = ["swaybg", "-i", path, "-m", fillMode || "fill"];
  if (output && output.length > 0)
    cmd.push("-o", output);
  if (bgColor && bgColor.length > 0)
    cmd.push("-c", bgColor);
  return cmd;
}

/**
 * swww-daemon start command.
 * @returns {string[]}
 */
export function buildSwwwDaemonStart() {
  return ["swww-daemon"];
}

/**
 * Kill previous swaybg instance.
 * @returns {string[]}
 */
export function buildSwaybgKill() {
  return ["pkill", "-x", "swaybg"];
}

/**
 * Return valid fill modes for a given backend.
 * swww only supports fill (always scales to fit).
 * swaybg supports all 5 modes.
 * @param {string} backend - "swww" or "swaybg"
 * @returns {string[]} array of valid fill mode strings
 */
export function validFillModesForBackend(backend) {
  switch (backend) {
    case "swww": return ["fill"];
    case "swaybg": return ["fill", "fit", "center", "tile", "stretch"];
    default: return [];
  }
}

/**
 * Parse conflict probe output (pgrep results).
 * @param {string} rawText - newline-separated process names
 * @returns {string[]} array of detected process names
 */
export function parseConflictProbe(rawText) {
  if (!rawText || rawText.trim().length === 0)
    return [];
  return rawText.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
}