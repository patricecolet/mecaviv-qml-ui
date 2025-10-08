// Configuration SirenConsole
// Configuration des pupitres et presets

const config = {
    // Configuration des pupitres (7 pupitres max)
    pupitres: [
        {
            id: 1,
            name: "Sirene 1",
            host: "192.168.1.101",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 }, // C3 à C6
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60, // C4
            status: "disconnected"
        },
        {
            id: 2,
            name: "Sirene 2",
            host: "192.168.1.102",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 },
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60,
            status: "disconnected"
        },
        {
            id: 3,
            name: "Sirene 3",
            host: "192.168.1.103",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 },
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60,
            status: "disconnected"
        },
        {
            id: 4,
            name: "Sirene 4",
            host: "192.168.1.104",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 },
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60,
            status: "disconnected"
        },
        {
            id: 5,
            name: "Sirene 5",
            host: "192.168.1.105",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 },
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60,
            status: "disconnected"
        },
        {
            id: 6,
            name: "Sirene 6",
            host: "192.168.1.106",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 },
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60,
            status: "disconnected"
        },
        {
            id: 7,
            name: "Sirene 7",
            host: "192.168.1.107",
            port: 8000,
            websocketPort: 10001,
            enabled: true,
            ambitus: { min: 48, max: 72 },
            frettedMode: false,
            motorSpeed: 0,
            frequency: 440,
            midiNote: 60,
            status: "disconnected"
        }
    ],
    
    // Presets de configuration
    presets: {
        "Concert Standard": {
            description: "Configuration standard pour concert",
            sirenConfig: {
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
            sirenConfig: {
                frettedMode: true
            }
        },
        "Ambitus Étendu": {
            description: "Ambitus étendu pour plus de notes",
            sirenConfig: {
                ambitus: { min: 36, max: 84 } // C2 à C7
            }
        },
        "Mode Test": {
            description: "Configuration pour les tests",
            sirenConfig: {
                ambitus: { min: 60, max: 72 }, // C4 à C6
                frettedMode: true,
                uiScale: 1.2
            },
            uiConfig: {
                controllersPanelVisible: false,
                adminMode: true
            }
        }
    },
    
    // Configuration de l'interface
    ui: {
        fullScreen: false,
        currentPage: 0, // 0=Overview, 1=Config, 2=Logs
        theme: "dark",
        autoConnect: true,
        reconnectInterval: 5000 // ms
    },
    
    // Configuration des couleurs
    colors: {
        background: "#1a1a1a",
        surface: "#2a2a2a",
        primary: "#00ff00",
        secondary: "#ff6b6b",
        accent: "#ffaa00",
        text: "#ffffff",
        textSecondary: "#cccccc"
    }
}

// Export pour Node.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = config
}