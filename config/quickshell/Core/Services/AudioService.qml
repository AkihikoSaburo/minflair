import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: audioService

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasPhysicalMic: source !== null && source.audio !== null && (source.name ? !source.name.endsWith(".monitor") : true)
    readonly property int micVolume: (source && source.audio) ? Math.round(source.audio.volume * 100) : 0
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : true

    function updateMicStatus() {
    }

    function setMicVolume(val) {
        if (!hasPhysicalMic || !source || !source.audio)
            return ;

        let normalized = Math.max(0, Math.min(100, val)) / 100;
        source.audio.volume = normalized;
    }

    function setMicMuted(state) {
        if (!hasPhysicalMic || !source || !source.audio)
            return ;

        source.audio.muted = state;
    }

    onMicMutedChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onMicVolumeChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }

}
