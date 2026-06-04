export function parseGammarelayOutputsXml(xml) {
  return [...String(xml ?? "").matchAll(/<node name="([^"]+)"\/>/g)]
    .map((match) => match[1])
    .filter(Boolean);
}

export function parseBusctlUint(text) {
  const match = String(text ?? "").trim().match(/^[qtnui]\s+(-?\d+)/);
  return match ? Number(match[1]) : null;
}

export function clampTemperature(value, min = 2500, max = 6500) {
  return Math.round(Math.max(min, Math.min(max, Number(value) || max)));
}

export function outputPath(outputName) {
  return `/outputs/${String(outputName ?? "").replaceAll("-", "_")}`;
}

export function gammarelayTreeCommand() {
  return ["busctl", "--user", "introspect", "--xml-interface", "rs.wl-gammarelay", "/outputs"];
}

export function gammarelayGetTemperatureCommand(outputName) {
  return [
    "busctl",
    "--user",
    "get-property",
    "rs.wl-gammarelay",
    outputPath(outputName),
    "rs.wl.gammarelay",
    "Temperature",
  ];
}

export function gammarelaySetTemperatureCommand(outputName, temperature) {
  return [
    "busctl",
    "--user",
    "set-property",
    "rs.wl-gammarelay",
    outputPath(outputName),
    "rs.wl.gammarelay",
    "Temperature",
    "q",
    String(clampTemperature(temperature)),
  ];
}
