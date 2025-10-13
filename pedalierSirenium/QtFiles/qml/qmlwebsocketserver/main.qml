import QtQuick
import QtQuick.Window
import QtQuick3D
import QtQuick.Controls

import "./components/core"
import "./components/ui" 
import "./components/debug"
import "./components/controls"
import "./components/monitoring"
import "./components/monitoring/midi-display"
import "./controllers"
import "./utils"           // ← Pour Logger.qml (local)
import "../utils" as Utils // ← Pour VirtualKeyboard.qml (niveau supérieur)

Window {
    id: window
    width: 800
    height: 600
    visible: true
    color: "black"
    
    // Police Emoji globale
    FontLoader {
        id: emojiFont
        source: "qrc:/fonts/NotoEmoji-VariableFont_wght.ttf"
        onStatusChanged: {
            if (status === FontLoader.Ready) {
                console.log("✅ [Global] Police Emoji chargée:", name)
            }
        }
    }
    
    // Rendre la police accessible globalement
    readonly property string globalEmojiFont: emojiFont.name

    // Settings
    Settings {
        id: settings
    }

    // Contrôleurs
    SirenController {
        id: sirenController
        logger: logger
    }
    
    BeatController {
        id: beatController
        sirenController: sirenController
        logger: logger
        webSocketController: wsController
    }

    PedalConfigController {
        id: pedalConfigController
        logger: logger
        
        onConfigValueChanged: function(pedalId, sirenId, controller, value, presetName) {
            if (logger) logger.debug("PRESET", "Config changed:", pedalId, sirenId, controller, value);
            wsController.sendMessage({
                device: "SIREN_PEDALS",
                pedalConfigChange: {
                    pedalId: pedalId,
                    sirenId: sirenId,
                    controller: controller,
                    value: value
                }
            });
        }
    }
    
    // Contrôleur MIDI
    MidiMonitorController {
        id: midiMonitorController
        logger: logger
    }
    
    // Router de messages
    MessageRouter {
        id: messageRouter
        logger: logger
        sirenController: sirenController
        beatController: beatController
        pedalConfigController: pedalConfigController
        tempoControl: tempoControl
        sceneManager: sceneManager  // ← Ajouter cette ligne
    }

    // WebSocket Controller
    WebSocketController {
        id: wsController
        logger: logger
        mainWindow: window  // Ajout de cette ligne
        midiMonitorController: midiMonitorController
        onMessageReceived: function(message) {
            if (settings.debugWebSocket) {
                if (logger) logger.debug("WEBSOCKET", "🔍 Message reçu:", JSON.stringify(message, null, 2));
            }
        }
        
        onPathMessageReceived: function(path, value) {
            if (settings.debugWebSocket) {
                if (logger) logger.debug("WEBSOCKET", "Path:", JSON.stringify(path), "Value:", value);
            }
            messageRouter.routePathMessage(path, value);
        }
        
        onBatchReceived: function(batchType, data) {
            // if (logger) logger.debug("WEBSOCKET", "📦 Batch reçu type:", batchType);
            messageRouter.routeBatch(batchType, data);
        }
    }

    // Vue 3D principale
    View3D {
        id: view
        anchors.fill: parent
        camera: camera
        renderMode: View3D.Overlay
        visible: !debugPanelVisible // Masquer la vue 3D quand le panneau debug est visible

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 200, 800)
        }

        DirectionalLight {
            eulerRotation.x: -30
        }

        SirenView {
            id: sirenView
            sirenNodes: sirenController.sirenNodes
            sirenController: sirenController
            pedalConfigController: pedalConfigController
            webSocketController: wsController
            sirenSpecProvider: sirenSpecProvider
            visible: !debugPanelVisible && !sirenView.scenesMode
        }
    }
    
    // Contrôle de tempo (créé séparément)
    TempoControl {
        id: tempoControl
        tempo: 120
        
        onTempoChanged: {
            wsController.sendTempoChange(tempo);
        }
    }

    // Gestionnaire de scènes
    SceneManager {
        id: sceneManager
        anchors.centerIn: parent
        logger: logger
        webSocketController: wsController
        visible: sirenView.scenesMode
        z: 10001
        
        onSceneSelected: function(sceneId, sceneName) {
            if (logger) logger.info("SCENES", "🎵 Scène sélectionnée depuis interface:", sceneName, "ID:", sceneId)
            
            // Mettre à jour currentScene dans SceneManager
            sceneManager.currentScene = sceneId
            
            // Forcer la mise à jour de l'interface
            sceneManager.scenesVersion++
        }
        
        onPageChanged: function(newPage) {
            if (logger) logger.info("SCENES", "📄 Page changée depuis interface:", newPage)
        }
        
        Component.onCompleted: {
            // Connecter le SceneManager au MessageRouter après création
            messageRouter.sceneManager = sceneManager;
        }
    }
    
    // Contrôles en bas
    BottomControls {
        id: bottomControls
        wsController: wsController
        tempoControl: tempoControl
        sirenView: sirenView
        pedalConfigController: pedalConfigController
        sceneManager: sceneManager
        overlayContainer: overlayContainer
        logger: logger
        // Ajout du callback pour ouvrir/fermer le DebugPanel
        onDebugPanelToggle: debugPanelVisible = !debugPanelVisible
    }
    
    // Connexions
    Connections {
        target: sirenView
        function onKnobValueChanged(pedalId, sirenId, controllerIndex, value) {
            let controllerName = pedalConfigController.getControllerName(controllerIndex);
            pedalConfigController.setValue(pedalId, sirenId, controllerName, value);
        }
    }
    
    // Overlay container
    Item {
        id: overlayContainer
        anchors.fill: parent
        z: 100000

        // Bouton engrenage flottant en haut à gauche
        Button {
            id: debugPanelGearButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.topMargin: 20
            width: 40
            height: 40
            z: 10001
            onClicked: debugPanelVisible = !debugPanelVisible
            ToolTip.text: debugPanelVisible ? "Fermer le panneau de debug" : "Ouvrir le panneau de debug"
            background: Rectangle {
                color: "#111"
                radius: 8
                border.color: "#444"
                border.width: 1
            }
            contentItem: Image {
                source: "qrc:/qml/icons/settings.png"
                anchors.centerIn: parent
                width: 24
                height: 24
                fillMode: Image.PreserveAspectFit
            }
        }
    }
    
    // Créer le logger AVANT tout le reste
    Logger {
        id: logger
        Component.onCompleted: {
            if (logger) logger.info("INIT", "🚀 Logger initialisé dans main.qml");
            // Retirer les logs de test
            // logger.info("TEST", "Ceci est un message de test depuis main.qml !");
        }
    }
    
    // Panneau de debug (F12 pour toggle)
    DebugPanel {
        id: debugPanel
        logger: logger
        webSocketController: wsController
        midiMonitorController: midiMonitorController
        anchors.fill: parent
        visible: debugPanelVisible
        z: 100002
        onCloseRequested: debugPanelVisible = false
    }

    // Provider de spécifications pour les sirènes (chargé au démarrage)
    SirenSpecProvider {
        id: sirenSpecProvider
    }

    // Propriété pour la visibilité du DebugPanel
    property bool debugPanelVisible: false

    // Raccourci clavier
    Shortcut {
        sequence: "F12"
        onActivated: debugPanelVisible = !debugPanelVisible
    }
    
    // ========== CLAVIER VIRTUEL GLOBAL ==========
    Utils.VirtualKeyboard {  // ← Maintenant ça devrait marcher
        id: globalVirtualKeyboard
        visible: false
        z: 100010  // Au-dessus de debugPanel (100002)
        
        // Propriétés de positionnement
        property string position: "center"  // "top", "center", "bottom", "above-target"
        property Item targetComponent: null  // Composant de référence pour "above-target"
        
        // Positionnement dynamique
        x: {
            switch (position) {
                case "top":
                case "center": 
                case "bottom":
                    return (parent.width - width) / 2;  // Centré
                case "above-target":
                    return targetComponent ? 
                        targetComponent.mapToItem(parent, 0, 0).x + (targetComponent.width - width) / 2 : 
                        (parent.width - width) / 2;
                default:
                    return (parent.width - width) / 2;
            }
        }
        
        y: {
            switch (position) {
                case "top":
                    return 50;
                case "center":
                    return (parent.height - height) / 2;
                case "bottom":
                    return parent.height - height - 50;
                case "above-target":
                    return targetComponent ? 
                        targetComponent.mapToItem(parent, 0, 0).y - height - 20 : 
                        50;
                default:
                    return (parent.height - height) / 2;
            }
        }
        
        onOkClicked: {
            hideKeyboard();
        }
    }
    
    // Fonctions globales pour contrôler le clavier
    function showKeyboard(targetField, keyboardPosition = "center", referenceComponent = null) {
        globalVirtualKeyboard.targetField = targetField;
        globalVirtualKeyboard.position = keyboardPosition;
        globalVirtualKeyboard.targetComponent = referenceComponent;
        globalVirtualKeyboard.visible = true;
    }
    
    function hideKeyboard() {
        globalVirtualKeyboard.visible = false;
        globalVirtualKeyboard.targetField = null;
        globalVirtualKeyboard.targetComponent = null;
    }
    
    // UN SEUL Component.onCompleted qui fait tout
    Component.onCompleted: {
        if (logger) logger.info("INIT", "🚀 Component.onCompleted de main.qml exécuté");
        
        // Configuration des contrôleurs
        sirenController.webSocketController = wsController;
        beatController.webSocketController = wsController;
        sirenController.beatController = beatController;
        
        // Synchroniser les sirènes
        sirenController.sirenNodes = sirenView.sirenNodes;
        if (logger) logger.info("INIT", "✅ Sirènes synchronisées:", sirenController.sirenNodes.length);
        
        // Positionner le TempoControl dans le placeholder de BottomControls
        let placeholder = bottomControls.children[1];
        if (placeholder) {
            tempoControl.parent = placeholder;
            tempoControl.anchors.centerIn = placeholder;
        }
        
        // La demande du preset courant est maintenant gérée dans PedalPresetManager
    }

    // Placer juste avant BottomControls
    SireniumMonitor {
        id: sireniumMonitor
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomControls.top
        anchors.bottomMargin: 12
        height: 120
        z: 1000
        note: midiNote
        velocity: midiVelocity
        
        // Masquer quand le PedalConfigPanel est ouvert
        visible: !sirenView.configMode  // ← AJOUTER CETTE LIGNE
    }

    // Propriétés pour le monitoring MIDI
    property int midiNote: 0
    property int midiVelocity: 0
    property int midiBend: 8192

    // Synchronisation simple de l'affichage avec le contrôleur (cadencée si besoin)
    Connections {
        target: midiMonitorController
        function onMidiDataChanged(note, velocity, bend, channel) {
            midiNote = note;
            midiVelocity = velocity;
            midiBend = bend;
        }
    }
}
