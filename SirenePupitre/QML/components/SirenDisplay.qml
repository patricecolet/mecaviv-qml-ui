import QtQuick
import QtQuick3D
import QtQuick.Controls
import "../utils"
import "../components"
import "./ambitus"
import "../game"

Item {
    id: root
    
    // Propriétés reçues de Main
    property var sirenController: null
    property var sirenInfo: null
    property var configController: null
    
    // Propriété pour le mode jeu
    property bool gameMode: false
    property alias gameModeComponent: gameModeComponent  // Exposer le GameMode pour les connexions externes
    
    // Propriétés calculées depuis sirenController
    property real rpm: sirenController ? sirenController.trueRpm : 0  // Vraies valeurs
    property real midiNote: sirenController ? sirenController.midiNote : 69.0
    property real clampedNote: sirenController ? sirenController.clampedNote : 69.0
    property string noteName: sirenController ? sirenController.trueNoteName : "La4"  // Vrai nom
    
    property color accentColor: "#00CED1"
    // Facteur d'échelle UI (réduction uniforme des éléments 3D)
    property real uiScale: {
        if (!configController) return 0.8
        var dummy = configController.updateCounter // Force la réévaluation
        var scale = configController.getValueAtPath(["ui", "scale"], 0.8)
        return scale
    }
    // Approximation de la largeur projetée de la portée en pixels (centrée)
    property real staffPixelWidth: 1600 * uiScale
    
    // Fonction pour mettre à jour les contrôleurs
    function updateControllers(controllersData) {
        controllersPanel.updateControllers(controllersData)
        
        // Mettre à jour la position GearShift pour l'ambitus
        if (controllersData.gearShift) {
            var newPosition = controllersData.gearShift.position || 0
            configController.gearShiftPosition = newPosition
        }
    }
    
    // Fonction pour changer de sirène
    function changeSiren(sirenId) {
        if (!configController || !configController.config) {
            return
        }
        
        configController.setValueAtPath(["sirenConfig", "currentSirens"], [sirenId])
    }
    
    // Fonction pour transmettre les événements MIDI au mode jeu
    function sendMidiEventToGame(event) {
        if (gameMode && gameModeComponent) {
            gameModeComponent.midiEventReceived(event)
        }
    }
    
    // Instance de MusicUtils
    MusicUtils {
        id: musicUtils
    }
    
    // Propriété calculée pour la fréquence avec transposition (vraie valeur)
    property int frequency: sirenController ? sirenController.trueFrequency : 0
    
    
    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
        
        // Vue 3D unique pour tout
        View3D {
            id: mainView3D
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            
            environment: SceneEnvironment {
                clearColor: "#0a0a0a"
                backgroundMode: SceneEnvironment.Color
                antialiasingMode: SceneEnvironment.SSAA
                antialiasingQuality: SceneEnvironment.High
            }
            
            // Éclairage global pour uniformiser l'éclairage des pyramides attack/release
            
            // Lumière principale depuis le haut (éclaire vers le bas)
            DirectionalLight {
                position: Qt.vector3d(0, 0, -50)  // Même Z que les cubes
                eulerRotation.x: -45  // Pointe vers le bas
                eulerRotation.y: 0
                brightness: 1.0
                ambientColor: Qt.rgba(0.3, 0.3, 0.3, 1.0)
            }
            
            // Lumière depuis le bas (éclaire vers le haut) pour la pyramide attack
            DirectionalLight {
                position: Qt.vector3d(0, 0, -50)  // Même Z que les cubes
                eulerRotation.x: 45  // Pointe vers le haut
                eulerRotation.y: 0
                brightness: 0.8  // Moins forte que celle du haut
                ambientColor: Qt.rgba(0.2, 0.2, 0.2, 1.0)
            }
            
            // Lumière frontale pour uniformiser
            DirectionalLight {
                position: Qt.vector3d(0, 0, -50)  // Même Z que les cubes
                eulerRotation.x: 0  // Frontale
                eulerRotation.y: 0
                brightness: 0.5
                ambientColor: Qt.rgba(0.3, 0.3, 0.3, 1.0)
            }
            
            PerspectiveCamera {
                position: {
                    // Forcer la mise à jour avec updateCounter
                    if (configController) {
                        var dummy = configController.updateCounter
                    }
                    if (configController && configController.config && configController.config.displayConfig && configController.config.displayConfig.camera) {
                        var cam = configController.config.displayConfig.camera.position
                        return Qt.vector3d(cam[0], cam[1], cam[2])
                    }
                    return Qt.vector3d(0, 0, 1500)  // Valeur par défaut
                }
                eulerRotation.x: 0
                fieldOfView: {
                    // Forcer la mise à jour avec updateCounter
                    if (configController) {
                        var dummy = configController.updateCounter
                    }
                    if (configController && configController.config && configController.config.displayConfig && configController.config.displayConfig.camera) {
                        return configController.config.displayConfig.camera.fieldOfView
                    }
                    return 27  // Valeur par défaut
                }
                clipFar: 5000
                clipNear: 1
            }
            
            // Lumières principales (réduites à 3)
            DirectionalLight {
                eulerRotation.x: -30
                eulerRotation.y: -70
                brightness: 1.5
                color: Qt.rgba(1, 1, 1, 1)
            }
            
            DirectionalLight {
                eulerRotation.x: 30
                eulerRotation.y: 70
                brightness: 0.8
                color: Qt.rgba(1, 1, 1, 1)
            }
            
            // Lumière ambiante simulée
            DirectionalLight {
                eulerRotation.x: 0
                eulerRotation.y: 0
                brightness: 0.3
                color: Qt.rgba(1, 1, 1, 1)
                castsShadow: false
            }
            
            // Zone supérieure - Afficheurs numériques
            Node {
                y: root.gameMode ? -270 : 270
                scale: Qt.vector3d(1.5 * root.uiScale, 1.5 * root.uiScale, 1.5 * root.uiScale)
                
                NumberDisplay3D {
                    x: -250
                    y: 20
                    visible: configController ? configController.isComponentVisible("rpm") : true
                    scaleX: 2 * root.uiScale
                    scaleY: 0.8 * root.uiScale
                    value: root.rpm
                    digitColor: root.accentColor
                    inactiveColor: "#003333"
                    frameColor: root.accentColor
                    label: "RPM"
                }
                
                NumberDisplay3D {
                    x: 250
                    y: 20
                    visible: configController ? configController.isComponentVisible("frequency") : true
                    scaleX: 1.8 * root.uiScale
                    scaleY: 0.7 * root.uiScale
                    value: root.frequency
                    digitColor: root.accentColor
                    inactiveColor: "#003333"
                    frameColor: root.accentColor
                    label: "Hz"
                }
            }
            
            // Zone centrale - Portée musicale (toujours visible)
            Node {
                y: 0 // Position centrale fixe
                scale: Qt.vector3d(root.uiScale, root.uiScale, root.uiScale)
                
                MusicalStaff3D {
                    id: musicalStaff
                    currentNoteMidi: root.clampedNote
                    sirenInfo: root.sirenInfo
                    configController: root.configController  // AJOUTER pour les sous-composants
                    staffWidth: 1600
                    staffPosX: 0
                    visible: {  // GARDER pour la visibilité globale
                        if (!configController) return true
                        configController.updateCounter
                        return configController.isComponentVisible("musicalStaff")
                    }
                }
                
                // Mode Jeu (DANS le même Node scalé pour partager le référentiel)
                GameMode {
                    id: gameModeComponent
                    configController: root.configController
                    sirenInfo: root.sirenInfo
                    currentNoteMidi: root.clampedNote
                    isGameModeActive: root.gameMode
                    staffWidth: 1950
                    staffPosX: 10
                }
                
                // Compteur de notes type speedometer vintage
                NoteSpeedometer3D {
                    currentNoteMidi: root.clampedNote
                    ambitusMin: root.sirenInfo ? root.sirenInfo.ambitus.min : 43
                    ambitusMax: root.sirenInfo ? root.sirenInfo.ambitus.max : 86
                    gameMode: root.gameMode  // Passer le mode pour ajuster le cadre
                    
                    // Position TOUT EN HAUT (mode normal) ou EN BAS (mode jeu)
                    position: Qt.vector3d(0, root.gameMode ? -300 : 400, 100)
                }
            }
        }
        
        // Conteneur pour les éléments 2D
        Item {
            id: infoContainer
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            
            // Mode ADMIN - Menu déroulant pour sélectionner une sirène
            ComboBox {
                id: sirenSelector
                width: 80
                height: 40
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                visible: {
                    if (!configController) return false
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("sirenCircle") && configController.mode === "admin"
                }
                
                // Modèle des sirènes
                model: configController && configController.config ? configController.config.sirenConfig.sirens : []
                textRole: "name"
                valueRole: "id"
                
                // Index actuel basé sur la sirène sélectionnée
                currentIndex: {
                    if (!configController || !configController.config) return 0
                    var list = configController.config.sirenConfig.currentSirens || []
                    var currentId = list.length > 0 ? list[0] : null
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].id === currentId) {
                            return i
                        }
                    }
                    return 0
                }
                
                onActivated: function(index) {
                    if (configController && configController.config && index >= 0) {
                        var selectedSiren = configController.config.sirenConfig.sirens[index]
                        changeSiren(selectedSiren.id)
                    }
                }
                
                // Style personnalisé
                delegate: ItemDelegate {
                    width: sirenSelector.width
                    contentItem: Text {
                        text: modelData.name
                        color: "#ffffff"
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#3a3a3a" : "#2a2a2a"
                        border.color: root.accentColor
                        border.width: parent.hovered ? 1 : 0
                    }
                }
                
                contentItem: Text {
                    leftPadding: 10
                    rightPadding: sirenSelector.indicator.width + sirenSelector.spacing
                    text: sirenSelector.displayText
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff"
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: "#2a2a2a"
                    border.color: root.accentColor
                    border.width: 2
                    radius: 6
                }
                
                popup: Popup {
                    y: sirenSelector.height - 1
                    width: sirenSelector.width
                    implicitHeight: contentItem.implicitHeight
                    padding: 1
                    
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: sirenSelector.popup.visible ? sirenSelector.delegateModel : null
                        currentIndex: sirenSelector.highlightedIndex
                        
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }
                    
                    background: Rectangle {
                        color: "#2a2a2a"
                        border.color: root.accentColor
                        border.width: 1
                        radius: 6
                    }
                }
            }
            
            // Mode RESTRICTED - Beau label circulaire (non cliquable)
            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#2a2a2a"
                border.color: root.accentColor
                border.width: 2
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.top: parent.top
                anchors.topMargin: 80
                visible: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("sirenCircle") && configController.mode === "restricted"
                }
                
                Text {
                    anchors.centerIn: parent
                    text: sirenInfo ? sirenInfo.name : "S1"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#ffffff"
                }
            }
            
            // Encadré avec détails de la note (tout en haut au centre)
            Rectangle {
                width: 120
                height: 80
                radius: 10
                border.color: root.accentColor
                border.width: 1
                color: "#2a2a2a"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 50  // Tout en haut
                visible: false  // TEST: Caché pour tester le nouveau speedometer 3D
                
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    
                    // Nom de la note
                    Text {
                        text: root.noteName
                        font.pixelSize: 24
                        font.bold: true
                        color: root.accentColor
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    // Mode
                    Text {
                        text: configController ? configController.mode.toUpperCase() : "RESTRICTED"
                        font.pixelSize: 10
                        color: "#888"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    // Note MIDI
                    Text {
                        text: "MIDI: " + Math.round(root.midiNote)
                        font.pixelSize: 12
                        color: "#aaa"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            
            // Indicateur des positions GearShift (overlay 2D)
            GearShiftPositionIndicator {
                anchors.fill: parent
                visible: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.getConfigValue("displayConfig.components.musicalStaff.gearShiftIndicator.visible", true)
                }
                currentPosition: configController ? (configController.gearShiftPosition || 0) : 0
                configController: root.configController
                
            }
        }

        // Zone inférieure - Contrôleurs (peut être affiché/masqué)
        ControllersPanel {
            id: controllersPanel
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.35
            configController: root.configController
            visible: {
                if (!configController) return false
                configController.updateCounter // Force la réévaluation
                return configController.getValueAtPath(["controllersPanel", "visible"], false) && !root.gameMode
            }
        }
        
        // Panneau autonome (mode jeu uniquement)
        Loader {
            id: gameAutonomyPanelLoader
            active: root.gameMode
            visible: root.gameMode
            anchors.fill: parent
            source: "../game/GameAutonomyPanel.qml"
            
            onLoaded: {
                if (item) {
                    item.configController = root.configController;
                    // Connecter le panneau au mode jeu pour la réinitialisation lors du stop
                    item.gameMode = root.gameModeComponent;
                }
            }
        }
    }
}
