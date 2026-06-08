import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

import {
  focusedOutputCommand,
  focusWindowCommand,
  focusWorkspaceFallbackCommand,
  groupWorkspacesByOutput,
  normalizeFocusedOutput,
  normalizeState,
  normalizeWindow,
  normalizeWorkspace,
  sortWorkspaces,
} from "./lib/niri-state-core.mjs";

import {
  audioNodeLabel,
  audioPercent,
  filterAudioNodes,
} from "./lib/audio-core.mjs";

import {
  activePlayer,
  cleanTrackTitle,
  playerLabel,
} from "./lib/media-core.mjs";

import {
  requiresConfirmation,
  sessionActionCommand,
} from "./lib/system-actions-core.mjs";

import {
  parsePowerProfilesList,
  setPowerProfileCommand,
} from "./lib/power-profiles-core.mjs";

import {
  bluetoothDeviceStatus,
  sortBluetoothDevices,
} from "./lib/bluetooth-core.mjs";

import {
  ddcutilDetectCommand,
  ddcutilGetBrightnessCommand,
  ddcutilSetBrightnessCommand,
  parseDdcutilBrightness,
  parseDdcutilDetect,
} from "./lib/brightness-core.mjs";

import {
  clampTemperature,
  gammarelayGetTemperatureCommand,
  gammarelaySetTemperatureCommand,
  gammarelayTreeCommand,
  outputPath,
  parseBusctlUint,
  parseGammarelayOutputsXml,
} from "./lib/night-mode-core.mjs";

import {
  captureToolProbeCommand,
  parseCaptureToolProbe,
  recordingAvailable,
  recordingStartCommand,
  recordingStopCommand,
  regionRecordingAvailable,
  regionRecordingMonitorCommand,
  regionRecordingStartCommand,
  screenshotAvailable,
  screenshotClipboardCommand,
} from "./lib/capture-core.mjs";

import {
  parseVpnConnections,
  splitNmcliTerseLine,
  vpnActionCommand,
} from "./lib/network-core.mjs";

import {
  calculateCpuUsage,
  parseCpuStat,
  parseMeminfo,
  percentText,
} from "./lib/resource-usage-core.mjs";

const root = dirname(fileURLToPath(import.meta.url));

async function readJson(path) {
  return JSON.parse(await readFile(join(root, path), "utf8"));
}

function assertAlmostEqual(actual, expected, epsilon = 1e-12) {
  assert.ok(Math.abs(actual - expected) < epsilon, `${actual} should be within ${epsilon} of ${expected}`);
}

test("normalizes snake_case niri workspace fields to stable camelCase fields", () => {
  const workspace = normalizeWorkspace({
    id: 7,
    idx: 2,
    name: "dev",
    output: "DP-2",
    is_active: true,
    is_focused: false,
    is_urgent: true,
    active_window_id: 42,
  });

  assert.deepEqual(workspace, {
    id: 7,
    idx: 2,
    name: "dev",
    output: "DP-2",
    isActive: true,
    isFocused: false,
    isUrgent: true,
    activeWindowId: 42,
  });
});

test("accepts already-normalized camelCase fields from a future QML-facing adapter", () => {
  const workspace = normalizeWorkspace({
    id: 9,
    idx: 4,
    name: null,
    output: "HDMI-A-1",
    isActive: false,
    isFocused: true,
    isUrgent: false,
    activeWindowId: null,
  });

  const window = normalizeWindow({
    id: 12,
    title: "Terminal",
    appId: "Alacritty",
    workspaceId: 9,
    isFocused: true,
    isFloating: false,
    isUrgent: false,
  });

  assert.equal(workspace.isFocused, true);
  assert.equal(workspace.activeWindowId, null);
  assert.equal(window.appId, "Alacritty");
  assert.equal(window.workspaceId, 9);
});

test("sorts live workspaces by output and idx instead of raw niri order", async () => {
  const workspaces = (await readJson("fixtures/live/workspaces.json")).map(normalizeWorkspace);
  const sorted = sortWorkspaces(workspaces, ["DP-2"]);

  assert.deepEqual(
    sorted.map((workspace) => workspace.id),
    [1, 3, 4, 5],
  );

  assert.deepEqual(
    sorted.map((workspace) => workspace.idx),
    [1, 2, 3, 4],
  );
});

test("groups multi-output workspaces by output order and sorts within each output by idx", () => {
  const workspaces = [
    normalizeWorkspace({ id: 11, idx: 2, output: "HDMI-A-1" }),
    normalizeWorkspace({ id: 3, idx: 3, output: "DP-2" }),
    normalizeWorkspace({ id: 1, idx: 1, output: "DP-2" }),
    normalizeWorkspace({ id: 10, idx: 1, output: "HDMI-A-1" }),
  ];

  const groups = groupWorkspacesByOutput(workspaces, ["DP-2", "HDMI-A-1"]);

  assert.deepEqual(
    groups.map((group) => ({
      output: group.output,
      ids: group.workspaces.map((workspace) => workspace.id),
    })),
    [
      { output: "DP-2", ids: [1, 3] },
      { output: "HDMI-A-1", ids: [10, 11] },
    ],
  );
});

test("calculates occupied state from activeWindowId or windows with matching workspaceId", async () => {
  const workspaces = await readJson("fixtures/live/workspaces.json");
  const windows = await readJson("fixtures/live/windows.json");
  const state = normalizeState({ workspaces, windows, outputOrder: ["DP-2"] });

  const occupiedById = new Map(state.workspaces.map((workspace) => [workspace.id, workspace.occupied]));

  assert.equal(occupiedById.get(1), true);
  assert.equal(occupiedById.get(3), true);
  assert.equal(occupiedById.get(4), true);
  assert.equal(occupiedById.get(5), false);
});

test("marks a workspace occupied when activeWindowId is missing but a window belongs to it", () => {
  const state = normalizeState({
    workspaces: [
      { id: 20, idx: 1, output: "DP-2", active_window_id: null },
    ],
    windows: [
      { id: 99, title: "Detached", app_id: "test-app", workspace_id: 20 },
    ],
    outputOrder: ["DP-2"],
  });

  assert.equal(state.workspaces[0].occupied, true);
});

test("preserves focused window and active workspace from live fixture", async () => {
  const workspaces = await readJson("fixtures/live/workspaces.json");
  const windows = await readJson("fixtures/live/windows.json");
  const focusedWindow = await readJson("fixtures/live/focused-window.json");
  const state = normalizeState({ workspaces, windows, focusedWindow, outputOrder: ["DP-2"] });

  assert.equal(state.focusedWindow.id, 10);
  assert.equal(state.focusedWindow.appId, "demo-editor");
  assert.equal(state.activeWorkspace.id, 4);
  assert.equal(state.focusedWorkspace.id, 4);
});

test("normalizes focused output and derives it from focused workspace when needed", () => {
  assert.deepEqual(
    normalizeFocusedOutput({
      name: "HDMI-A-1",
      make: "PNP(AOC)",
      model: "2476WM",
      serial: "E71G4BA001153",
      logical: { x: 1440, y: 0, width: 1920, height: 1080 },
    }),
    {
      name: "HDMI-A-1",
      make: "PNP(AOC)",
      model: "2476WM",
      serial: "E71G4BA001153",
      logical: { x: 1440, y: 0, width: 1920, height: 1080 },
    },
  );

  const state = normalizeState({
    workspaces: [
      { id: 1, idx: 1, output: "DP-1", is_focused: false },
      { id: 2, idx: 1, output: "HDMI-A-1", is_focused: true },
    ],
    windows: [
      { id: 99, workspace_id: 2, is_focused: true },
    ],
    outputOrder: ["DP-1", "HDMI-A-1"],
  });

  assert.equal(state.focusedOutput.name, "HDMI-A-1");
});

test("generates niri workspace fallback commands using index or name, not unsupported --id", () => {
  assert.deepEqual(
    focusWorkspaceFallbackCommand({ id: 4, idx: 3, name: null }),
    ["niri", "msg", "action", "focus-workspace", "3"],
  );

  assert.deepEqual(
    focusWorkspaceFallbackCommand({ id: 7, idx: 2, name: "chat" }),
    ["niri", "msg", "action", "focus-workspace", "chat"],
  );
});

test("generates niri focus-window fallback command by id", () => {
  assert.deepEqual(
    focusWindowCommand({ id: 10 }),
    ["niri", "msg", "action", "focus-window", "--id", "10"],
  );
});

test("generates focused output probe command for sidebar screen targeting", () => {
  assert.deepEqual(
    focusedOutputCommand(),
    ["niri", "msg", "--json", "focused-output"],
  );
});

test("parses meminfo memory and swap usage ratios", () => {
  const usage = parseMeminfo(`
MemTotal:        8000000 kB
MemFree:         1000000 kB
MemAvailable:   5000000 kB
SwapTotal:       2000000 kB
SwapFree:        1500000 kB
`);

  assert.equal(usage.memoryTotalKb, 8000000);
  assert.equal(usage.memoryUsedKb, 3000000);
  assert.equal(usage.memoryUsedRatio, 0.375);
  assert.equal(usage.swapUsedKb, 500000);
  assert.equal(usage.swapUsedRatio, 0.25);
});

test("calculates cpu usage from two /proc/stat samples including iowait as idle", () => {
  const previous = parseCpuStat("cpu  100 0 50 850 20 0 0 0 0 0\n");
  const current = parseCpuStat("cpu  160 0 90 930 30 0 0 0 0 0\n");

  assert.deepEqual(previous, { idle: 870, total: 1020 });
  assert.deepEqual(current, { idle: 960, total: 1210 });
  assertAlmostEqual(calculateCpuUsage(previous, current), 100 / 190);
});

test("formats usage ratio as a rounded percentage", () => {
  assert.equal(percentText(0), "0%");
  assert.equal(percentText(0.426), "43%");
  assert.equal(percentText(1.5), "100%");
});

test("formats and filters PipeWire audio node data", () => {
  const nodes = [
    { name: "alsa_output.pci.stereo", isSink: true, isStream: false, audio: {} },
    { name: "app.output", isSink: true, isStream: true, audio: {} },
    { name: "alsa_input.pci.mic", isSink: false, isStream: false, audio: {} },
    { name: "metadata", isSink: false, isStream: false, audio: null },
  ];

  assert.equal(audioPercent(0.426), "43%");
  assert.equal(audioNodeLabel(nodes[0]), "pci stereo");
  assert.deepEqual(filterAudioNodes(nodes, { sink: true, stream: false }).map((node) => node.name), ["alsa_output.pci.stereo"]);
  assert.deepEqual(filterAudioNodes(nodes, { sink: false, stream: false }).map((node) => node.name), ["alsa_input.pci.mic"]);
});

