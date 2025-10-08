// Configuration globale de l'application PedalierSirenium

// Configuration réseau
var websocketUrl = "ws://localhost:10000";
var httpPort = 8000;

// Configuration des contrôleurs
var controllers = {
    definitions: {
        "volume":            { min: -100, max: 100, default: 0, unit: "%", label: "Volume", color: "#ffff66" },
        "vibratoSpeed":      { min: -100, max: 100, default: 0, unit: "%", label: "Speed", color: "#6699ff" },
        "vibratoDepth":      { min: -100, max: 100, default: 0, unit: "%", label: "Depth", color: "#6699ff" },
        "tremoloSpeed":      { min: -100, max: 100, default: 0, unit: "%", label: "Speed", color: "#ff9966" },
        "tremoloDepth":      { min: -100, max: 100, default: 0, unit: "%", label: "Depth", color: "#ff9966" },
        "attack":            { min: -100, max: 100, default: 0, unit: "%", label: "Attack", color: "#66ff99" },
        "release":           { min: -100, max: 100, default: 0, unit: "%", label: "Release", color: "#66ff99" },
        // Remis sur 'voice' conformément au projet
        "voice":             { min: -12, max: 12, default: 0, unit: "°", label: "Voice", color: "#ff66ff" }
    },
    
    order: [
        // Volume (section 1)
        "volume",
        // Vibrato (section 2) 
        "vibratoSpeed", "vibratoDepth",
        // Tremolo (section 3)
        "tremoloSpeed", "tremoloDepth", 
        // Enveloppe (section 4)
        "attack", "release",
        // Transpose (section 5)
        "voice"
    ],
    
    // ========== ORGANISATION VISUELLE ==========
    sections: [
        {
            name: "VOLUME",
            controllers: ["volume"],
            color: "#ffff66",
            label: "VOLUME"
        },
        {
            name: "VIBRATO", 
            controllers: ["vibratoSpeed", "vibratoDepth"],
            color: "#6699ff",
            label: "VIBRATO"
        },
        {
            name: "TREMOLO",
            controllers: ["tremoloSpeed", "tremoloDepth"], 
            color: "#ff9966",
            label: "TREMOLO"
        },
        {
            name: "ENVELOPPE",
            controllers: ["attack", "release"],
            color: "#66ff99", 
            label: "ENVELOPPE"
        },
        {
            name: "TRANSPOSE",
            controllers: ["voice"],
            color: "#ff66ff",
            label: "TRANSPOSE"
        }
    ]
};

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

// Configuration des pédales  
var pedals = {
    count: 8,
    defaultPreset: "default"
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

// Fonctions helper - Déclaration simple
function getControllerName(index) {
    return controllers.order[index] || "";
}

function getControllerByIndex(index) {
    var name = controllers.order[index];
    return controllers.definitions[name] || { min: 0, max: 127, default: 0, label: "" };
}

function getPedalRange(controllerName) {
    var meta = controllers.definitions[controllerName];
    if (!meta) return { min: -100, max: 100 };
    return { min: meta.min, max: meta.max };
}

// Export pour Node.js
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        websocketUrl: websocketUrl,
        httpPort: httpPort,
        controllers: controllers,
        sirens: sirens,
        pedals: pedals,
        ui: ui,
        getControllerName: getControllerName,
        getControllerByIndex: getControllerByIndex,
        getPedalRange: getPedalRange
    };
}
