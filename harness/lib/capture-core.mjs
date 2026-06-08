export function parseCaptureToolProbe(text) {
  const tools = {
    grim: false,
    niri: false,
    slurp: false,
    wlCopy: false,
    wfRecorder: false,
  };

  for (const rawLine of String(text ?? "").split("\n")) {
    const [name, value] = rawLine.trim().split("=");
    const available = value === "1";

    if (name === "grim")
      tools.grim = available;
    else if (name === "niri")
      tools.niri = available;
    else if (name === "slurp")
      tools.slurp = available;
    else if (name === "wl-copy")
      tools.wlCopy = available;
    else if (name === "wf-recorder")
      tools.wfRecorder = available;
  }

  return tools;
}

export function screenshotAvailable(tools) {
  return tools.niri === true && tools.wlCopy === true;
}

export function recordingAvailable(tools) {
  return tools.niri === true && tools.wfRecorder === true;
}

export function regionRecordingAvailable(tools) {
  return tools.slurp === true && tools.wfRecorder === true;
}

export function captureToolProbeCommand() {
  return [
    "sh",
    "-c",
    "for tool in grim niri slurp wl-copy wf-recorder; do command -v \"$tool\" >/dev/null 2>&1 && echo \"$tool=1\" || echo \"$tool=0\"; done",
  ];
}

export function screenshotClipboardCommand() {
  return [
    "bash",
    "-lc",
    "set -euo pipefail\n(\n    file=\"$(mktemp \"${XDG_RUNTIME_DIR:-/tmp}/niri-screenshot-XXXXXX.png\")\"\n    rm -f \"$file\"\n    niri msg action screenshot --path \"$file\"\n    for _ in $(seq 1 900); do\n        if [ -s \"$file\" ]; then\n            wl-copy --type image/png < \"$file\"\n            rm -f \"$file\"\n            exit 0\n        fi\n        sleep 0.1\n    done\n    rm -f \"$file\"\n) >/dev/null 2>&1 </dev/null &",
  ];
}

export function recordingStartCommand() {
  return [
    "bash",
    "-lc",
    "set -euo pipefail\ndir=\"$HOME/Videos/Screen Recordings\"\nmkdir -p \"$dir\"\nfile=\"$dir/recording-$(date +%Y%m%d-%H%M%S).mp4\"\noutput=\"$(niri msg --json focused-output | sed -n 's/.*\"name\":\"\\([^\"]*\\)\".*/\\1/p')\"\n[ -n \"$output\" ]\nwf-recorder -o \"$output\" -f \"$file\"",
  ];
}

export function regionRecordingStartCommand() {
  return [
    "bash",
    "-lc",
    "set -euo pipefail\ndir=\"$HOME/Videos/Screen Recordings\"\nmkdir -p \"$dir\"\nfile=\"$dir/recording-region-$(date +%Y%m%d-%H%M%S).mp4\"\ngeometry=\"$(slurp)\"\n[ -n \"$geometry\" ]\nexec wf-recorder -g \"$geometry\" -f \"$file\"",
  ];
}

export function regionRecordingMonitorCommand() {
  return [
    "bash",
    "-lc",
    "pgrep -x slurp >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1",
  ];
}

export function recordingStopCommand() {
  return [
    "bash",
    "-lc",
    "pkill -INT wf-recorder >/dev/null 2>&1 || true\npkill -TERM slurp >/dev/null 2>&1 || true",
  ];
}
