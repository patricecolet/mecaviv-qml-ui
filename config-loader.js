/**
 * Configuration Loader
 * Charge config.json avec détection OS et expansion du ~
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Déterminer le chemin vers config.json selon l'OS
 */
function getConfigPath() {
    const platform = os.platform();
    const home = os.homedir();
    
    if (platform === 'darwin') {
        // macOS - Dev
        return path.join(home, 'repo/mecaviv/config.json');
    } else {
        // Linux (Raspberry Pi) - Prod
        return path.join(home, 'mecaviv/config.json');
    }
}

/**
 * Expansion du ~ dans un chemin
 */
function expandTilde(str) {
    if (typeof str !== 'string') return str;
    if (str.startsWith('~/') || str === '~') {
        return str.replace('~', os.homedir());
    }
    return str;
}

/**
 * Résoudre les chemins selon l'OS
 */
function resolvePaths(obj, platform) {
    if (typeof obj !== 'object' || obj === null) {
        return obj;
    }
    
    // Si c'est un objet avec des clés par OS (darwin, linux)
    if (obj.darwin || obj.linux) {
        const value = obj[platform] || obj.linux || obj.darwin;
        return expandTilde(value);
    }
    
    // Sinon, expansion simple du ~
    if (typeof obj === 'string') {
        return expandTilde(obj);
    }
    
    // Récursion pour les objets/arrays
    if (Array.isArray(obj)) {
        return obj.map(item => resolvePaths(item, platform));
    }
    
    const resolved = {};
    for (const [key, value] of Object.entries(obj)) {
        resolved[key] = resolvePaths(value, platform);
    }
    return resolved;
}

/**
 * Charger et résoudre la configuration
 */
function loadConfig(configPath = null) {
    // Utiliser le chemin fourni ou détecter automatiquement
    const finalPath = configPath || getConfigPath();
    
    console.log('📁 Chargement config depuis:', finalPath);
    
    if (!fs.existsSync(finalPath)) {
        throw new Error(`❌ Fichier config.json introuvable: ${finalPath}`);
    }
    
    // Lire le JSON
    const rawConfig = JSON.parse(fs.readFileSync(finalPath, 'utf8'));
    const platform = os.platform();
    
    console.log('🖥️  Plateforme détectée:', platform);
    
    // Résoudre les chemins selon l'OS
    const config = {
        ...rawConfig,
        paths: resolvePaths(rawConfig.paths, platform),
        servers: {
            ...rawConfig.servers,
            websocket: {
                ...rawConfig.servers.websocket,
                host: resolvePaths(rawConfig.servers.websocket.host, platform)
            }
        }
    };
    
    // Afficher les chemins résolus
    console.log('📂 MIDI Repository:', config.paths.midiRepository);
    console.log('🔌 WebSocket Host:', config.servers.websocket.host);
    console.log('🔌 WebSocket Port:', config.servers.websocket.port);
    
    return config;
}

module.exports = { loadConfig, getConfigPath };