test("normalizes MPRIS player labels and active player", () => {
  const players = [
    { identity: "VLC", isPlaying: false },
    { desktopEntry: "spotify", isPlaying: true },
  ];

  assert.equal(cleanTrackTitle("Song - YouTube"), "Song");
  assert.equal(playerLabel(players[0]), "VLC");
  assert.equal(activePlayer(players), players[1]);
});

test("protects session-ending commands behind confirmation metadata", () => {
  assert.equal(requiresConfirmation("lock"), false);
  assert.equal(requiresConfirmation("logout"), true);
  assert.equal(requiresConfirmation("shutdown"), true);
  assert.deepEqual(sessionActionCommand("lock"), ["swaylock", "--screenshots", "--clock", "--indicator"]);
  assert.deepEqual(sessionActionCommand("logout"), ["niri", "msg", "action", "quit"]);
  assert.deepEqual(sessionActionCommand("shutdown"), ["systemctl", "poweroff"]);
});

test("parses power profile list and set command", () => {
  assert.deepEqual(
    parsePowerProfilesList("  performance:\n* balanced:\n  power-saver:\n"),
    [
      { name: "performance", active: false },
      { name: "balanced", active: true },
      { name: "power-saver", active: false },
    ],
  );
  assert.deepEqual(setPowerProfileCommand("balanced"), ["powerprofilesctl", "set", "balanced"]);
});

test("parses nmcli terse fields with escaped colons", () => {
  assert.deepEqual(splitNmcliTerseLine("Office\\: VPN:vpn"), ["Office: VPN", "vpn"]);
  assert.deepEqual(splitNmcliTerseLine("Meta:tun"), ["Meta", "tun"]);
});

test("parses VPN profiles and active state from nmcli output", () => {
  assert.deepEqual(
    parseVpnConnections(
      "Home Wi-Fi:802-11-wireless\nMeta:tun\nOffice\\: VPN:vpn\nWire:wireguard\nLAN:802-3-ethernet\n",
      "Meta:tun\nLAN:802-3-ethernet\n",
    ),
    [
      { name: "Meta", type: "tun", active: true },
      { name: "Office: VPN", type: "vpn", active: false },
      { name: "Wire", type: "wireguard", active: false },
    ],
  );
});

test("generates VPN up/down commands without shell string construction", () => {
  assert.deepEqual(vpnActionCommand({ name: "Meta", active: false }), ["nmcli", "connection", "up", "Meta"]);
  assert.deepEqual(vpnActionCommand({ name: "Meta", active: true }), ["nmcli", "connection", "down", "Meta"]);
});

test("formats and sorts Bluetooth devices by connected and paired state", () => {
  const devices = [
    { name: "Speaker", connected: false, paired: true, bonded: false },
    { name: "Keyboard", connected: true, paired: true, bonded: true, batteryAvailable: true, battery: 0.82 },
    { name: "Phone", connected: false, paired: false, bonded: false },
  ];

  assert.equal(bluetoothDeviceStatus(devices[1]), "Connected · 82%");
  assert.equal(bluetoothDeviceStatus({ ...devices[0], pairing: true }), "Pairing");
  assert.deepEqual(sortBluetoothDevices(devices).map((device) => device.name), ["Keyboard", "Speaker", "Phone"]);
});

test("parses ddcutil displays and brightness for external monitors", () => {
  const detect = `Display 1
   I2C bus:  /dev/i2c-7
   DRM_connector:           card1-DP-2
   EDID synopsis:
      Mfg id:               DEL - Dell Inc.
      Model:                DELL SP2418H
      Serial number:        4H94J7510WNL

Display 2
   I2C bus:  /dev/i2c-12
   DRM_connector:           card1-HDMI-A-1
   EDID synopsis:
      Mfg id:               ACR - Acer
      Model:                XB271HU
      Serial number:        T6TEE0018520

Invalid display
   I2C bus:  /dev/i2c-9
   DRM_connector:           card1-DP-1
   EDID synopsis:
      Mfg id:               ACR - Acer Technologies
      Model:                Acer V193WV
      Serial number:        LRD080044221
   DDC communication failed`;

  assert.deepEqual(parseDdcutilDetect(detect), [
    {
      id: 1,
      bus: 7,
      connector: "card1-DP-2",
      manufacturer: "DEL - Dell Inc.",
      model: "DELL SP2418H",
      serial: "4H94J7510WNL",
      label: "DELL SP2418H",
      controllable: true,
      errorText: "",
    },
    {
      id: 2,
      bus: 12,
      connector: "card1-HDMI-A-1",
      manufacturer: "ACR - Acer",
      model: "XB271HU",
      serial: "T6TEE0018520",
      label: "XB271HU",
      controllable: true,
      errorText: "",
    },
    {
      id: 3,
      bus: 9,
      connector: "card1-DP-1",
      manufacturer: "ACR - Acer Technologies",
      model: "Acer V193WV",
      serial: "LRD080044221",
      label: "Acer V193WV",
      controllable: false,
      errorText: "DDC communication failed",
    },
  ]);

  assert.deepEqual(parseDdcutilBrightness(
    "VCP code 0x10 (Brightness                    ): current value =    20, max value =   100",
  ), {
    current: 20,
    max: 100,
    percent: 20,
  });
  assert.equal(parseDdcutilBrightness("No monitor detected"), null);
});

test("generates ddcutil brightness commands with explicit bus selection", () => {
  assert.deepEqual(ddcutilDetectCommand(), ["ddcutil", "detect"]);
  assert.deepEqual(ddcutilGetBrightnessCommand(7), ["ddcutil", "--bus", "7", "getvcp", "10"]);
  assert.deepEqual(ddcutilSetBrightnessCommand(7, 42), ["ddcutil", "--bus", "7", "setvcp", "10", "42"]);
  assert.deepEqual(ddcutilSetBrightnessCommand(7, 180), ["ddcutil", "--bus", "7", "setvcp", "10", "100"]);
  assert.deepEqual(ddcutilSetBrightnessCommand(7, -10), ["ddcutil", "--bus", "7", "setvcp", "10", "0"]);
});

test("parses wl-gammarelay-rs outputs and temperature values", () => {
  const xml = '<node><interface name="org.freedesktop.DBus.Properties"></interface><node name="DP_2"/><node name="HDMI_A_1"/></node>';

  assert.deepEqual(parseGammarelayOutputsXml(xml), ["DP_2", "HDMI_A_1"]);
  assert.equal(parseBusctlUint("q 6500"), 6500);
  assert.equal(parseBusctlUint("n -250"), -250);
  assert.equal(parseBusctlUint("d 1"), null);
  assert.equal(clampTemperature(1800), 2500);
  assert.equal(clampTemperature(4200), 4200);
  assert.equal(clampTemperature(9000), 6500);
});

test("generates wl-gammarelay-rs busctl commands for per-output temperature", () => {
  assert.equal(outputPath("DP-2"), "/outputs/DP_2");
  assert.deepEqual(gammarelayTreeCommand(), [
    "busctl", "--user", "introspect", "--xml-interface", "rs.wl-gammarelay", "/outputs",
  ]);
  assert.deepEqual(gammarelayGetTemperatureCommand("DP-2"), [
    "busctl", "--user", "get-property", "rs.wl-gammarelay", "/outputs/DP_2", "rs.wl.gammarelay", "Temperature",
  ]);
  assert.deepEqual(gammarelaySetTemperatureCommand("DP-2", 3400), [
    "busctl", "--user", "set-property", "rs.wl-gammarelay", "/outputs/DP_2", "rs.wl.gammarelay", "Temperature", "q", "3400",
  ]);
});

test("generates capture commands for screenshot clipboard and region recording", () => {
  const tools = parseCaptureToolProbe("grim=1\nniri=1\nslurp=1\nwl-copy=1\nwf-recorder=0\n");

  assert.deepEqual(tools, {
    grim: true,
    niri: true,
    slurp: true,
    wlCopy: true,
    wfRecorder: false,
  });
  assert.equal(screenshotAvailable(tools), true);
  assert.equal(recordingAvailable(tools), false);
  assert.equal(recordingAvailable({ ...tools, wfRecorder: true }), true);
  assert.equal(regionRecordingAvailable(tools), false);
  assert.equal(regionRecordingAvailable({ ...tools, wfRecorder: true }), true);
  assert.deepEqual(captureToolProbeCommand(), [
    "sh",
    "-c",
    "for tool in grim niri slurp wl-copy wf-recorder; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool=1\" || echo \"$tool=0\"; done",
  ]);
  assert.match(recordingStopCommand().join("\n"), /pkill -INT wf-recorder/);
  assert.match(recordingStopCommand().join("\n"), /pkill -TERM slurp/);
  assert.match(screenshotClipboardCommand().join("\n"), /niri msg action screenshot --path "\$file"/);
  assert.match(screenshotClipboardCommand().join("\n"), /wl-copy --type image\/png < "\$file"/);
  assert.match(screenshotClipboardCommand().join("\n"), /\) >\/dev\/null 2>&1 <\/dev\/null &/);
  assert.match(recordingStartCommand().join("\n"), /niri msg --json focused-output/);
  assert.match(recordingStartCommand().join("\n"), /wf-recorder -o "\$output" -f "\$file"/);
  assert.match(regionRecordingStartCommand().join("\n"), /geometry="\$\(slurp\)"/);
  assert.match(regionRecordingStartCommand().join("\n"), /exec wf-recorder -g "\$geometry" -f "\$file"/);
  assert.match(regionRecordingMonitorCommand().join("\n"), /pgrep -x slurp/);
  assert.match(regionRecordingMonitorCommand().join("\n"), /pgrep -x wf-recorder/);
});

