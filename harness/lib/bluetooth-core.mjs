export function bluetoothDeviceStatus(device) {
  if (!device) {
    return "Unknown";
  }

  if (device.connected) {
    return device.batteryAvailable
      ? `Connected · ${Math.round(device.battery * 100)}%`
      : "Connected";
  }

  if (device.pairing) {
    return "Pairing";
  }

  if (device.state === "Connecting") {
    return "Connecting";
  }

  if (device.state === "Disconnecting") {
    return "Disconnecting";
  }

  if (device.paired || device.bonded) {
    return "Paired";
  }

  if (device.blocked) {
    return "Blocked";
  }

  return "Available";
}

export function sortBluetoothDevices(devices) {
  return [...devices].sort((a, b) => {
    if (a.connected !== b.connected) {
      return a.connected ? -1 : 1;
    }

    const aPaired = Boolean(a.paired || a.bonded);
    const bPaired = Boolean(b.paired || b.bonded);
    if (aPaired !== bPaired) {
      return aPaired ? -1 : 1;
    }

    return String(a.name || a.deviceName || a.address || "").localeCompare(
      String(b.name || b.deviceName || b.address || ""),
    );
  });
}
