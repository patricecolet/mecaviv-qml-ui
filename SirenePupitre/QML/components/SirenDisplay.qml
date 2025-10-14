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
        
        configController.setValueAtPath(["sirenConfig", "currentSiren"], sirenId)
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
                y: 270 // Position haute fixe
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
            
            // Mode Jeu (à l'intérieur du View3D)
                GameMode {
                    id: gameModeComponent
                    configController: root.configController
                    sirenInfo: root.sirenInfo
                    currentNoteMidi: root.clampedNote
                    isGameModeActive: root.gameMode  // Lier au mode jeu
                    staffWidth: 1600
                }                
                // Compteur de notes type speedometer vintage
                NoteSpeedometer3D {
                    currentNoteMidi: root.clampedNote
                    ambitusMin: root.sirenInfo ? root.sirenInfo.ambitus.min : 43
                    ambitusMax: root.sirenInfo ? root.sirenInfo.ambitus.max : 86
                    
                    // Position TOUT EN HAUT
                    position: Qt.vector3d(0, 400, 100)
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
                    var currentId = configController.config.sirenConfig.currentSiren
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
            
            // Indicateur du mode fretté
            Rectangle {
                width: 120
                height: 35
                radius: 15
                color: {
                    if (!configController) return "#666666"
                    var dummy = configController.updateCounter // Force la réévaluation
                    var currentSirenId = configController.getValueAtPath(["sirenConfig", "currentSiren"], "1")
                    var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                        return siren.id === currentSirenId
                    })?.frettedMode?.enabled || false
                    return frettedModeEnabled ? "#FFD700" : "#666666"
                }
                border.color: {
                    if (!configController) return "#888888"
                    var dummy = configController.updateCounter // Force la réévaluation
                    var currentSirenId = configController.getValueAtPath(["sirenConfig", "currentSiren"], "1")
                    var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                        return siren.id === currentSirenId
                    })?.frettedMode?.enabled || false
                    return frettedModeEnabled ? "#FFA500" : "#888888"
                }
                border.width: 2
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.top: parent.top
                anchors.topMargin: 150
                visible: {
                    if (!configController) return true
                    var dummy = configController.updateCounter
                    return configController.isComponentVisible("sirenCircle")
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "FRETTÉ"
                    font.pixelSize: 14
                    font.bold: true
                    color: {
                        if (!configController) return "#CCCCCC"
                        var dummy = configController.updateCounter // Force la réévaluation
                        var currentSirenId = configController.getValueAtPath(["sirenConfig", "currentSiren"], "1")
                        var frettedModeEnabled = configController.getValueAtPath(["sirenConfig", "sirens"], []).find(function(siren) {
                            return siren.id === currentSirenId
                        })?.frettedMode?.enabled || false
                        return frettedModeEnabled ? "#000000" : "#CCCCCC"
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (configController) {
                            var currentSirenId = configController.getValueAtPath(["sirenConfig", "currentSiren"], "1")
                            var sirens = configController.getValueAtPath(["sirenConfig", "sirens"], [])
                            var currentSiren = sirens.find(function(siren) {
                                return siren.id === currentSirenId
                            })
                            
                            if (currentSiren) {
                                var currentValue = currentSiren.frettedMode?.enabled || false
                                
                                // Trouver l'index de la sirène dans le tableau
                                var sirenIndex = sirens.findIndex(function(siren) {
                                    return siren.id === currentSirenId
                                })
                                
                                if (sirenIndex >= 0) {
                                    var newValue = !currentValue
                                    var success = configController.setValueAtPath(["sirenConfig", "sirens", sirenIndex, "frettedMode", "enabled"], newValue)
                                    
                                    // Vérifier immédiatement si la valeur a changé
                                    var updatedSirens = configController.getValueAtPath(["sirenConfig", "sirens"], [])
                                    var updatedSiren = updatedSirens[sirenIndex]
                                }
                            } else {
                            }
                        } else {
                        }
                    }
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
    }
}
