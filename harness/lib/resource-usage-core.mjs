export function clamp01(value) {
  if (!Number.isFinite(value)) {
    return 0;
  }

  return Math.max(0, Math.min(1, value));
}

export function parseMeminfo(text) {
  const readKb = (key, fallback = 0) => {
    const match = text.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"));
    return match ? Number(match[1]) : fallback;
  };

  const memoryTotalKb = readKb("MemTotal", 1);
  const memoryAvailableKb = readKb("MemAvailable", readKb("MemFree", 0));
  const swapTotalKb = readKb("SwapTotal", 0);
  const swapFreeKb = readKb("SwapFree", 0);
  const memoryUsedKb = Math.max(0, memoryTotalKb - memoryAvailableKb);
  const swapUsedKb = Math.max(0, swapTotalKb - swapFreeKb);

  return {
    memoryTotalKb,
    memoryAvailableKb,
    memoryUsedKb,
    memoryUsedRatio: clamp01(memoryUsedKb / memoryTotalKb),
    swapTotalKb,
    swapFreeKb,
    swapUsedKb,
    swapUsedRatio: swapTotalKb > 0 ? clamp01(swapUsedKb / swapTotalKb) : 0,
  };
}

export function parseCpuStat(text) {
  const line = text.match(/^cpu\s+(.+)$/m)?.[1];

  if (!line) {
    return null;
  }

  const values = line.trim().split(/\s+/).map(Number);
  const idle = (values[3] ?? 0) + (values[4] ?? 0);
  const total = values.reduce((sum, value) => sum + (Number.isFinite(value) ? value : 0), 0);

  return { idle, total };
}

export function calculateCpuUsage(previous, current) {
  if (!previous || !current) {
    return 0;
  }

  const totalDiff = current.total - previous.total;
  const idleDiff = current.idle - previous.idle;

  return totalDiff > 0 ? clamp01(1 - idleDiff / totalDiff) : 0;
}

export function percentText(ratio) {
  return `${Math.round(clamp01(ratio) * 100)}%`;
}
