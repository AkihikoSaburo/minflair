import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Bar
import qs.Modules.Bar.Styles.Convex
import qs.Modules.Bar.Styles.Gaming

ShellRoot {
    id: root

    readonly property bool isGaming: DisplayProfileService.gameModeActive
    readonly property bool isConvex: SettingsService.barStyle === "convex"

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource, Pipewire.defaultAudioSink]
    }

    IpcHandler {
        function toggle(widgetId: string) {
            AppState.toggleWidget(widgetId);
        }

        function open(widgetId: string) {
            AppState.openWidget(widgetId);
        }

        function close(widgetId: string) {
            AppState.closeWidget(widgetId);
        }

        target: "widgets"
    }

    IpcHandler {
        function showVolume(volume: string, isMuted: string) {
            OsdService.displayVolume(volume, isMuted);
        }

        function showMic(isMuted: string) {
            OsdService.displayMic(isMuted);
        }

        function showBrightness(percent: string) {
            OsdService.displayBrightness(percent);
        }

        function showMessage(title: string, value: string, icon: string) {
            let active = (value === "ON" || value === "Enabled" || (value !== "OFF" && value !== "Disabled" && value !== "DESACTIVADO"));
            OsdService.displayMessage(title, value, icon, active);
        }

        target: "osd"
    }

    NotificationService {
        id: globalNotificationService
    }

    PanelWindow {
        id: barSurface

        readonly property int barHeight: BarStyleConfig.barHeight(SettingsService.barStyle)
        readonly property int barMarginTop: BarStyleConfig.barMarginTop(SettingsService.barStyle)
        readonly property int barMarginSide: BarStyleConfig.barMarginSide(SettingsService.barStyle)

        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"
        focusable: false
        implicitHeight: !SettingsService.settingsLoaded ? 0 : (barMarginTop + barHeight)
        visible: SettingsService.settingsLoaded && !root.isGaming

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
        }

    }

    PanelWindow {
        id: gamingBarSurface

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: Constants.size3Xl + 2
        color: Theme.bg
        focusable: false
        implicitHeight: Constants.size3Xl + 2
        visible: SettingsService.settingsLoaded && root.isGaming

        anchors {
            top: true
            left: true
            right: true
        }

        GamingBar {
            anchors.fill: parent
            notificationService: globalNotificationService
        }

    }

    BarOverlayWindow {
        notificationService: globalNotificationService
        barSurface: barSurface
        visible: SettingsService.settingsLoaded && !root.isConvex && !root.isGaming
    }

    ConvexDesktop {
        id: convexDesktopSurface

        notificationService: globalNotificationService
        visible: SettingsService.settingsLoaded && root.isConvex && !root.isGaming
    }

    GamingOverlay {
        id: gamingOverlaySurface

        notificationService: globalNotificationService
    }

    ShellModules {
        id: shellModules
    }

}
