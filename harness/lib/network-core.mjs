export function splitNmcliTerseLine(line) {
  const fields = [];
  let current = "";
  let escaped = false;

  for (const char of String(line ?? "")) {
    if (escaped) {
      current += char;
      escaped = false;
    } else if (char === "\\") {
      escaped = true;
    } else if (char === ":") {
      fields.push(current);
      current = "";
    } else {
      current += char;
    }
  }

  fields.push(current);
  return fields;
}

export function isVpnConnectionType(type) {
  return ["vpn", "wireguard", "tun"].includes(String(type ?? "").toLowerCase());
}

export function parseVpnConnections(allText, activeText = "") {
  const activeNames = new Set(
    String(activeText ?? "")
      .trim()
      .split("\n")
      .filter(Boolean)
      .map((line) => splitNmcliTerseLine(line))
      .filter(([, type]) => isVpnConnectionType(type))
      .map(([name]) => name),
  );

  return String(allText ?? "")
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => splitNmcliTerseLine(line))
    .filter(([, type]) => isVpnConnectionType(type))
    .map(([name, type]) => ({
      name,
      type,
      active: activeNames.has(name),
    }));
}

export function vpnActionCommand(profile) {
  return ["nmcli", "connection", profile.active ? "down" : "up", profile.name];
}
