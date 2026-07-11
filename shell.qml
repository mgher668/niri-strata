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
import "./modules/settings/"
import "./modules/launcher/"

ShellRoot{
    id: shellRoot
    readonly property var niriStateService: niriState
    readonly property var commandPaletteService: commandPalette
    readonly property var sidebarControllerService: sidebarState
    readonly property var notificationService: notifications
    readonly property var systemActionsService: systemActions
    readonly property var resourceUsageService: resourceUsage
    readonly property var batteryStatusService: battery
    readonly property var wifiStatusService: wifi
    readonly property var bluetoothStatusService: bluetooth
    readonly property var audioStatusService: audio
    readonly property var mediaStatusService: media
    property bool sidebarLoaded: false

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

        onOpenChanged: {
            if (open)
                shellRoot.sidebarLoaded = true;
        }
    }

    AppSearch {
        id: appSearch
    }

    CommandPalette {
        id: commandPalette
        appSearch: appSearch
        systemActions: systemActions
        sidebarController: sidebarState
        settingsController: settingsController
    }

    TrayState {
        id: trayStateService
    }

    SettingsController {
        id: settingsController
    }
    ThemeEngine {
        id: themeEngine

        onPaletteReady: function(palette) {
            Theme._dynamicPalette = palette;
        }
    }
    ThemeExport {
        id: themeExport
    }

    AutoThemeBridge {
        id: autoThemeBridge
    }

    Timer {
        id: autoThemeLauncher
        interval: 2000
        repeat: false
        running: true
        onTriggered: {
            var xdg = Quickshell.env("XDG_CONFIG_HOME");
            var home = Quickshell.env("HOME");
            var base = (xdg && xdg.length > 0) ? xdg : (home + "/.config");
            var dir = base + "/quickshell/niri-strata";
            Quickshell.execDetached(["sh", "-c", "mkdir -p " + dir + " && touch " + dir + "/auto-theme-state.json"]);
            var bin = home + "/.config/quickshell/niri-strata/target/release/niri-strata-auto-theme";
            Quickshell.execDetached([bin]);
        }
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void { sidebarState.toggleForOutput(""); }
        function open(): void { sidebarState.openForOutput(""); }
        function close(): void { sidebarState.close(); }
        function isOpen(): bool { return sidebarState.open; }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { commandPalette.toggle(); }
        function open(): void { commandPalette.openPalette(); }
        function close(): void { commandPalette.close(); }
        function isOpen(): bool { return commandPalette.open; }
    }

    IpcHandler {
        target: "tray"

        function toggleBarIcons(): string { return trayStateService.toggleBarIcons() ? "visible" : "hidden"; }
        function showBarIcons(): string { trayStateService.showBarIcons(); return "visible"; }
        function hideBarIcons(): string { trayStateService.hideBarIcons(); return "hidden"; }
        function barIconsVisible(): bool { return trayStateService.barIconsVisible; }
        function debug(): string { return trayStateService.debugSummary(); }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void { settingsController.toggle(""); }
        function open(): void { settingsController.openSettings(""); }
        function close(): void { settingsController.close(); }
        function isOpen(): bool { return settingsController.open; }
        function showTab(tabName: string): void { settingsController.showTab(tabName); }
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

    LazyLoader {
        active: shellRoot.sidebarLoaded

        component: Sidebar {
            controller: shellRoot.sidebarControllerService
            notificationService: shellRoot.notificationService
            systemActions: shellRoot.systemActionsService
            resourceService: shellRoot.resourceUsageService
            batteryService: shellRoot.batteryStatusService
            wifiService: shellRoot.wifiStatusService
            bluetoothService: shellRoot.bluetoothStatusService
            audioService: shellRoot.audioStatusService
            mediaService: shellRoot.mediaStatusService
        }
    }

    LazyLoader {
        active: commandPalette.open

        component: Launcher {
            palette: shellRoot.commandPaletteService
            niriState: shellRoot.niriStateService
        }
    }

    LazyLoader {
        active: notifications.popupCount > 0

        component: NotificationToast {
            service: shellRoot.notificationService
            niriState: shellRoot.niriStateService
            sidebarController: shellRoot.sidebarControllerService
        }
    }

    LazyLoader {
        active: audio.osdVisible

        component: VolumeOsd {
            service: shellRoot.audioStatusService
        }
    }

    LazyLoader {
        active: settingsController.open

        component: SettingsWindow {
            controller: settingsController
            settingsData: SettingsData
            captureService: capture
        }
    }
}
