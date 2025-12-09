import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SirenManager
import "components"

ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 700
    title: "SirenManager - Contrôle des Sirènes Mecaviv"

    // Background
    color: "#1e1e1e"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // TabBar avec les 10 onglets
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: 0
            
            background: Rectangle {
                color: "#2a2a2a"
            }

            TabButton {
                text: "PLAYER"
            }
            TabButton {
                text: "MIXAGE"
            }
            TabButton {
                text: "SIRENIUM"
            }
            TabButton {
                text: "MAINTENANCE"
            }
            TabButton {
                text: "CONTROLEURS"
            }
            TabButton {
                text: "PIANO"
            }
            TabButton {
                text: "VOITURES"
            }
            TabButton {
                text: "PAVILLONS"
            }
            TabButton {
                text: "SYSTÈME"
            }
            TabButton {
                text: "PLAYLISTS"
            }
        }

        // StackLayout pour afficher la vue correspondante
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Loader {
                source: "views/PlayerView.qml"
            }

            Loader {
                source: "views/MixerView.qml"
            }

            Loader {
                source: "views/SireniumView.qml"
            }

            Loader {
                source: "views/MaintenanceView.qml"
            }

            Loader {
                source: "views/ControleurView.qml"
            }

            Loader {
                source: "views/PianoView.qml"
            }

            Loader {
                source: "views/VoitureView.qml"
            }

            Loader {
                source: "views/PavillonView.qml"
            }

            Loader {
                source: "views/SystemMaintenanceView.qml"
            }

            Loader {
                source: "views/PlaylistComposerView.qml"
            }
        }
    }
}

