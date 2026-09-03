// Configuration globale de l'application PedalierSirenium

// Configuration réseau
var websocketUrl = "ws://localhost:10000";
var httpPort = 8000;

// Configuration des sirènes
var sirens = {
    count: 7,
    colors: {
        active: "lime",
        inactive: "#404040",
        recording: "red",
        pedal: "#00ffff"
    }
};

// Configuration UI
var ui = {
    debugWebSocket: false,
    debugAnimations: false,
    knobSensitivity: {
        small: 0.3,
        medium: 0.5,
        large: 1.0
    }
};

// Export pour Node.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        websocketUrl: websocketUrl,
        httpPort: httpPort,
        sirens: sirens,
        ui: ui
    };
}
