// Pure Node ESM: wallpaper folder scanning and file list parsing.
// No side effects. Testable without Quickshell.

/**
 * Build the scan command for listing wallpaper images in a directory.
 *
 * Non-recursive (uses ls):
 *   ["ls", "-1", dir + "/*.jpg", dir + "/*.png", ...]
 *
 * Recursive (uses find):
 *   ["find", dir, "-type", "f", "(", "-name", "*.jpg", "-o", ..., ")"]
 *
 * Date sort with recursive:
 *   ["find", dir, "-type", "f", "(", ..., ")", "-printf", "%T@ %p\\n"]
 *
 * @param {string} dir - directory to scan
 * @param {boolean} recursive - scan subfolders
 * @param {string} sortBy - "name" or "date"
 * @returns {string[]} argv array for sh -c
 */
const IMAGE_EXTS = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"];

export function buildScanCommand(dir, recursive, sortBy) {
  if (recursive) {
    const nameArgs = IMAGE_EXTS.flatMap(ext => ["-name", ext]);
    // Interleave -o between -name patterns
    const nameWithOr = [];
    for (let i = 0; i < nameArgs.length; i += 2) {
      if (i > 0) nameWithOr.push("-o");
      nameWithOr.push(nameArgs[i], nameArgs[i + 1]);
    }

    if (sortBy === "date") {
      return ["find", dir, "-type", "f", "(", ...nameWithOr, ")", "-printf", "%T@ %p\\n"];
    }
    return ["find", dir, "-type", "f", "(", ...nameWithOr, ")"];
  }

  // Non-recursive: ls with glob patterns
  const globs = IMAGE_EXTS.map(ext => `${dir}/${ext}`);
  return ["ls", "-1", ...globs];
}

/**
 * Parse raw file list output into a sorted array of paths.
 *
 * For name sorting: input is newline-separated paths.
 * For date sorting: input is newline-separated "timestamp path" lines
 *   (from find -printf "%T@ %p\n").
 *
 * @param {string} rawText - raw output from ls or find
 * @param {string} sortBy - "name" or "date"
 * @param {string} sortOrder - "ascending" or "descending"
 * @returns {string[]} sorted array of file paths
 */
export function parseFileList(rawText, sortBy, sortOrder) {
  if (!rawText || rawText.trim().length === 0)
    return [];

  const lines = rawText.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);

  if (sortBy === "date") {
    // Each line: "1700000000.0 /path/to/file.jpg"
    const entries = lines.map(line => {
      const spaceIdx = line.indexOf(" ");
      if (spaceIdx < 0) return { ts: 0, path: line };
      return { ts: parseFloat(line.slice(0, spaceIdx)) || 0, path: line.slice(spaceIdx + 1) };
    });

    entries.sort((a, b) => a.ts - b.ts);
    if (sortOrder === "descending")
      entries.reverse();

    return entries.map(e => e.path);
  }

  // Name sort
  const paths = [...lines];
  paths.sort((a, b) => {
    const nameA = a.split("/").pop().toLowerCase();
    const nameB = b.split("/").pop().toLowerCase();
    return nameA.localeCompare(nameB);
  });

  if (sortOrder === "descending")
    paths.reverse();

  return paths;
}