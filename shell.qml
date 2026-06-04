//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Niri 0.1
import "./modules/common/"
import "./modules/bar/"
import "./modules/services/"
import "./modules/sidebar/"

ShellRoot{
    id: root

    Niri {
        id: niri
        Component.onCompleted: connect()

        onConnected: console.info("Connected to niri")
        onErrorOccurred: function(error) {
            console.error("Niri error:", error)
        }
    }

    NiriState {
        id: niriState
        niri: niri
    }

    DateTime {
        id: dateTime
    }

    Battery {
        id: battery
    }

    ResourceUsage {
        id: resourceUsage
    }

    Audio {
        id: audio
    }

    Network {
        id: network
    }

    Wifi {
        id: wifi
    }

    Bluetooth {
        id: bluetooth
    }

    Media {
        id: media
    }

    PowerProfiles {
        id: powerProfiles
    }

    Brightness {
        id: brightness
    }

    NightMode {
        id: nightMode
    }

    Capture {
        id: capture
    }

    Notifications {
        id: notifications
    }

    SystemActions {
        id: systemActions
        networkService: network
        wifiService: wifi
        bluetoothService: bluetooth
        audioService: audio
        notificationService: notifications
        powerProfilesService: powerProfiles
        brightnessService: brightness
        nightModeService: nightMode
        captureService: capture
    }

    SidebarController {
        id: sidebarState
        niriState: niriState
    }

    TrayState {
        id: trayStateService
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void { sidebarState.toggleForOutput(""); }
        function open(): void { sidebarState.openForOutput(""); }
        function close(): void { sidebarState.close(); }
        function isOpen(): bool { return sidebarState.open; }
    }

    IpcHandler {
        target: "tray"

        function toggleBarIcons(): string { return trayStateService.toggleBarIcons() ? "visible" : "hidden"; }
        function showBarIcons(): string { trayStateService.showBarIcons(); return "visible"; }
        function hideBarIcons(): string { trayStateService.hideBarIcons(); return "hidden"; }
        function barIconsVisible(): bool { return trayStateService.barIconsVisible; }
        function debug(): string { return trayStateService.debugSummary(); }
    }

    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property ShellScreen modelData

            barScreen: modelData
            state: niriState
            clockService: dateTime
            batteryService: battery
            resourceService: resourceUsage
            audioService: audio
            networkService: network
            sidebarController: sidebarState
            trayState: trayStateService
        }
    }

    Sidebar {
        controller: sidebarState
        notificationService: notifications
        systemActions: systemActions
        resourceService: resourceUsage
        batteryService: battery
        wifiService: wifi
        bluetoothService: bluetooth
        audioService: audio
        mediaService: media
    }

    NotificationToast {
        service: notifications
        niriState: niriState
        sidebarController: sidebarState
    }

    VolumeOsd {
        service: audio
    }
}
