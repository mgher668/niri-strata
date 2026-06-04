# niri-strata

A Quickshell bar and Material You control center for the
[niri](https://github.com/YaLTeR/niri) compositor.

It includes a multi-output bar, system tray, notification center, quick
settings, and hardware/service panels.

## Status

This is a personal desktop shell that is being shaped into a reusable project.
It is tested on Arch Linux with niri, Quickshell, PipeWire, NetworkManager, and
BlueZ. Other setups may need small service or dependency changes.

## Features

- Floating top or bottom bar with per-output workspace indicators.
- niri workspace sorting by output and workspace index.
- Active window title, clock with seconds, resource usage, battery, network,
  audio, and system tray modules.
- Tray pin/overflow policy with IPC toggle support.
- Right-side Material You control center.
- Notification ownership, notification toasts, and swipe-to-dismiss cards.
- Wi-Fi scan/connect/disconnect with password prompt for new protected
  networks.
- VPN profile status and connect/disconnect actions through NetworkManager.
- Bluetooth device list and connect/disconnect actions through BlueZ.
- PipeWire audio mixer for output, input, devices, and streams.
- MPRIS media controls.
- Brightness control for DDC/CI displays through `ddcutil`.
- Night mode/color temperature through `wl-gammarelay-rs`.
- Screenshot-to-clipboard and focused-output recording shortcuts.
- Lock, logout, suspend, reboot, and shutdown actions with confirmation for
  destructive session actions.
- Harness tests for the niri data model and service command boundaries.

## Requirements

Core runtime:

- [niri](https://github.com/YaLTeR/niri)
- [Quickshell](https://quickshell.org)
- Qt 6 matching the installed Quickshell build
- Material Symbols Rounded font
- Barlow font

Service backends:

- PipeWire and WirePlumber for audio.
- NetworkManager for Wi-Fi and VPN.
- BlueZ for Bluetooth.
- UPower for battery information.
- power-profiles-daemon for power profiles.

Optional tools:

- `ddcutil` for external monitor brightness.
- `wl-gammarelay-rs` for night mode/color temperature.
- `wl-clipboard` for screenshot clipboard copy.
- `wf-recorder` for screen recording.
- `swaylock` for lock screen actions.

On Arch Linux, the useful package set is roughly:

```sh
sudo pacman -S quickshell niri pipewire wireplumber pipewire-pulse \
  networkmanager bluez bluez-utils upower power-profiles-daemon \
  ddcutil wl-clipboard wf-recorder swaylock ttf-barlow
```

Install Material Symbols Rounded separately if your package source does not
provide it. Confirm with:

```sh
fc-match "Material Symbols Rounded"
```

## Install

Clone the repository as a Quickshell config directory:

```sh
git clone https://github.com/mgher/niri-strata ~/.config/quickshell/niri-strata
quickshell --path ~/.config/quickshell/niri-strata --daemonize
```

If another notification daemon owns `org.freedesktop.Notifications`, stop or
disable it before relying on niri-strata notifications. Common examples are
`swaync`, `mako`, and `dunst`.

## niri Bindings

Example bindings for `~/.config/niri/config.kdl`:

```kdl
binds {
    Mod+Space {
        spawn "quickshell" "ipc" "--path" "~/.config/quickshell/niri-strata" "--newest" "call" "controlCenter" "toggle";
    }

    Mod+M {
        spawn "quickshell" "ipc" "--path" "~/.config/quickshell/niri-strata" "--newest" "call" "tray" "toggleBarIcons";
    }
}
```

Depending on your niri version and shell expansion behavior, replace `~` with
the absolute path to the config directory.

## IPC

Control center:

```sh
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call controlCenter toggle
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call controlCenter open
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call controlCenter close
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call controlCenter isOpen
```

Tray:

```sh
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call tray toggleBarIcons
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call tray showBarIcons
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call tray hideBarIcons
quickshell ipc --path ~/.config/quickshell/niri-strata --newest call tray debug
```

## Configuration

Most local settings live in:

- `modules/common/Config.qml`
- `modules/common/Theme.qml`
- `modules/bar/TrayConfig.qml`

The current config intentionally keeps the service layer small and explicit.
If a backend is missing, the related module should show an unavailable state
instead of crashing the shell.

## Development

Run the harness before changing niri state, service parsing, or command
construction logic:

```sh
npm run harness
```

The harness uses sanitized niri-shaped fixtures under
`harness/fixtures/live`. Do not commit real window titles, local paths, Wi-Fi
passwords, tokens, or other secrets into fixtures.

## References and Acknowledgements

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) inspired the
  broader control-center direction and visual ambition.
- [imiric/quickshell-niri](https://github.com/imiric/quickshell-niri) is a
  useful niri-focused Quickshell reference.

## License

MIT. See [LICENSE](./LICENSE).
