export function parsePowerProfilesList(text) {
  return String(text ?? "")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.endsWith(":"))
    .map((line) => ({
      name: line.replace(/^\*\s*/, "").replace(/:$/, ""),
      active: line.startsWith("*"),
    }));
}

export function setPowerProfileCommand(profile) {
  return ["powerprofilesctl", "set", profile];
}
