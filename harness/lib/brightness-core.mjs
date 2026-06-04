export function parseDdcutilDetect(text) {
  const displays = [];
  let current = null;

  for (const rawLine of String(text ?? "").split("\n")) {
    const line = rawLine.trim();
    if (line.length === 0)
      continue;

    const displayMatch = line.match(/^Display\s+(\d+)/);
    if (displayMatch) {
      current = {
        id: Number(displayMatch[1]),
        bus: null,
        connector: "",
        manufacturer: "",
        model: "",
        serial: "",
        label: `Display ${displayMatch[1]}`,
        controllable: true,
        errorText: "",
      };
      displays.push(current);
      continue;
    }

    if (line === "Invalid display") {
      current = {
        id: displays.length + 1,
        bus: null,
        connector: "",
        manufacturer: "",
        model: "",
        serial: "",
        label: `Display ${displays.length + 1}`,
        controllable: false,
        errorText: "DDC communication failed",
      };
      displays.push(current);
      continue;
    }

    if (!current)
      continue;

    const busMatch = line.match(/^I2C bus:\s+\/dev\/i2c-(\d+)/);
    if (busMatch) {
      current.bus = Number(busMatch[1]);
      continue;
    }

    const connectorMatch = line.match(/^DRM_connector:\s+(.+)$/);
    if (connectorMatch) {
      current.connector = connectorMatch[1].trim();
      continue;
    }

    const briefConnectorMatch = line.match(/^DRM connector:\s+(.+)$/);
    if (briefConnectorMatch) {
      current.connector = briefConnectorMatch[1].trim();
      continue;
    }

    const manufacturerMatch = line.match(/^Mfg id:\s+(.+)$/);
    if (manufacturerMatch) {
      current.manufacturer = manufacturerMatch[1].trim();
      continue;
    }

    const modelMatch = line.match(/^Model:\s+(.+)$/);
    if (modelMatch) {
      current.model = modelMatch[1].trim();
      current.label = current.model;
      continue;
    }

    const serialMatch = line.match(/^Serial number:\s+(.+)$/);
    if (serialMatch) {
      current.serial = serialMatch[1].trim();
      continue;
    }

    if (/DDC communication failed/i.test(line))
      current.errorText = "DDC communication failed";
  }

  return displays.filter((display) => Number.isInteger(display.bus));
}

export function parseDdcutilBrightness(text) {
  const match = String(text ?? "").match(/current value\s*=\s*(\d+),\s*max value\s*=\s*(\d+)/i);
  if (!match)
    return null;

  const current = Number(match[1]);
  const max = Number(match[2]);
  if (!Number.isFinite(current) || !Number.isFinite(max) || max <= 0)
    return null;

  return {
    current,
    max,
    percent: Math.round(Math.max(0, Math.min(1, current / max)) * 100),
  };
}

export function ddcutilDetectCommand() {
  return ["ddcutil", "detect"];
}

export function ddcutilGetBrightnessCommand(bus) {
  return ["ddcutil", "--bus", String(bus), "getvcp", "10"];
}

export function ddcutilSetBrightnessCommand(bus, value) {
  const percent = Math.round(Math.max(0, Math.min(100, Number(value) || 0)));
  return ["ddcutil", "--bus", String(bus), "setvcp", "10", String(percent)];
}
