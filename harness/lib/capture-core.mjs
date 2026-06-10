export function parseCaptureToolProbe(text) {
  const tools = {
    grim: false,
    niri: false,
    notifySend: false,
    pactl: false,
    slurp: false,
    wlCopy: false,
    wfRecorder: false,
    wpctl: false,
  };

  for (const rawLine of String(text ?? "").split("\n")) {
    const [name, value] = rawLine.trim().split("=");
    const available = value === "1";

    if (name === "grim")
      tools.grim = available;
    else if (name === "niri")
      tools.niri = available;
    else if (name === "notify-send")
      tools.notifySend = available;
    else if (name === "pactl")
      tools.pactl = available;
    else if (name === "slurp")
      tools.slurp = available;
    else if (name === "wl-copy")
      tools.wlCopy = available;
    else if (name === "wf-recorder")
      tools.wfRecorder = available;
    else if (name === "wpctl")
      tools.wpctl = available;
  }

  return tools;
}

export function screenshotAvailable(tools) {
  return tools.niri === true && tools.wlCopy === true;
}

export function recordingAvailable(tools) {
  return currentOutputRecordingAvailable(tools) || regionRecordingAvailable(tools);
}

export function currentOutputRecordingAvailable(tools) {
  return tools.niri === true && tools.wfRecorder === true;
}

export function regionRecordingAvailable(tools) {
  return tools.slurp === true && tools.wfRecorder === true;
}

export function recordingModeAvailable(mode, tools) {
  if (mode === "region")
    return regionRecordingAvailable(tools);
  if (mode === "output")
    return currentOutputRecordingAvailable(tools);
  return false;
}

export function parseAudioMonitorSource(text) {
  return String(text ?? "").split("\n").map(line => line.trim()).find(line => line.length > 0) ?? "";
}

export function recordingAudioAvailable(audioMonitorSource) {
  return parseAudioMonitorSource(audioMonitorSource).length > 0;
}

export function captureToolProbeCommand() {
  return [
    "sh",
    "-c",
    "for tool in grim niri notify-send pactl slurp wl-copy wf-recorder wpctl; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool=1\" || echo \"$tool=0\"; done",
  ];
}

export function audioMonitorSourceCommand() {
  return [
    "bash",
    "-lc",
    "set -euo pipefail\nsink=\"$(pactl get-default-sink 2>/dev/null)\"\n[ -n \"$sink\" ]\nmonitor=\"$sink.monitor\"\npactl list sources short | cut -f2 | grep -Fx \"$monitor\"",
  ];
}

export function screenshotClipboardCommand() {
  return [
    "bash",
    "-lc",
    "set -euo pipefail\n(\n    file=\"$(mktemp \"${XDG_RUNTIME_DIR:-/tmp}/niri-screenshot-XXXXXX.png\")\"\n    rm -f \"$file\"\n    niri msg action screenshot --path \"$file\"\n    for _ in $(seq 1 900); do\n        if [ -s \"$file\" ]; then\n            wl-copy --type image/png < \"$file\"\n            rm -f \"$file\"\n            exit 0\n        fi\n        sleep 0.1\n    done\n    rm -f \"$file\"\n) >/dev/null 2>&1 </dev/null &",
  ];
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, "'\\''")}'`;
}

function recordingStartScript({ mode = "output", audioEnabled = false, audioMonitorSource = "" } = {}) {
  const normalizedMode = mode === "region" ? "region" : "output";
  const audioSource = parseAudioMonitorSource(audioMonitorSource);
  const audioArg = audioEnabled && audioSource.length > 0 ? ` --audio=${shellQuote(audioSource)}` : "";
  const basename = normalizedMode === "region" ? "recording-region" : "recording";
  const target = normalizedMode === "region"
    ? `geometry="$(slurp)"
[ -n "$geometry" ]
printf 'file=%s\\n' "$file"
exec wf-recorder -g "$geometry"${audioArg} -f "$file"`
    : `output="$(niri msg --json focused-output | sed -n 's/.*"name":"\\([^"]*\\)".*/\\1/p')"
[ -n "$output" ]
printf 'file=%s\\n' "$file"
exec wf-recorder -o "$output"${audioArg} -f "$file"`;

  return `set -euo pipefail
dir="$HOME/Videos/Screen Recordings"
mkdir -p "$dir"
file="$dir/${basename}-$(date +%Y%m%d-%H%M%S).mp4"
${target}`;
}

export function recordingStartCommand(options = {}) {
  return [
    "bash",
    "-lc",
    recordingStartScript({ ...options, mode: options.mode ?? "output" }),
  ];
}

export function regionRecordingStartCommand(options = {}) {
  return [
    "bash",
    "-lc",
    recordingStartScript({ ...options, mode: "region" }),
  ];
}

export function regionRecordingMonitorCommand() {
  return [
    "bash",
    "-lc",
    "if pgrep -x wf-recorder >/dev/null 2>&1; then echo recording; elif pgrep -x slurp >/dev/null 2>&1; then echo selecting; else exit 1; fi",
  ];
}

export function recordingStopMonitorCommand() {
  return [
    "bash",
    "-lc",
    "pgrep -x wf-recorder >/dev/null 2>&1 || pgrep -x slurp >/dev/null 2>&1",
  ];
}

export function recordingStopCommand() {
  return [
    "bash",
    "-lc",
    "pkill -INT wf-recorder >/dev/null 2>&1 || true\npkill -TERM slurp >/dev/null 2>&1 || true",
  ];
}

export function reduceRecordingState(state, event) {
  if (state === "idle" && event === "startRegion")
    return "selectingRegion";
  if (state === "selectingRegion" && event === "regionSelected")
    return "recordingRegion";
  if (state === "idle" && event === "startOutput")
    return "recordingOutput";
  if ((state === "recordingRegion" || state === "recordingOutput") && event === "stop")
    return "stopping";
  if ((state === "recordingRegion" || state === "recordingOutput") && event === "backendExited")
    return "idle";
  if (state === "stopping" && event === "stopped")
    return "idle";
  if (state === "selectingRegion" && event === "cancel")
    return "idle";
  if (event === "fail")
    return "error";
  return state;
}
