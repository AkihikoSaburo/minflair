import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Core
import qs.Core.Components

ThemedSlider {
    id: root

    property int brightness: 0
    property bool isVisible: true
    property int _pendingBrightness: 0

    function setBrightness(val) {
        let finalVal = Math.max(5, val);
        root.brightness = finalVal;
        root._pendingBrightness = finalVal;
        if (!brightnessThrottleTimer.running)
            brightnessThrottleTimer.start();

    }

    value: root.brightness
    icon: "sun"
    onMoved: (val) => {
        return root.setBrightness(val);
    }
    onIconClicked: {
        let target = (root.brightness <= 5) ? 100 : 5;
        root.brightness = target;
        root._pendingBrightness = target;
        brightSetProc.command = ["brightnessctl", "s", target + "%"];
        brightSetProc.running = true;
    }

    Timer {
        id: brightnessThrottleTimer

        interval: 35
        repeat: false
        onTriggered: {
            if (!brightSetProc.running) {
                brightSetProc.command = ["brightnessctl", "s", root._pendingBrightness + "%"];
                brightSetProc.running = true;
            } else {
                brightnessThrottleTimer.restart();
            }
        }
    }

    Timer {
        interval: 250
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: brightGetProc.running = true
    }

    Process {
        id: brightGetProc

        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var parts = data.split(",");
                if (parts.length >= 4) {
                    var pct = parts[3];
                    if (pct.endsWith("%"))
                        pct = pct.substring(0, pct.length - 1);

                    if (!root.pressed)
                        root.brightness = parseInt(pct);

                }
            }
        }

    }

    Process {
        id: brightSetProc
    }

}
