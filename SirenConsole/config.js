// Configuration SirenConsole
// Cette configuration charge les données depuis config.json (source unique de vérité)
// et ajoute uniquement les données spécifiques à SirenConsole

const config = {
    // Configuration des pupitres - chargée depuis config.json
    // Les pupitres correspondent aux sirènes physiques définies dans config.json
    pupitres: [
        {
            id: "P1",
            name: "Pupitre 1",
            host: "192.168.1.41",
            port: 8000,
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        },
        {
            id: "P2",
            name: "Pupitre 2",
            host: "localhost",
            port: 8000,
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        },
        {
            id: "P3",
            name: "Pupitre 3", 
            host: "192.168.1.43",
            port: 8000,
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        },
        {
            id: "P4",
            name: "Pupitre 4",
            host: "192.168.1.44", 
            port: 8000,
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        },
        {
            id: "P5",
            name: "Pupitre 5",
            host: "192.168.1.45",
            port: 8000, 
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        },
        {
            id: "P6",
            name: "Pupitre 6",
            host: "192.168.1.46",
            port: 8000,
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        },
        {
            id: "P7",
            name: "Pupitre 7",
            host: "192.168.1.47",
            port: 8000,
            websocketPort: 10002,
            enabled: true,
            status: "disconnected"
        }
    ],
    
    // Configuration spécifique à SirenConsole (pas dans config.json)
    ui: {
        fullScreen: false,
        currentPage: 0, // 0=Overview, 1=Config, 2=Logs
        theme: "dark",
        autoConnect: false,
        reconnectInterval: 5000, // ms
        showSirenAssignment: true,
        showPupitreStatus: true,
        showControllerMapping: true
    },
    
    // Presets de configuration (spécifiques à SirenConsole)
    presets: {
        "Concert Standard": {
            description: "Configuration standard pour concert",
            pupitreConfig: {
                ambitus: { min: 48, max: 72 },
                frettedMode: false,
                uiScale: 1.0
            },
            uiConfig: {
                controllersPanelVisible: true,
                adminMode: false
            }
        },
        "Mode Fretté": {
            description: "Tous les pupitres en mode fretté",
            pupitreConfig: {
                frettedMode: true
            }
        },
        "Ambitus Étendu": {
            description: "Ambitus étendu pour plus de notes",
            pupitreConfig: {
                ambitus: { min: 36, max: 84 }
            }
        },
        "Mode Test": {
            description: "Configuration pour les tests",
            pupitreConfig: {
                ambitus: { min: 60, max: 72 },
                frettedMode: true,
                uiScale: 1.2
            },
            uiConfig: {
                controllersPanelVisible: false,
                adminMode: true
            }
        }
    },
    
    // Configuration des couleurs (spécifique à SirenConsole)
    colors: {
        background: "#1a1a1a",
        surface: "#2a2a2a",
        primary: "#00ff00",
        secondary: "#ff6b6b",
        accent: "#ffaa00",
        text: "#ffffff",
        textSecondary: "#cccccc",
        pupitre: "#2E86AB",
        siren: "#F18F01",
        connected: "#00ff00",
        disconnected: "#ff6b6b",
        warning: "#ffaa00"
    },
    
    // Configuration des serveurs (pour puredata-proxy.js)
    servers: {
        websocket: {
            host: "192.168.1.41",
            port: 10002
        }
    },
    
    // Configuration de l'assignation des sirènes (spécifique à SirenConsole)
    sirenAssignment: {
        mode: "exclusive", // 1 sirène = 1 pupitre
        autoAssign: true,
        allowReassignment: true
    }
}

// Export pour Node.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = config
}