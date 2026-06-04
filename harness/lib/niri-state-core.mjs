export function readField(object, snakeName, camelName, fallback = null) {
  if (!object || typeof object !== "object") {
    return fallback;
  }

  if (Object.hasOwn(object, camelName)) {
    return object[camelName];
  }

  if (Object.hasOwn(object, snakeName)) {
    return object[snakeName];
  }

  return fallback;
}

export function normalizeWorkspace(raw) {
  return {
    id: raw?.id ?? null,
    idx: raw?.idx ?? null,
    name: raw?.name ?? null,
    output: raw?.output ?? null,
    isActive: Boolean(readField(raw, "is_active", "isActive", false)),
    isFocused: Boolean(readField(raw, "is_focused", "isFocused", false)),
    isUrgent: Boolean(readField(raw, "is_urgent", "isUrgent", false)),
    activeWindowId: readField(raw, "active_window_id", "activeWindowId", null),
  };
}

export function normalizeWindow(raw) {
  return {
    id: raw?.id ?? null,
    title: raw?.title ?? "",
    appId: readField(raw, "app_id", "appId", ""),
    workspaceId: readField(raw, "workspace_id", "workspaceId", null),
    isFocused: Boolean(readField(raw, "is_focused", "isFocused", false)),
    isFloating: Boolean(readField(raw, "is_floating", "isFloating", false)),
    isUrgent: Boolean(readField(raw, "is_urgent", "isUrgent", false)),
  };
}

export function normalizeFocusedWindow(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  return normalizeWindow(raw);
}

export function normalizeFocusedOutput(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  return {
    name: raw.name ?? null,
    make: raw.make ?? "",
    model: raw.model ?? "",
    serial: raw.serial ?? "",
    logical: raw.logical ?? null,
  };
}

export function workspaceLabel(workspace) {
  if (workspace.name && String(workspace.name).trim().length > 0) {
    return workspace.name;
  }

  if (workspace.idx !== null && workspace.idx !== undefined) {
    return String(workspace.idx);
  }

  return "";
}

export function compareWorkspaces(a, b, outputOrder = []) {
  const aOutput = a.output ?? "";
  const bOutput = b.output ?? "";
  const aOutputIndex = outputOrder.includes(aOutput) ? outputOrder.indexOf(aOutput) : Number.MAX_SAFE_INTEGER;
  const bOutputIndex = outputOrder.includes(bOutput) ? outputOrder.indexOf(bOutput) : Number.MAX_SAFE_INTEGER;

  if (aOutputIndex !== bOutputIndex) {
    return aOutputIndex - bOutputIndex;
  }

  if (aOutput !== bOutput) {
    return aOutput.localeCompare(bOutput);
  }

  if (a.idx !== b.idx) {
    return (a.idx ?? Number.MAX_SAFE_INTEGER) - (b.idx ?? Number.MAX_SAFE_INTEGER);
  }

  return (a.id ?? Number.MAX_SAFE_INTEGER) - (b.id ?? Number.MAX_SAFE_INTEGER);
}

export function sortWorkspaces(workspaces, outputOrder = []) {
  return [...workspaces].sort((a, b) => compareWorkspaces(a, b, outputOrder));
}

export function groupWorkspacesByOutput(workspaces, outputOrder = []) {
  const sorted = sortWorkspaces(workspaces, outputOrder);
  const groups = [];

  for (const workspace of sorted) {
    const output = workspace.output ?? "";
    const current = groups[groups.length - 1];

    if (!current || current.output !== output) {
      groups.push({
        output,
        workspaces: [workspace],
      });
    } else {
      current.workspaces.push(workspace);
    }
  }

  return groups;
}

export function windowsForWorkspace(workspace, windows) {
  return windows.filter((window) => window.workspaceId === workspace.id);
}

export function isWorkspaceOccupied(workspace, windows) {
  return workspace.activeWindowId !== null && workspace.activeWindowId !== undefined
    ? true
    : windowsForWorkspace(workspace, windows).length > 0;
}

export function normalizeState(rawState) {
  const workspaces = (rawState.workspaces ?? []).map(normalizeWorkspace);
  const windows = (rawState.windows ?? []).map(normalizeWindow);
  const sortedWorkspaces = sortWorkspaces(workspaces, rawState.outputOrder ?? []);
  const focusedWindow = normalizeFocusedWindow(rawState.focusedWindow ?? windows.find((window) => window.isFocused) ?? null);
  const focusedWorkspaceForOutput = focusedWindow
    ? sortedWorkspaces.find((workspace) => workspace.id === focusedWindow.workspaceId)
    : sortedWorkspaces.find((workspace) => workspace.isFocused);
  const focusedOutput = normalizeFocusedOutput(
    rawState.focusedOutput
      ?? rawState.focused_output
      ?? (focusedWorkspaceForOutput ? { name: focusedWorkspaceForOutput.output } : null)
      ?? null,
  );

  return {
    workspaces: sortedWorkspaces.map((workspace) => ({
      ...workspace,
      label: workspaceLabel(workspace),
      occupied: isWorkspaceOccupied(workspace, windows),
      windows: windowsForWorkspace(workspace, windows),
    })),
    windows,
    focusedWindow,
    focusedOutput,
    activeWorkspace: sortedWorkspaces.find((workspace) => workspace.isActive) ?? null,
    focusedWorkspace: sortedWorkspaces.find((workspace) => workspace.isFocused) ?? null,
    groups: groupWorkspacesByOutput(sortedWorkspaces, rawState.outputOrder ?? []),
  };
}

export function focusWorkspaceFallbackCommand(workspace) {
  const reference = workspace.name && String(workspace.name).trim().length > 0
    ? workspace.name
    : String(workspace.idx);

  return ["niri", "msg", "action", "focus-workspace", reference];
}

export function focusWindowCommand(windowOrId) {
  const id = typeof windowOrId === "object" ? windowOrId.id : windowOrId;
  return ["niri", "msg", "action", "focus-window", "--id", String(id)];
}

export function focusedOutputCommand() {
  return ["niri", "msg", "--json", "focused-output"];
}
