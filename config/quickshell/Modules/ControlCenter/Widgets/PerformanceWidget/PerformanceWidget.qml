import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows

Card {
    id: root

    property string activeProfile: ""
    property var profilesList: ["balanced"]

    cardRadius: Constants.sizeSm
    useBorder: false
    backgroundColor: Theme.bgSecondary
    contentPadding: Constants.sizeLg

    Process {
        id: fetchProfileProcess
        command: ["python3", "-c", "import socket, json\ns = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\ntry:\n    s.connect('/var/run/DAMX.sock')\n    s.sendall(json.dumps({'command': 'get_thermal_profile'}).encode())\n    res = s.recv(4096)\n    print(res.decode())\nexcept Exception as e:\n    print(json.dumps({'success': False, 'error': str(e)}))\nfinally:\n    s.close()"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let response = JSON.parse(data.trim());
                    if (response.success && response.data) {
                        root.activeProfile = response.data.current;
                        if (response.data.available && response.data.available.length > 0) {
                            root.profilesList = response.data.available;
                        }
                    }
                } catch (e) {
                    console.log("Gagal mem-parsing balasan socket:", e);
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            fetchProfileProcess.running = true;
        }
    }

    Process {
        id: setProfileProcess
        property string targetProfile: ""
        command: ["python3", "-c", "import socket, json\ns = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\ntry:\n    s.connect('/var/run/DAMX.sock')\n    payload = {'command': 'set_thermal_profile', 'params': {'profile': '" + targetProfile + "'}}\n    s.sendall(json.dumps(payload).encode())\n    res = s.recv(4096)\n    print(res.decode())\nexcept Exception as e:\n    print(json.dumps({'success': False, 'error': str(e)}))\nfinally:\n    s.close()"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                fetchProfileProcess.running = true;
            } else {
                console.log("Gagal mengirim perintah set_thermal_profile ke socket.");
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Constants.sizeLg

        ThemedSelect {
            id: profileSelect

            label: "Performance Mode"
            comboWidth: 160
            model: root.profilesList
            
            Component.onCompleted: {
                updateSelectedIndex();
            }

            onActivated: (index) => {
                let selected = root.profilesList[index];
                setProfileProcess.targetProfile = selected;
                setProfileProcess.running = true;
            }

            Connections {
                target: root
                function onActiveProfileChanged() {
                    profileSelect.updateSelectedIndex();
                }
            }
            
            function updateSelectedIndex() {
                for (let i = 0; i < root.profilesList.length; i++) {
                    if (root.profilesList[i] === root.activeProfile) {
                        profileSelect.currentIndex = i;
                        return;
                    }
                }
                profileSelect.currentIndex = 0;
            }
        }
    }
}