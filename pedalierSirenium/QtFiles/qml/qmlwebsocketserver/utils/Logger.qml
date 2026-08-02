import QtQuick

QtObject {
    id: root
    
    // Propriétés
    property int globalLevel: 0  // OFF par défaut
    
    // Propriétés individuelles pour chaque catégorie
    // INFO : sans ça, tout ce que PD répond est muet dans /logs et on ne peut pas
    // distinguer « la commande n'est pas partie » de « PD l'a ignorée ».
    property int levelWebSocket: 3
    property int levelClock: 0
    property int levelVoice: 0
    property int levelAnimation: 0
    property int levelBatch: 0
    property int levelRecording: 0
    property int levelPreset: 0
    property int levelKnob: 0
    property int levelRouter: 0
    property int levelParser: 0
    property int levelInit: 0
    property int levelScenes: 3  // INFO par défaut pour voir les logs de scènes
    property int levelMidi: 3    // INFO par défaut pour voir les logs MIDI
    
    // Map pour associer les noms aux propriétés
    readonly property var categoryMap: ({
        "WEBSOCKET": "levelWebSocket",
        "CLOCK": "levelClock",
        "VOICE": "levelVoice",
        "ANIMATION": "levelAnimation",
        "BATCH": "levelBatch",
        "RECORDING": "levelRecording",
        "PRESET": "levelPreset",
        "KNOB": "levelKnob",
        "ROUTER": "levelRouter",
        "PARSER": "levelParser",
        "INIT": "levelInit",
        "SCENES": "levelScenes",
        "MIDI": "levelMidi"
    })
    
    // Emojis pour chaque catégorie
    property var emojis: ({
        "WEBSOCKET": "🌐",
        "CLOCK": "⏰",
        "VOICE": "🎤",
        "ANIMATION": "🎬",
        "BATCH": "📦",
        "RECORDING": "🔴",
        "PRESET": "💾",
        "KNOB": "🎛️",
        "ROUTER": "🔀",
        "PARSER": "📊",
        "INIT": "🚀",
        "SCENES": "🎭",  // Pas besoin de changer les logs, emoji acceptable ici
        "MIDI": "🎛️"
    })
    
    // Ajout de l'historique des logs
    property var logHistory: []

    // Niveaux (propriétés readonly en minuscules)
    readonly property int level_off: 0
    readonly property int level_error: 1
    readonly property int level_warn: 2
    readonly property int level_info: 3
    readonly property int level_debug: 4
    readonly property int level_trace: 5
    
    signal historyChanged()

    function setAllCategories(level) {
        console.log("🎯 Logger.setAllCategories appelé avec level:", level);
        for (let cat in categoryMap) {
            console.log("   Setting", cat, "to", level);
            setCategoryLevel(cat, level);
        }
    }

    function setCategoryLevel(category, level) {
        console.log("🎯 Logger.setCategoryLevel:", category, "->", level);
        let propName = categoryMap[category];
        if (propName) {
            console.log("   Propriété trouvée:", propName);
            root[propName] = level;
            console.log("   Nouvelle valeur:", root[propName]);
        }
    }
    
    function getCategoryLevel(category) {
        let prop = categoryMap[category];
        let level = prop ? root[prop] : root.level_info;
        // console.log("getCategoryLevel", category, "->", level);
        return level;
    }
    
    // Fonction de log principale
    function log(level, category, ...args) {
        // Obtenir le niveau de la catégorie
        let categoryLevel = getCategoryLevel(category);
        
        if (level > categoryLevel) return;
        
        // Construire le message
        let emoji = emojis[category] || "📝";
        let levelStr = ["OFF", "ERROR", "WARN", "INFO", "DEBUG", "TRACE"][level];
        let prefix = emoji + " " + category;
        
        // Afficher selon le niveau
        switch(level) {
            case level_error:
                console.error(prefix + ":", ...args);
                break;
            case level_warn:
                console.warn(prefix + ":", ...args);
                break;
            default:
                console.log(prefix + ":", ...args);
                break;
        }
    }
    
    // Méthodes de commodité
    function addToHistory(level, category, args) {
        let now = new Date();
        let time = now.toLocaleTimeString();
        let emoji = emojis[category] || "";
        let msg = `[${time}] ${emoji} [${category}] ${level}: ` + Array.prototype.join.call(args, " ");
        logHistory = logHistory.concat([msg]); // version réactive
        // Limiter la taille de l'historique (par exemple 500 messages)
        if (logHistory.length > 500) logHistory = logHistory.slice(-500);
        historyChanged();
        if (category === "VOICE") {
            console.log("addToHistory VOICE", msg);
        }
    }

    function clearHistory() {
        logHistory = [];
        historyChanged();
    }

    function info(category, ...args) {
        if (getCategoryLevel(category) >= level_info) {
            console.log("LOGGER.INFO", category, ...args);
            addToHistory("INFO", category, args);
        }
    }
    function debug(category, ...args) {
        if (getCategoryLevel(category) >= level_debug) {
            console.log("DEBUG", category, ...args);
            addToHistory("DEBUG", category, args);
        }
    }
    function warn(category, ...args) {
        if (getCategoryLevel(category) >= level_warn) {
            console.warn("WARN", category, ...args);
            addToHistory("WARN", category, args);
        }
    }
    function error(category, ...args) {
        if (getCategoryLevel(category) >= level_error) {
            console.error("ERROR", category, ...args);
            addToHistory("ERROR", category, args);
        }
    }
    function trace(category, ...args) {
        if (getCategoryLevel(category) >= level_trace) {
            console.log("TRACE", category, ...args);
            addToHistory("TRACE", category, args);
        }
    }
}