test("uses PopupWindow anchors for bar popups instead of hand-positioned panel windows", async () => {
  const panelPopup = await readFile(join(root, "../modules/bar/PanelPopup.qml"), "utf8");
  const anchorBlock = panelPopup.match(/anchor\s*\{(?<body>[\s\S]*?)\n\s*\}/)?.groups?.body ?? "";

  assert.match(panelPopup, /component:\s*PopupWindow/);
  assert.match(panelPopup, /readonly property bool targetReady/);
  assert.match(panelPopup, /property int panelGap:\s*Theme\.spacing\.lg/);
  assert.match(panelPopup, /property int edgeGap:\s*Config\.bar\.sideMargin/);
  assert.match(anchorBlock, /window:\s*root\.target\.QsWindow\.window/);
  assert.match(anchorBlock, /item:\s*root\.target/);
  assert.match(anchorBlock, /adjustment:\s*PopupAdjustment\.SlideX \| PopupAdjustment\.ResizeY/);
  assert.match(anchorBlock, /edges:\s*Config\.bar\.position === "bottom" \? Edges\.Top : Edges\.Bottom/);
  assert.match(anchorBlock, /gravity:\s*Config\.bar\.position === "bottom" \? Edges\.Top : Edges\.Bottom/);
  assert.match(panelPopup, /implicitWidth:\s*popupBackground\.implicitWidth \+ root\.edgeGap \* 2/);
  assert.match(panelPopup, /implicitHeight:\s*popupBackground\.implicitHeight \+ root\.panelGap/);
  assert.match(panelPopup, /x:\s*root\.edgeGap/);
  assert.match(panelPopup, /y:\s*Config\.bar\.position === "bottom" \? 0 : root\.panelGap/);
  assert.doesNotMatch(anchorBlock, /margins\s*\{/);
  assert.doesNotMatch(panelPopup, /component:\s*PanelWindow/);
  assert.doesNotMatch(panelPopup, /WlrLayershell/);
  assert.doesNotMatch(panelPopup, /function clampedX/);
});

test("filters workspace buttons by the bar screen output name", async () => {
  const bar = await readFile(join(root, "../modules/bar/Bar.qml"), "utf8");
  const workspaces = await readFile(join(root, "../modules/bar/Workspaces.qml"), "utf8");
  const workspaceBlock = bar.match(/Workspaces\s*\{(?<body>[\s\S]*?)\n\s*\}/)?.groups?.body ?? "";

  assert.match(workspaceBlock, /outputName:\s*bar\.barScreen\.name/);
  assert.match(workspaces, /property string outputName:\s*""/);
  assert.match(workspaces, /state\.workspaces\.filter\(workspace => workspace\.output === outputName\)/);
});

test("keeps empty workspace labels unobstructed", async () => {
  const workspaces = await readFile(join(root, "../modules/bar/Workspaces.qml"), "utf8");

  assert.doesNotMatch(workspaces, /visible:\s*!active && !occupied && !urgent/);
});

test("enables QApplication and keeps tray right-clicks on menu display path", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const sysTray = await readFile(join(root, "../modules/bar/SysTray.qml"), "utf8");
  const overflow = await readFile(join(root, "../modules/bar/SysTrayOverflowPopup.qml"), "utf8");
  const config = await readFile(join(root, "../modules/bar/TrayConfig.qml"), "utf8");
  const trayState = await readFile(join(root, "../modules/bar/TrayState.qml"), "utf8");
  const bar = await readFile(join(root, "../modules/bar/Bar.qml"), "utf8");
  const panelPopup = await readFile(join(root, "../modules/bar/PanelPopup.qml"), "utf8");

  assert.match(shell.split("\n")[0], /\/\/@ pragma UseQApplication/);
  assert.match(config, /readonly property int maxVisibleItems:\s*6/);
  assert.match(config, /readonly property var pinnedItemTokens/);
  assert.match(trayState, /property bool barIconsVisible:\s*true/);
  assert.match(trayState, /property var outputStats:\s*\(\{\}\)/);
  assert.match(trayState, /function toggleBarIcons\(\)/);
  assert.match(trayState, /function showBarIcons\(\)/);
  assert.match(trayState, /function hideBarIcons\(\)/);
  assert.match(trayState, /function updateOutputStats\(outputName, totalCount, visibleCount, hiddenCount\)/);
  assert.match(trayState, /function debugSummary\(\)/);
  assert.match(shell, /TrayState\s*\{[\s\S]*id:\s*trayStateService/);
  assert.match(shell, /IpcHandler\s*\{[\s\S]*target:\s*"tray"[\s\S]*function toggleBarIcons\(\): string \{ return trayStateService\.toggleBarIcons\(\) \? "visible" : "hidden"; \}/);
  assert.match(shell, /function showBarIcons\(\): string \{ trayStateService\.showBarIcons\(\); return "visible"; \}/);
  assert.match(shell, /function hideBarIcons\(\): string \{ trayStateService\.hideBarIcons\(\); return "hidden"; \}/);
  assert.match(shell, /function barIconsVisible\(\): bool \{ return trayStateService\.barIconsVisible; \}/);
  assert.match(shell, /function debug\(\): string \{ return trayStateService\.debugSummary\(\); \}/);
  assert.match(bar, /required property var trayState/);
  assert.match(bar, /SysTray\s*\{[\s\S]*trayState:\s*bar\.trayState/);
  assert.match(bar, /SysTray\s*\{[\s\S]*outputName:\s*bar\.barScreen\.name/);
  assert.match(shell, /trayState:\s*trayStateService/);
  assert.doesNotMatch(shell, /id:\s*trayState\s/);
  assert.doesNotMatch(shell, /trayState:\s*trayState\s/);
  assert.match(sysTray, /property var trayState:\s*null/);
  assert.match(sysTray, /property string outputName:\s*""/);
  assert.match(sysTray, /property bool barIconsVisible:\s*true/);
  assert.match(sysTray, /property var sortedItems:\s*\[\]/);
  assert.match(sysTray, /property var visibleItems:\s*\[\]/);
  assert.match(sysTray, /property var hiddenItems:\s*\[\]/);
  assert.match(sysTray, /Connections\s*\{[\s\S]*target:\s*root\.trayState \|\| null[\s\S]*function onBarIconsVisibleChanged\(\) \{[\s\S]*root\.refreshItems\(\);[\s\S]*\}/);
  assert.match(sysTray, /Component\.onCompleted:\s*refreshItems\(\)/);
  assert.match(sysTray, /onItemsChanged:\s*refreshItems\(\)/);
  assert.match(sysTray, /onTrayStateChanged:\s*refreshItems\(\)/);
  assert.match(sysTray, /onOutputNameChanged:\s*refreshItems\(\)/);
  assert.match(sysTray, /function itemText\(item\)/);
  assert.match(sysTray, /function isPinned\(item\)/);
  assert.match(sysTray, /function sortItems\(sourceItems\)/);
  assert.match(sysTray, /function refreshItems\(\)/);
  assert.match(sysTray, /const showBarIcons = trayState \? trayState\.barIconsVisible : true/);
  assert.match(sysTray, /const visible = showBarIcons \? ordered\.slice\(0, maxVisibleItems\) : \[\]/);
  assert.match(sysTray, /barIconsVisible = showBarIcons/);
  assert.match(sysTray, /hiddenItems = sorted\.filter\(item => !visible\.includes\(item\)\)/);
  assert.match(sysTray, /trayState\.updateOutputStats\(outputName, sortedItems\.length, visibleItems\.length, hiddenItems\.length\)/);
  assert.match(sysTray, /function needsAttention\(item\)/);
  assert.match(sysTray, /function menuAnchor\(button\)[\s\S]*const anchor = button && button\.QsWindow\.window \? button : root;[\s\S]*anchor\.mapToItem/);
  assert.match(sysTray, /if \(!anchor\) \{[\s\S]*Cannot open tray menu without a parent window[\s\S]*return false;[\s\S]*\}/);
  assert.match(sysTray, /tooltipEnabled = false;[\s\S]*Qt\.callLater\(\(\) => \{[\s\S]*item\.display\(anchor\.window, anchor\.x, anchor\.y\)/);
  assert.match(sysTray, /onContainsMouseChanged:[\s\S]*root\.tooltipEnabled = true/);
  assert.match(sysTray, /onClicked: event => \{[\s\S]*root\.tooltipEnabled = false/);
  assert.match(sysTray, /requestMenu:\s*\(item, button\) => root\.showMenu\(item, button\)/);
  assert.doesNotMatch(sysTray, /onItemActivated:\s*root\.overflowOpen = false/);
  assert.doesNotMatch(sysTray, /function showMenu[\s\S]*overflowOpen = false;[\s\S]*return true;/);
  assert.match(sysTray, /PanelPopup\s*\{[\s\S]*open:\s*root\.tooltipEnabled && trayButton\.hovered && trayButton\.tooltipTitle\.length > 0[\s\S]*panelRadius:\s*Theme\.rounding\.xs/);
  assert.match(panelPopup, /property int panelRadius:\s*Theme\.rounding\.lg/);
  assert.match(panelPopup, /radius:\s*root\.panelRadius/);
  assert.match(sysTray, /needsAttention:\s*root\.needsAttention\(modelData\)/);
  assert.match(sysTray, /pinned:\s*root\.isPinned\(modelData\)/);
  assert.match(sysTray, /border\.color:\s*trayButton\.needsAttention \? Theme\.colors\.warningColor : Theme\.colors\.outlineVariant/);
  assert.match(overflow, /property var itemText:/);
  assert.match(overflow, /property var itemDescription:/);
  assert.match(overflow, /property var needsAttention:/);
  assert.match(overflow, /signal tooltipRequested\(var button, string title, string description\)/);
  assert.match(overflow, /signal tooltipDismissed\(var button\)/);
  assert.match(overflow, /implicitHeight:\s*overflowColumn\.implicitHeight/);
  assert.match(overflow, /onContainsMouseChanged:[\s\S]*root\.tooltipRequested\(trayButton, tooltipTitle, tooltipDescription\)[\s\S]*root\.tooltipDismissed\(trayButton\)/);
  assert.match(overflow, /Layout\.preferredWidth:\s*38[\s\S]*Layout\.preferredHeight:\s*38/);
  assert.match(overflow, /property bool attention:\s*root\.needsAttention\(modelData\)/);
  assert.match(sysTray, /property bool overflowTooltipMounted:\s*false/);
  assert.match(sysTray, /property bool overflowTooltipVisible:\s*false/);
  assert.match(sysTray, /function overflowTooltipAnchor\(button\)/);
  assert.match(sysTray, /button\.mapToGlobal\(button\.width \/ 2, button\.height\)/);
  assert.match(sysTray, /root\.mapFromGlobal\(globalPoint\.x, globalPoint\.y\)/);
  assert.match(sysTray, /function showOverflowTooltip\(button, title, description\)/);
  assert.match(sysTray, /function hideOverflowTooltip\(button\)/);
  assert.match(sysTray, /function clearOverflowTooltip\(\)/);
  assert.match(sysTray, /onTooltipRequested:\s*\(button, title, description\) => root\.showOverflowTooltip\(button, title, description\)/);
  assert.match(sysTray, /onTooltipDismissed:\s*button => root\.hideOverflowTooltip\(button\)/);
  assert.match(sysTray, /LazyLoader\s*\{[\s\S]*active:\s*root\.overflowTooltipMounted[\s\S]*component:\s*PopupWindow/);
  assert.match(sysTray, /window:\s*root\.QsWindow\.window/);
  assert.match(sysTray, /rect\.x:\s*Math\.round\(root\.overflowTooltipAnchorX - overflowTooltipWindow\.implicitWidth \/ 2\)/);
  assert.match(sysTray, /rect\.y:\s*Math\.round\(root\.overflowTooltipAnchorY \+ Theme\.spacing\.sm\)/);
  assert.match(sysTray, /color:\s*Theme\.colors\.layer0/);
  assert.match(sysTray, /border\.color:\s*Theme\.colors\.outline/);
  assert.match(sysTray, /opacity:\s*root\.overflowTooltipVisible \? 1 : 0/);
  assert.match(sysTray, /scale:\s*root\.overflowTooltipVisible \? 1 : 0\.96/);
  assert.match(sysTray, /Behavior on opacity[\s\S]*NumberAnimation/);
  assert.doesNotMatch(overflow, /PanelPopup\s*\{/);
  assert.doesNotMatch(overflow, /PopupWindow\s*\{/);
  assert.doesNotMatch(overflow, /LazyLoader\s*\{/);
  assert.doesNotMatch(overflow, /QsWindow\.window/);
  assert.doesNotMatch(overflow, /tooltipReserveHeight/);
  assert.doesNotMatch(overflow, /id:\s*tooltipCard/);
  assert.doesNotMatch(overflow, /text:\s*trayButton\.tooltipTitle/);
  assert.doesNotMatch(overflow, /visible:\s*root\.hoveredTitle\.length > 0/);
  assert.match(sysTray, /console\.info\("Opening tray menu:"/);
  assert.match(sysTray, /console\.info\("Activating tray item:"/);
  assert.doesNotMatch(sysTray, /if \(!trayButton\.requestMenu\(trayButton\.item\)\)\s*root\.secondaryActivateItem/);
  assert.doesNotMatch(sysTray, /if \(!trayButton\.requestMenu\(trayButton\.item\)\)\s*trayButton\.item\.secondaryActivate/);
  assert.doesNotMatch(overflow, /if \(!root\.requestMenu\(modelData, trayButton\)\)\s*modelData\.secondaryActivate/);
});

test("documents sidebar scope with harness-backed implementation gates", async () => {
  const plan = await readFile(join(root, "../SIDEBAR_PLAN.md"), "utf8");

  assert.match(plan, /focused niri output/);
  assert.match(plan, /Notification ownership/);
  assert.match(plan, /Wi-Fi connection: first version should support entering a password/);
  assert.match(plan, /BlueZ/);
  assert.match(plan, /PipeWire and WirePlumber/);
  assert.match(plan, /NetworkManager/);
  assert.match(plan, /Do not log passwords/);
  assert.match(plan, /Do not store passwords in QML properties longer than needed/);
  assert.match(plan, /every phase must add or update harness coverage/i);
  assert.match(plan, /Sidebar is created for focused output only/);
  assert.match(plan, /Sidebar code does not import Hyprland modules/);
  assert.match(plan, /## Phase 0 probe results/);
  assert.match(plan, /HDMI-A-1/);
  assert.match(plan, /tam-work_5G/);
  assert.match(plan, /tun.*Meta/);
  assert.match(plan, /Xiaomi Buds 5/);
  assert.match(plan, /OpenRun Pro 2 by Shokz/);
  assert.match(plan, /PipeWire 1\.6\.5/);
  assert.match(plan, /DDC\/CI-capable Dell SP2418H/);
  assert.match(plan, /`ddcutil getvcp 10` returns current\/max brightness/);
  assert.match(plan, /`wl-gammarelay-rs` is installed/);
  assert.match(plan, /`rs\.wl\.gammarelay` `Temperature` properties/);
  assert.match(plan, /powerprofilesctl get` returned `balanced/);
  assert.match(plan, /`niri` and `wl-copy` are installed/);
  assert.match(plan, /niri's native screenshot UI/);
  assert.match(plan, /copy PNG data to the clipboard/);
  assert.match(plan, /`wf-recorder` can list niri outputs/);
  assert.match(plan, /focused-output recording by default/);
  assert.match(plan, /timestamped recordings under `~\/Videos\/Screen Recordings`/);
  assert.match(plan, /notification ownership requires that external daemons/);
  assert.match(plan, /validated after stopping\/disabling `swaync`/);
  assert.match(plan, /`npm run harness` passed with 45 tests/);

  for (const heading of [
    "Phase 0: data probe and compatibility map",
    "Phase 1: sidebar shell and focused-output targeting",
    "Phase 2: notification ownership and do-not-disturb",
    "Phase 3: quick toggles and low-risk system cards",
    "Phase 4: audio mixer",
    "Phase 5: Wi-Fi and VPN",
    "Phase 6: Bluetooth devices",
    "Phase 7: media, brightness, color temperature, and power",
    "Phase 8: polish, resilience, and rollout",
  ]) {
    assert.match(plan, new RegExp(`## ${heading}`));
  }
});

test("wires sidebar shell through focused-output controller", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const bar = await readFile(join(root, "../modules/bar/Bar.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const controller = await readFile(join(root, "../modules/sidebar/SidebarController.qml"), "utf8");
  const button = await readFile(join(root, "../modules/sidebar/SidebarButton.qml"), "utf8");

  assert.match(shell, /import "\.\/modules\/sidebar\/"/);
  assert.match(shell, /import Quickshell\.Io/);
  assert.match(shell, /SidebarController\s*\{/);
  assert.match(shell, /id:\s*sidebarState/);
  assert.match(shell, /niriState:\s*niriState/);
  assert.match(shell, /IpcHandler\s*\{/);
  assert.match(shell, /target:\s*"controlCenter"/);
  assert.match(shell, /function toggle\(\):\s*void\s*\{\s*sidebarState\.toggleForOutput\(""\);\s*\}/);
  assert.match(shell, /function open\(\):\s*void\s*\{\s*sidebarState\.openForOutput\(""\);\s*\}/);
  assert.match(shell, /function close\(\):\s*void\s*\{\s*sidebarState\.close\(\);\s*\}/);
  assert.match(shell, /function isOpen\(\):\s*bool\s*\{\s*return sidebarState\.open;\s*\}/);
  assert.match(shell, /sidebarController:\s*sidebarState/);
  assert.match(shell, /Sidebar\s*\{\s*controller:\s*sidebarState/s);
  assert.doesNotMatch(shell, /id:\s*sidebarController/);
  assert.doesNotMatch(shell, /sidebarController:\s*sidebarController/);
  assert.match(bar, /required property var sidebarController/);
  assert.match(bar, /SidebarButton\s*\{/);
  assert.match(bar, /outputName:\s*bar\.barScreen\.name/);
  assert.match(button, /toggleForOutput\(root\.outputName\)/);
  assert.match(controller, /property string targetOutputName:\s*niriState\.focusedOutputName/);
  assert.match(controller, /function screenMatches\(screen\)/);
  assert.match(sidebar, /Variants\s*\{\s*model:\s*Quickshell\.screens/s);
  assert.match(sidebar, /visible:\s*shown/);
  assert.match(sidebar, /root\.controller\.open && root\.controller\.screenMatches\(modelData\)/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});

test("provides Material You visual primitives for bar and sidebar restyle", async () => {
  const theme = await readFile(join(root, "../modules/common/Theme.qml"), "utf8");
  const config = await readFile(join(root, "../modules/common/Config.qml"), "utf8");
  const icon = await readFile(join(root, "../modules/common/MaterialIcon.qml"), "utf8");
  const iconButton = await readFile(join(root, "../modules/common/IconButton.qml"), "utf8");
  const surfaceCard = await readFile(join(root, "../modules/common/SurfaceCard.qml"), "utf8");

  assert.match(theme, /familyIcon:\s*"Material Symbols Rounded"/);
  assert.match(theme, /surfaceContainerHigh/);
  assert.match(theme, /primaryContainerText/);
  assert.match(theme, /pressedScale/);
  assert.match(config, /iconButtonSize/);
  assert.match(config, /toggleHeight/);
  assert.match(config, /contentPadding/);
  assert.match(icon, /font\.family:\s*Theme\.font\.familyIcon/);
  assert.match(icon, /font\.variableAxes/);
  assert.match(icon, /"FILL":\s*filled \? 1 : 0/);
  assert.match(iconButton, /MaterialIcon\s*\{/);
  assert.match(iconButton, /Theme\.elevation\.pressedScale/);
  assert.match(surfaceCard, /default property alias content/);
  assert.match(surfaceCard, /Theme\.colors\.surfaceContainer/);
});

test("uses Material icons for the bar control center entry and status modules", async () => {
  const button = await readFile(join(root, "../modules/sidebar/SidebarButton.qml"), "utf8");
  const audio = await readFile(join(root, "../modules/bar/AudioIndicator.qml"), "utf8");
  const network = await readFile(join(root, "../modules/bar/NetworkIndicator.qml"), "utf8");
  const resources = await readFile(join(root, "../modules/bar/Resources.qml"), "utf8");
  const clock = await readFile(join(root, "../modules/bar/Clock.qml"), "utf8");
  const barGroup = await readFile(join(root, "../modules/common/BarGroup.qml"), "utf8");

  assert.match(button, /IconButton\s*\{/);
  assert.match(button, /icon:\s*"dashboard_customize"/);
  assert.doesNotMatch(button, /text:\s*"CC"/);
  assert.match(audio, /MaterialIcon\s*\{/);
  assert.match(audio, /volume_off|volume_up/);
  assert.match(network, /MaterialIcon\s*\{/);
  assert.match(network, /name:\s*root\.service\.label === "WI" \? "wifi" : "lan"/);
  assert.match(resources, /name:\s*"monitoring"/);
  assert.match(clock, /name:\s*"schedule"/);
  assert.match(barGroup, /radius:\s*Theme\.rounding\.full/);
});

test("shows seconds in bar clock and calendar popup", async () => {
  const dateTime = await readFile(join(root, "../modules/services/DateTime.qml"), "utf8");
  const clock = await readFile(join(root, "../modules/bar/Clock.qml"), "utf8");
  const calendar = await readFile(join(root, "../modules/bar/CalendarPopup.qml"), "utf8");

  assert.match(dateTime, /precision:\s*SystemClock\.Seconds/);
  assert.match(dateTime, /timeText:\s*Qt\.formatDateTime\(root\.date,\s*"hh:mm:ss"\)/);
  assert.match(clock, /text:\s*root\.service\.timeText/);
  assert.match(calendar, /text:\s*root\.service\.timeText/);
  assert.doesNotMatch(dateTime, /timeText:\s*Qt\.formatDateTime\(root\.date,\s*"hh:mm"\)/);
});

test("styles sidebar shell as a Material You control center surface", async () => {
  const config = await readFile(join(root, "../modules/common/Config.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");

  assert.match(config, /property real wheelScrollFactor:\s*[0-9.]+/);
  assert.match(sidebar, /implicitWidth:\s*Config\.sidebar\.width \+ Config\.sidebar\.margin \* 2/);
  assert.doesNotMatch(sidebar, /implicitWidth:\s*modelData\.width/);
  assert.match(sidebar, /id:\s*scrim[\s\S]*color:\s*Theme\.colors\.transparent/);
  assert.match(sidebar, /radius:\s*Theme\.rounding\.xxl/);
  assert.match(sidebar, /Theme\.colors\.surfaceContainerLow/);
  assert.match(sidebar, /MaterialIcon\s*\{[\s\S]*name:\s*"dashboard_customize"/);
  assert.match(sidebar, /IconButton\s*\{[\s\S]*icon:\s*"close"/);
  assert.match(sidebar, /id:\s*headerIcon/);
  assert.match(sidebar, /id:\s*closeButton[\s\S]*anchors\s*\{[\s\S]*right:\s*parent\.right[\s\S]*verticalCenter:\s*parent\.verticalCenter/);
  assert.match(sidebar, /right:\s*closeButton\.left/);
  assert.match(sidebar, /SurfaceCard\s*\{[\s\S]*NotificationCenter\s*\{/);
  assert.match(sidebar, /id:\s*panelTranslate[\s\S]*Behavior on x/);
  assert.match(sidebar, /id:\s*sidebarFlickable/);
  assert.match(sidebar, /boundsBehavior:\s*Flickable\.StopAtBounds/);
  assert.match(sidebar, /WheelHandler\s*\{[\s\S]*Config\.sidebar\.wheelScrollFactor/);
  assert.match(sidebar, /function scrollBy\(delta\)[\s\S]*Math\.max\(0, Math\.min\(maxY, contentY \+ delta\)\)/);
  assert.doesNotMatch(sidebar, /#33000000/);
  assert.doesNotMatch(sidebar, /text:\s*"X"/);
  assert.doesNotMatch(sidebar, /will land in phase order/);
});

test("styles quick toggles and summary cards with Material You icon surfaces", async () => {
  const toggles = await readFile(join(root, "../modules/sidebar/QuickToggleGrid.qml"), "utf8");
  const resources = await readFile(join(root, "../modules/sidebar/ResourceCard.qml"), "utf8");
  const power = await readFile(join(root, "../modules/sidebar/PowerSummary.qml"), "utf8");

  assert.match(toggles, /function iconFor\(id\)/);
  assert.match(toggles, /MaterialIcon\s*\{/);
  assert.match(toggles, /Config\.sidebar\.toggleHeight/);
  assert.match(toggles, /Theme\.elevation\.pressedScale/);
  assert.match(resources, /SurfaceCard\s*\{/);
  assert.match(resources, /name:\s*"monitoring"/);
  assert.match(power, /SurfaceCard\s*\{/);
  assert.match(power, /function batteryIcon\(\)/);
  assert.match(power, /battery_charging_full/);
  assert.match(power, /MaterialIcon\s*\{/);
});

test("styles detailed sidebar panels with shared Material components", async () => {
  const files = {
    wifi: await readFile(join(root, "../modules/sidebar/WifiPanel.qml"), "utf8"),
    bluetooth: await readFile(join(root, "../modules/sidebar/BluetoothPanel.qml"), "utf8"),
    audio: await readFile(join(root, "../modules/sidebar/AudioMixer.qml"), "utf8"),
    media: await readFile(join(root, "../modules/sidebar/MediaPanel.qml"), "utf8"),
    brightness: await readFile(join(root, "../modules/sidebar/BrightnessPanel.qml"), "utf8"),
    nightMode: await readFile(join(root, "../modules/sidebar/NightModePanel.qml"), "utf8"),
    notifications: await readFile(join(root, "../modules/sidebar/NotificationCenter.qml"), "utf8"),
    toast: await readFile(join(root, "../modules/sidebar/NotificationToast.qml"), "utf8"),
    dismissibleNotification: await readFile(join(root, "../modules/sidebar/DismissibleNotificationCard.qml"), "utf8"),
    notificationIcon: await readFile(join(root, "../modules/common/NotificationAppIcon.qml"), "utf8"),
    notificationImageCache: await readFile(join(root, "../modules/common/NotificationImageCache.js"), "utf8"),
    system: await readFile(join(root, "../modules/sidebar/SystemPanel.qml"), "utf8"),
  };

  for (const [name, content] of Object.entries(files)) {
    assert.doesNotMatch(content, /component ActionButton/, `${name} should use shared ActionChip/IconButton`);
    assert.doesNotMatch(content, /text:\s*"X"/, `${name} should not use text close buttons`);
  }

  assert.match(files.wifi, /SectionHeader\s*\{[\s\S]*icon:\s*"wifi"/);
  assert.match(files.wifi, /ActionChip\s*\{/);
  assert.match(files.bluetooth, /SectionHeader\s*\{[\s\S]*icon:\s*"bluetooth"/);
  assert.match(files.bluetooth, /MaterialIcon\s*\{[\s\S]*name:\s*"bluetooth"/);
  assert.match(files.audio, /SectionHeader\s*\{[\s\S]*icon:\s*"tune"/);
  assert.match(files.audio, /ActionChip\s*\{/);
  assert.match(files.media, /IconButton\s*\{[\s\S]*skip_previous/);
  assert.match(files.brightness, /SectionHeader\s*\{[\s\S]*icon:\s*"brightness_6"/);
  assert.match(files.brightness, /model:\s*actions\.brightnessDisplays/);
  assert.match(files.brightness, /actions\.setBrightness\(display, value\)/);
  assert.match(files.brightness, /actions\.refreshBrightness\(\)/);
  assert.doesNotMatch(files.brightness, /ddcutil|Quickshell\.execDetached/);
  assert.match(files.nightMode, /SectionHeader\s*\{[\s\S]*icon:\s*"nightlight"/);
  assert.match(files.nightMode, /actions\.toggleNightMode\(\)/);
  assert.match(files.nightMode, /actions\.setNightModeTemperature\(value\)/);
  assert.match(files.nightMode, /actions\.refreshNightMode\(\)/);
  assert.doesNotMatch(files.nightMode, /busctl|wl-gammarelay-rs|Quickshell\.execDetached/);
  assert.match(files.notifications, /SectionHeader\s*\{[\s\S]*icon:\s*"notifications"/);
  assert.match(files.notifications, /DismissibleNotificationCard\s*\{/);
  assert.match(files.toast, /DismissibleNotificationCard\s*\{/);
  assert.match(files.dismissibleNotification, /NotificationAppIcon\s*\{[\s\S]*appIcon:\s*root\.notification\.appIcon[\s\S]*image:\s*root\.notification\.image/);
  assert.match(files.dismissibleNotification, /IconButton\s*\{[\s\S]*icon:\s*"close"/);
  assert.match(files.dismissibleNotification, /drag\.axis:\s*Drag\.XAxis/);
  assert.match(files.dismissibleNotification, /drag\.minimumX:\s*0/);
  assert.match(files.dismissibleNotification, /readonly property int dismissThreshold/);
  assert.match(files.dismissibleNotification, /Behavior on x/);
  assert.match(files.dismissibleNotification, /signal dismissed\(\)/);
  assert.doesNotMatch(files.dismissibleNotification, /name:\s*"delete"/);
  assert.doesNotMatch(files.dismissibleNotification, /card\.x\s*\/\s*root\.dismissThreshold/);
  assert.doesNotMatch(files.dismissibleNotification, /clip:\s*true/);
  assert.match(files.notificationIcon, /import Quickshell\.Widgets/);
  assert.match(files.notificationIcon, /property string appIcon/);
  assert.match(files.notificationIcon, /property string image/);
  assert.match(files.notificationIcon, /property bool imageLoadFailed:\s*false/);
  assert.match(files.notificationIcon, /import "NotificationImageCache\.js" as NotificationImageCache/);
  assert.match(files.notificationIcon, /readonly property bool showImage:\s*hasImage && !imageLoadFailed && !NotificationImageCache\.hasFailed\(image\)/);
  assert.match(files.notificationIcon, /onImageChanged:\s*imageLoadFailed = NotificationImageCache\.hasFailed\(image\)/);
  assert.match(files.notificationIcon, /if \(status === Image\.Error\)[\s\S]*NotificationImageCache\.markFailed\(root\.image\)[\s\S]*root\.imageLoadFailed = true/);
  assert.match(files.notificationIcon, /Quickshell\.iconPath\(root\.appIcon, "image-missing"\)/);
  assert.match(files.notificationIcon, /MaterialIcon\s*\{/);
  assert.match(files.notificationImageCache, /\.pragma library/);
  assert.match(files.notificationImageCache, /function hasFailed\(source\)/);
  assert.match(files.notificationImageCache, /function markFailed\(source\)/);
  assert.match(files.system, /SectionHeader\s*\{[\s\S]*icon:\s*"settings"/);
  assert.match(files.system, /MaterialIcon\s*\{[\s\S]*name:\s*tile\.icon/);
  assert.match(files.system, /readonly property string pendingAction/);
  assert.doesNotMatch(files.system, /pendingSessionAction\.length/);
});

test("wires notification ownership into sidebar and focused-output toasts", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const notifications = await readFile(join(root, "../modules/services/Notifications.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const center = await readFile(join(root, "../modules/sidebar/NotificationCenter.qml"), "utf8");
  const toast = await readFile(join(root, "../modules/sidebar/NotificationToast.qml"), "utf8");
  const card = await readFile(join(root, "../modules/sidebar/DismissibleNotificationCard.qml"), "utf8");
  const icon = await readFile(join(root, "../modules/common/NotificationAppIcon.qml"), "utf8");

  assert.match(shell, /Notifications\s*\{\s*id:\s*notifications/s);
  assert.match(shell, /notificationService:\s*notifications/);
  assert.match(shell, /NotificationToast\s*\{/);
  assert.match(shell, /NotificationToast\s*\{[\s\S]*sidebarController:\s*sidebarState/);
  assert.match(notifications, /import Quickshell\.Services\.Notifications/);
  assert.match(notifications, /NotificationServer\s*\{/);
  assert.match(notifications, /property bool doNotDisturb:\s*false/);
  assert.match(notifications, /popup:\s*!doNotDisturb/);
  assert.match(notifications, /function toggleDoNotDisturb\(\)/);
  assert.match(notifications, /function clearAll\(\)/);
  assert.match(notifications, /function dismissServerNotification\(notificationId\)/);
  assert.match(notifications, /notificationServer\.trackedNotifications\?\.values/);
  assert.match(notifications, /typeof serverNotification\.dismiss !== "function"/);
  assert.doesNotMatch(notifications, /entry\.notification\.dismiss\(\)/);
  assert.match(sidebar, /required property var notificationService/);
  assert.match(sidebar, /NotificationCenter\s*\{/);
  assert.match(center, /root\.service\.toggleDoNotDisturb\(\)/);
  assert.match(center, /root\.service\.clearAll\(\)/);
  assert.match(center, /root\.service\.dismissNotification\(modelData\.notificationId\)/);
  assert.match(center, /DismissibleNotificationCard\s*\{[\s\S]*bodyLineCount:\s*3/);
  assert.match(toast, /required property var niriState/);
  assert.match(toast, /property var sidebarController:\s*null/);
  assert.match(sidebar, /WlrLayershell\.layer:\s*WlrLayer\.Top/);
  assert.match(toast, /WlrLayershell\.layer:\s*WlrLayer\.Overlay/);
  assert.match(toast, /visible:\s*targetScreen && root\.service\.popupCount > 0/);
  assert.doesNotMatch(toast, /sidebarOpenOnTarget/);
  assert.match(toast, /modelData\.name === root\.targetOutputName/);
  assert.match(toast, /root\.service\.popupNotifications\.slice\(0, 3\)/);
  assert.match(toast, /implicitHeight:\s*toastColumn\.implicitHeight \+ Config\.sidebar\.margin/);
  assert.match(toast, /margins\s*\{[\s\S]*top:\s*Config\.bar\.height \+ Config\.bar\.margin \* 2/);
  assert.doesNotMatch(toast, /topMargin:\s*Config\.bar\.height \+ Config\.bar\.margin \* 2/);
  assert.match(toast, /DismissibleNotificationCard\s*\{[\s\S]*bodyLineCount:\s*2/);
  assert.match(toast, /root\.service\.dismissNotification\(modelData\.notificationId\)/);
  assert.doesNotMatch(toast, /implicitHeight:\s*modelData\.height/);
  assert.doesNotMatch(toast, /bottom:\s*true/);
  assert.match(card, /function settleSwipe\(\)/);
  assert.match(card, /card\.x >= dismissThreshold/);
  assert.match(card, /requestDismiss\(true\)/);
  assert.match(card, /requestDismiss\(false\)/);
  assert.match(card, /drag\.maximumX:\s*root\.width \* 0\.58/);
  assert.match(icon, /NotificationImageCache\.hasFailed\(image\)/);
  assert.match(icon, /Image\s*\{[\s\S]*source:\s*root\.showImage \? root\.image : ""/);
  assert.match(icon, /Quickshell\.iconPath\(root\.appIcon, "image-missing"\)/);
  assert.doesNotMatch(notifications, /FileView|setText|write/);
  assert.doesNotMatch(toast, /Quickshell\.Hyprland/);
});

test("wires quick toggles and low-risk system cards through sidebar services", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const actions = await readFile(join(root, "../modules/services/SystemActions.qml"), "utf8");
  const capture = await readFile(join(root, "../modules/services/Capture.qml"), "utf8");
  const brightness = await readFile(join(root, "../modules/services/Brightness.qml"), "utf8");
  const nightMode = await readFile(join(root, "../modules/services/NightMode.qml"), "utf8");
  const quickToggles = await readFile(join(root, "../modules/sidebar/QuickToggleGrid.qml"), "utf8");
  const resourceCard = await readFile(join(root, "../modules/sidebar/ResourceCard.qml"), "utf8");
  const powerSummary = await readFile(join(root, "../modules/sidebar/PowerSummary.qml"), "utf8");

  assert.match(shell, /SystemActions\s*\{/);
  assert.match(shell, /networkService:\s*network/);
  assert.match(shell, /audioService:\s*audio/);
  assert.match(shell, /notificationService:\s*notifications/);
  assert.match(shell, /Brightness\s*\{\s*id:\s*brightness/s);
  assert.match(shell, /brightnessService:\s*brightness/);
  assert.match(shell, /NightMode\s*\{\s*id:\s*nightMode/s);
  assert.match(shell, /nightModeService:\s*nightMode/);
  assert.match(shell, /Capture\s*\{\s*id:\s*capture/s);
  assert.match(shell, /captureService:\s*capture/);
  assert.match(shell, /systemActions:\s*systemActions/);
  assert.match(shell, /resourceService:\s*resourceUsage/);
  assert.match(shell, /batteryService:\s*battery/);

  assert.match(sidebar, /required property var systemActions/);
  assert.match(sidebar, /required property var resourceService/);
  assert.match(sidebar, /required property var batteryService/);
  assert.match(sidebar, /QuickToggleGrid\s*\{/);
  assert.match(sidebar, /ResourceCard\s*\{/);
  assert.match(sidebar, /PowerSummary\s*\{/);

  for (const id of [
    "wifi",
    "bluetooth",
    "dnd",
    "audio",
    "microphone",
    "night",
    "screenshot",
    "recording",
    "lock",
    "regionRecording",
  ]) {
    assert.match(quickToggles, new RegExp(`"${id}"`));
  }
  assert.match(quickToggles, /"lock"[\s\S]*"regionRecording"/);

  assert.match(actions, /readonly property bool bluetoothAvailable:\s*bluetoothService\.available/);
  assert.match(actions, /readonly property bool microphoneAvailable:\s*audioService\.inputAvailable/);
  assert.match(actions, /required property var nightModeService/);
  assert.match(actions, /readonly property bool nightModeAvailable:\s*nightModeService\.available/);
  assert.match(actions, /readonly property bool nightModeEnabled:\s*nightModeService\.enabled/);
  assert.match(actions, /readonly property string nightModeStatus:\s*nightModeService\.statusText \|\| "Backend unavailable"/);
  assert.match(actions, /function setNightModeTemperature\(temperature\)/);
  assert.match(actions, /function refreshNightMode\(\)/);
  assert.match(brightness, /property bool controllable:\s*true/);
  assert.match(brightness, /readonly property bool available:\s*displays\.some\(display => display\.controllable\)/);
  assert.match(brightness, /if \(!display \|\| !display\.controllable\)/);
  assert.match(brightness, /line === "Invalid display"/);
  assert.match(brightness, /property var staleReadBuses:\s*\[\]/);
  assert.match(brightness, /function hasSetPendingForBus\(bus\)/);
  assert.match(brightness, /function hasStaleReadForBus\(bus\)/);
  assert.match(brightness, /currentReadBus === display\.bus[\s\S]*staleReadBuses = \[\.\.\.staleReadBuses, display\.bus\]/);
  assert.match(brightness, /root\.hasSetPendingForBus\(root\.currentReadBus\)[\s\S]*root\.hasStaleReadForBus\(root\.currentReadBus\)/);
  assert.match(actions, /required property var captureService/);
  assert.match(actions, /readonly property bool screenshotAvailable:\s*captureService\.screenshotAvailable/);
  assert.match(actions, /readonly property bool screenshotBusy:\s*captureService\.screenshotBusy/);
  assert.match(actions, /readonly property bool recordingActive:\s*captureService\.recordingActive/);
  assert.match(actions, /readonly property bool regionRecordingAvailable:\s*captureService\.regionRecordingAvailable/);
  assert.match(actions, /readonly property string regionRecordingStatus:\s*captureService\.regionRecordingStatus/);
  assert.match(actions, /readonly property bool regionRecordingActive:\s*captureService\.regionRecordingActive/);
  assert.match(actions, /function takeScreenshot\(\)[\s\S]*captureService\.takeScreenshot\(\)/);
  assert.match(actions, /function toggleRecording\(\)[\s\S]*captureService\.toggleRecording\(\)/);
  assert.match(actions, /function toggleRegionRecording\(\)[\s\S]*captureService\.toggleRegionRecording\(\)/);
  assert.match(quickToggles, /if \(id === "regionRecording"\)\s*return "Record area"/);
  assert.match(quickToggles, /if \(id === "regionRecording"\)\s*return actions\.regionRecordingStatus/);
  assert.match(quickToggles, /signal startRegionRecordingRequested\(\)/);
  assert.match(quickToggles, /if \(actions\.regionRecordingActive\)[\s\S]*actions\.toggleRegionRecording\(\)/);
  assert.match(quickToggles, /root\.startRegionRecordingRequested\(\)/);
  assert.match(sidebar, /id:\s*startRegionRecordingTimer[\s\S]*interval:\s*250[\s\S]*root\.systemActions\.toggleRegionRecording\(\)/);
  assert.match(sidebar, /onStartRegionRecordingRequested:[\s\S]*root\.controller\.close\(\)[\s\S]*startRegionRecordingTimer\.restart\(\)/);
  assert.match(quickToggles, /if \(id === "screenshot"\)\s*return false/);
  assert.match(capture, /readonly property bool screenshotAvailable:\s*tools\.niri && tools\.wlCopy/);
  assert.match(capture, /readonly property string screenshotStatus:\s*screenshotAvailable \? "Clipboard" : "Unavailable"/);
  assert.match(capture, /niri msg action screenshot --path \\?"\$file\\?"/);
  assert.match(capture, /wl-copy --type image\/png < \\?"\$file\\?"/);
  assert.match(capture, /readonly property bool recordingAvailable:\s*tools\.niri && tools\.wfRecorder/);
  assert.match(capture, /recordingAvailable \? "Focused output" : "Unavailable"/);
  assert.match(capture, /niri msg --json focused-output/);
  assert.match(capture, /wf-recorder -o \\?"\$output\\?" -f \\?"\$file\\?"/);
  assert.match(capture, /readonly property bool regionRecordingAvailable:\s*tools\.slurp && tools\.wfRecorder/);
  assert.match(capture, /regionRecordingAvailable \? "Select region" : "Unavailable"/);
  assert.match(capture, /readonly property var regionRecordingCommand:/);
  assert.match(capture, /Quickshell\.execDetached\(regionRecordingCommand\)/);
  assert.match(capture, /geometry=\\?"\$\(slurp\)\\?"/);
  assert.match(capture, /exec wf-recorder -g \\?"\$geometry\\?" -f \\?"\$file\\?"/);
  assert.match(capture, /id:\s*regionRecordingMonitorTimer[\s\S]*interval:\s*500/);
  assert.match(capture, /pgrep -x slurp[\s\S]*pgrep -x wf-recorder/);
  assert.match(capture, /recordingActive = false[\s\S]*stopRecordingProcess\.running = true/);
  assert.match(capture, /pkill -INT wf-recorder/);
  assert.match(capture, /pkill -TERM slurp/);
  assert.match(nightMode, /command:\s*\["busctl", "--user", "introspect", "--xml-interface", "rs\.wl-gammarelay", "\/outputs"\]/);
  assert.match(nightMode, /"get-property"[\s\S]*"rs\.wl\.gammarelay"[\s\S]*"Temperature"/);
  assert.match(nightMode, /"set-property"[\s\S]*"rs\.wl\.gammarelay"[\s\S]*"Temperature"[\s\S]*"q"/);
  assert.match(nightMode, /function parseOutputs\(text\)/);
  assert.match(nightMode, /pattern\.exec\(value\)/);
  assert.doesNotMatch(nightMode, /matchAll|replaceAll/);
  assert.match(nightMode, /function parseTemperature\(text\)/);
  assert.match(actions, /required property var brightnessService/);
  assert.match(actions, /readonly property bool brightnessAvailable:\s*brightnessService\.available/);
  assert.match(actions, /readonly property var brightnessDisplays:\s*brightnessService\.displays/);
  assert.match(actions, /function setBrightness\(display, percent\)/);
  assert.match(actions, /function refreshBrightness\(\)/);
  assert.match(brightness, /command:\s*\["ddcutil", "detect"\]/);
  assert.match(brightness, /\["ddcutil", "--bus", String\(currentReadBus\), "getvcp", "10"\]/);
  assert.match(brightness, /\["ddcutil", "--bus", String\(next\.bus\), "setvcp", "10", String\(next\.value\)\]/);
  assert.match(brightness, /function parseDisplays\(text\)/);
  assert.match(brightness, /function parseBrightness\(text\)/);
  assert.match(actions, /function takeScreenshot\(\)/);
  assert.match(actions, /function lockScreen\(\)/);
  assert.match(resourceCard, /root\.service\.cpuText/);
  assert.match(resourceCard, /root\.service\.memoryText/);
  assert.match(resourceCard, /root\.service\.swapText/);
  assert.match(powerSummary, /batteryService\.present/);
  assert.match(powerSummary, /actions\.powerProfileStatus/);

  assert.doesNotMatch(quickToggles, /Quickshell\.execDetached/);
  assert.doesNotMatch(quickToggles, /import Quickshell/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});

test("wires Wi-Fi and VPN panel through a NetworkManager service boundary", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const wifi = await readFile(join(root, "../modules/services/Wifi.qml"), "utf8");
  const panel = await readFile(join(root, "../modules/sidebar/WifiPanel.qml"), "utf8");
  const actions = await readFile(join(root, "../modules/services/SystemActions.qml"), "utf8");

  assert.match(shell, /Wifi\s*\{\s*id:\s*wifi/s);
  assert.match(shell, /wifiService:\s*wifi/);
  assert.match(sidebar, /required property var wifiService/);
  assert.match(sidebar, /WifiPanel\s*\{/);
  assert.match(sidebar, /Flickable\s*\{/);
  assert.match(actions, /required property var wifiService/);
  assert.match(actions, /wifiService\.toggleEnabled\(\)/);
  assert.match(wifi, /import Quickshell\.Networking/);
  assert.match(wifi, /connectWithPsk\(psk\)/);
  assert.match(wifi, /inputMethodHints|Password required|passwordNetwork/);
  assert.match(wifi, /function parseVpnProfiles\(\)/);
  assert.match(wifi, /function buildVpnProfiles\(vpnText, activeText\)/);
  assert.match(wifi, /function commitVpnRefreshIfReady\(\)/);
  assert.match(wifi, /function vpnProfilesEqual\(left, right\)/);
  assert.match(wifi, /pendingVpnListText/);
  assert.match(wifi, /pendingActiveVpnListText/);
  assert.match(wifi, /if \(!vpnProfilesEqual\(vpnProfiles, nextProfiles\)\)/);
  assert.doesNotMatch(wifi, /function refreshVpn\(\)\s*\{[\s\S]*vpnListText\s*=\s*""[\s\S]*activeVpnListText\s*=\s*""/);
  assert.match(wifi, /\["nmcli", "connection", profile\.active \? "down" : "up", profile\.name\]/);
  assert.match(panel, /echoMode:\s*TextInput\.Password/);
  assert.match(panel, /inputMethodHints:\s*Qt\.ImhSensitiveData/);
  assert.match(panel, /passwordInput\.text = ""/);
  assert.match(panel, /service\.connectWithPassword\(network, passwordInput\.text\)/);
  assert.match(panel, /service\.toggleVpn\(modelData\)/);
  assert.doesNotMatch(panel, /Quickshell\.execDetached/);
  assert.doesNotMatch(panel, /nmcli/);
  assert.doesNotMatch(panel, /environment[\s\S]*PASSWORD/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});

test("wires Bluetooth panel through BlueZ service boundary", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const bluetooth = await readFile(join(root, "../modules/services/Bluetooth.qml"), "utf8");
  const panel = await readFile(join(root, "../modules/sidebar/BluetoothPanel.qml"), "utf8");
  const actions = await readFile(join(root, "../modules/services/SystemActions.qml"), "utf8");

  assert.match(shell, /Bluetooth\s*\{\s*id:\s*bluetooth/s);
  assert.match(shell, /bluetoothService:\s*bluetooth/);
  assert.match(sidebar, /required property var bluetoothService/);
  assert.match(sidebar, /BluetoothPanel\s*\{/);
  assert.match(actions, /required property var bluetoothService/);
  assert.match(actions, /bluetoothService\.toggleEnabled\(\)/);
  assert.match(bluetooth, /import Quickshell\.Bluetooth/);
  assert.match(bluetooth, /Bluetooth\.defaultAdapter/);
  assert.match(bluetooth, /adapter\.discovering = true/);
  assert.match(bluetooth, /device\.connect\(\)/);
  assert.match(bluetooth, /device\.disconnect\(\)/);
  assert.match(bluetooth, /batteryAvailable/);
  assert.match(panel, /service\.toggleDevice\(modelData\)/);
  assert.match(panel, /import Quickshell\.Bluetooth/);
  assert.match(panel, /modelData\.blocked/);
  assert.doesNotMatch(panel, /Quickshell\.execDetached/);
  assert.doesNotMatch(panel, /bluetoothctl/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});

test("wires audio mixer through PipeWire service boundary", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const audio = await readFile(join(root, "../modules/services/Audio.qml"), "utf8");
  const mixer = await readFile(join(root, "../modules/sidebar/AudioMixer.qml"), "utf8");
  const actions = await readFile(join(root, "../modules/services/SystemActions.qml"), "utf8");

  assert.match(shell, /audioService:\s*audio/);
  assert.match(sidebar, /required property var audioService/);
  assert.match(sidebar, /AudioMixer\s*\{/);
  assert.match(audio, /import Quickshell\.Services\.Pipewire/);
  assert.match(audio, /readonly property var source:\s*Pipewire\.defaultAudioSource/);
  assert.match(audio, /outputDevices:\s*audioNodes\(true, false\)/);
  assert.match(audio, /inputDevices:\s*audioNodes\(false, false\)/);
  assert.match(audio, /outputStreams:\s*audioNodes\(true, true\)/);
  assert.match(audio, /inputStreams:\s*audioNodes\(false, true\)/);
  assert.match(audio, /Pipewire\.preferredDefaultAudioSink = node/);
  assert.match(audio, /Pipewire\.preferredDefaultAudioSource = node/);
  assert.match(audio, /function toggleMicrophoneMute\(\)/);
  assert.match(actions, /audioService\.toggleMicrophoneMute\(\)/);
  assert.match(mixer, /import Quickshell\.Services\.Pipewire/);
  assert.match(mixer, /component AudioSlider:\s*ColumnLayout\s*\{\s*id:\s*audioSlider/);
  assert.match(mixer, /property bool compact:\s*false/);
  assert.match(mixer, /property real maxVolume:\s*compact \? 1 : 1\.5/);
  assert.match(mixer, /PwObjectTracker\s*\{\s*objects:\s*audioSlider\.node \? \[audioSlider\.node\] : \[\]/s);
  assert.match(mixer, /MaterialSlider\s*\{/);
  assert.match(mixer, /from:\s*0/);
  assert.match(mixer, /to:\s*maxVolume/);
  assert.match(mixer, /stepSize:\s*0\.01/);
  assert.match(mixer, /size:\s*compact \? "compact" : "regular"/);
  assert.match(mixer, /visible:\s*!compact/);
  assert.match(mixer, /text:\s*compact \? "" : ready && node\.audio\.muted \? "Unmute" : "Mute"/);
  assert.match(mixer, /compact:\s*true/);
  assert.match(mixer, /maxVolume:\s*1/);
  assert.match(mixer, /node\.audio\.volume = value/);
  assert.match(mixer, /node\.audio\.muted = !node\.audio\.muted/);
  assert.match(mixer, /service\.setDefaultSink\(node\)/);
  assert.match(mixer, /service\.setDefaultSource\(node\)/);
  assert.doesNotMatch(mixer, /component SliderTrack/);
  assert.doesNotMatch(mixer, /wpctl|pactl|Quickshell\.execDetached/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});

test("wires MPRIS media panel through media service boundary", async () => {
  const shell = await readFile(join(root, "../shell.qml"), "utf8");
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const media = await readFile(join(root, "../modules/services/Media.qml"), "utf8");
  const panel = await readFile(join(root, "../modules/sidebar/MediaPanel.qml"), "utf8");

  assert.match(shell, /Media\s*\{\s*id:\s*media/s);
  assert.match(shell, /mediaService:\s*media/);
  assert.match(sidebar, /required property var mediaService/);
  assert.match(sidebar, /MediaPanel\s*\{/);
  assert.match(media, /import Quickshell\.Services\.Mpris/);
  assert.match(media, /Mpris\.players\.values/);
  assert.match(media, /activePlayer\.previous\(\)/);
  assert.match(media, /activePlayer\.togglePlaying\(\)/);
  assert.match(media, /activePlayer\.next\(\)/);
  assert.match(panel, /service\.previous\(\)/);
  assert.match(panel, /service\.toggle\(\)/);
  assert.match(panel, /service\.next\(\)/);
  assert.doesNotMatch(panel, /playerctl|Quickshell\.execDetached/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});

test("wires system controls with confirmation-gated session actions", async () => {
  const sidebar = await readFile(join(root, "../modules/sidebar/Sidebar.qml"), "utf8");
  const actions = await readFile(join(root, "../modules/services/SystemActions.qml"), "utf8");
  const capture = await readFile(join(root, "../modules/services/Capture.qml"), "utf8");
  const panel = await readFile(join(root, "../modules/sidebar/SystemPanel.qml"), "utf8");
  const brightnessPanel = await readFile(join(root, "../modules/sidebar/BrightnessPanel.qml"), "utf8");
  const nightModePanel = await readFile(join(root, "../modules/sidebar/NightModePanel.qml"), "utf8");
  const materialSlider = await readFile(join(root, "../modules/common/MaterialSlider.qml"), "utf8");
  const unit = await readFile(join(root, "../systemd/user/wl-gammarelay-rs.service"), "utf8");
  const powerSummary = await readFile(join(root, "../modules/sidebar/PowerSummary.qml"), "utf8");

  assert.match(sidebar, /SystemPanel\s*\{/);
  assert.match(sidebar, /BrightnessPanel\s*\{/);
  assert.match(sidebar, /NightModePanel\s*\{/);
  assert.match(actions, /required property var powerProfilesService/);
  assert.match(actions, /required property var brightnessService/);
  assert.match(actions, /readonly property bool brightnessAvailable:\s*brightnessService\.available/);
  assert.match(actions, /readonly property string brightnessStatus:\s*brightnessService\.statusText \|\| "No DDC display"/);
  assert.match(actions, /required property var nightModeService/);
  assert.match(actions, /readonly property bool nightModeAvailable:\s*nightModeService\.available/);
  assert.match(actions, /readonly property bool nightModeEnabled:\s*nightModeService\.enabled/);
  assert.match(actions, /readonly property bool powerProfileAvailable:\s*powerProfilesService\.available/);
  assert.match(actions, /readonly property var powerProfiles:\s*powerProfilesService\.profiles/);
  assert.match(actions, /required property var captureService/);
  assert.match(actions, /readonly property string screenshotStatus:\s*captureService\.screenshotStatus/);
  assert.match(actions, /readonly property string recordingStatus:\s*captureService\.recordingStatus/);
  assert.match(actions, /readonly property string regionRecordingStatus:\s*captureService\.regionRecordingStatus/);
  assert.match(actions, /property string pendingSessionAction:\s*""/);
  assert.match(actions, /readonly property bool recordingActive:\s*captureService\.recordingActive/);
  assert.match(actions, /readonly property bool regionRecordingActive:\s*captureService\.regionRecordingActive/);
  assert.match(actions, /Item\s*\{/);
  assert.doesNotMatch(actions, /Process\s*\{\s*id:\s*startRecordingProcess/s);
  assert.doesNotMatch(actions, /Process\s*\{\s*id:\s*stopRecordingProcess/s);
  assert.match(actions, /function requiresConfirmation\(action\)/);
  assert.match(actions, /function setPowerProfile\(profile\)/);
  assert.match(actions, /pendingSessionAction !== action/);
  assert.match(actions, /confirmTimer\.restart\(\)/);
  assert.match(actions, /\["swaylock", "--screenshots", "--clock", "--indicator"\]/);
  assert.match(actions, /\["niri", "msg", "action", "quit"\]/);
  assert.match(actions, /\["systemctl", "poweroff"\]/);
  assert.match(actions, /Quickshell\.execDetached\(command\)/);
  assert.match(panel, /actions\.setPowerProfile\(modelData\.name\)/);
  assert.match(panel, /actions\.runSessionAction\("logout"\)/);
  assert.match(panel, /actions\.runSessionAction\("shutdown"\)/);
  assert.match(panel, /actions\.cancelSessionAction\(\)/);
  assert.match(panel, /actions\.takeScreenshot\(\)/);
  assert.match(panel, /detail:\s*actions\.screenshotStatus/);
  assert.doesNotMatch(panel, /active:\s*actions\.screenshotBusy/);
  assert.doesNotMatch(panel, /enabled:\s*actions\.screenshotAvailable && !actions\.screenshotBusy/);
  assert.match(panel, /detail:\s*actions\.recordingStatus/);
  assert.match(panel, /actions\.toggleRecording\(\)/);
  assert.match(capture, /property bool screenshotBusy:\s*false/);
  assert.match(capture, /property bool regionRecordingActive:\s*false/);
  assert.match(capture, /function takeScreenshot\(\)/);
  assert.match(capture, /function toggleRecording\(\)/);
  assert.match(capture, /function toggleRegionRecording\(\)/);
  assert.match(materialSlider, /signal setValue\(real value\)/);
  assert.match(materialSlider, /property real from:\s*0/);
  assert.match(materialSlider, /property real to:\s*1/);
  assert.match(materialSlider, /property real stepSize:\s*0/);
  assert.match(materialSlider, /property string size:\s*"regular"/);
  assert.match(materialSlider, /property int trackHeight:\s*size === "compact" \? 6 : 9/);
  assert.match(materialSlider, /property int handleSize:\s*size === "compact" \? 14 : 18/);
  assert.match(materialSlider, /readonly property real ratio/);
  assert.match(materialSlider, /Rectangle\s*\{[\s\S]*id:\s*handle/);
  assert.match(materialSlider, /MouseArea\s*\{[\s\S]*preventStealing:\s*true/);
  assert.match(materialSlider, /function valueFromPosition\(position\)/);
  assert.match(brightnessPanel, /MaterialSlider\s*\{/);
  assert.match(brightnessPanel, /MaterialSlider\s*\{[\s\S]*?visible:\s*display\.controllable/);
  assert.match(brightnessPanel, /MaterialSlider\s*\{[\s\S]*?enabled:\s*display\.ready[\s\S]*?from:\s*0[\s\S]*?to:\s*100[\s\S]*?stepSize:\s*1[\s\S]*?onSetValue:/);
  assert.doesNotMatch(brightnessPanel, /component BrightnessSlider/);
  assert.doesNotMatch(brightnessPanel, /MaterialSlider\s*\{[\s\S]*?enabled:\s*display\.ready\s*&&\s*!display\.busy/);
  assert.doesNotMatch(brightnessPanel, /root\.serviceBusy \? "Reading" : "Refresh"/);
  assert.doesNotMatch(brightnessPanel, /enabled:\s*!root\.serviceBusy/);
  assert.match(brightnessPanel, /onSetValue:\s*value => actions\.setBrightness\(display, value\)/);
  assert.match(nightModePanel, /MaterialSlider\s*\{/);
  assert.match(nightModePanel, /MaterialIcon\s*\{[\s\S]*?name:\s*"bedtime"[\s\S]*?MaterialSlider\s*\{/);
  assert.match(nightModePanel, /MaterialSlider\s*\{[\s\S]*?MaterialIcon\s*\{[\s\S]*?name:\s*"wb_sunny"/);
  assert.match(nightModePanel, /MaterialSlider\s*\{[\s\S]*?enabled:\s*root\.available[\s\S]*?from:\s*root\.minTemperature[\s\S]*?to:\s*root\.maxTemperature[\s\S]*?stepSize:\s*50[\s\S]*?onSetValue:/);
  assert.doesNotMatch(nightModePanel, /component TemperatureSlider/);
  assert.doesNotMatch(nightModePanel, /MaterialSlider\s*\{[\s\S]*?enabled:\s*root\.available\s*&&\s*!root\.serviceBusy/);
  assert.match(nightModePanel, /text:\s*root\.enabledState \? "On" : "Off"[\s\S]*?enabled:\s*root\.available/);
  assert.doesNotMatch(nightModePanel, /root\.serviceBusy \? "Reading" : "Refresh"/);
  assert.doesNotMatch(nightModePanel, /enabled:\s*!root\.serviceBusy/);
  assert.match(nightModePanel, /onSetValue:\s*value => actions\.setNightModeTemperature\(value\)/);
  assert.match(unit, /ExecStart=\/usr\/bin\/wl-gammarelay-rs run/);
  assert.match(unit, /WantedBy=graphical-session\.target/);
  assert.match(powerSummary, /actions\.powerProfileAvailable/);
  assert.doesNotMatch(panel, /Quickshell\.execDetached|\["systemctl"|\["loginctl"|\["niri", "msg"|\["swaylock"\]/);
  assert.doesNotMatch(sidebar, /Quickshell\.Hyprland/);
});
