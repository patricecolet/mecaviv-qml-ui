/**
 * Configuration Loader
 * Charge config.json et résout les chemins relatifs
 */

const fs = require('fs');
const path = require('path');

/**
 * Déterminer le chemin vers config.json
 * Cherche à la racine du projet mecaviv-qml-ui
 */
function getConfigPath() {
    // Chemin relatif depuis ce fichier (config-loader.js est à la racine de mecaviv-qml-ui)
    return path.join(__dirname, 'config.json');
}

/**
 * Résoudre un chemin relatif depuis la racine du projet
 */
function resolvePath(relativePath) {
    if (typeof relativePath !== 'string') return relativePath;
    
    // Si c'est déjà un chemin absolu, le retourner tel quel
    if (path.isAbsolute(relativePath)) {
        return relativePath;
    }
    
    // Résoudre depuis la racine du projet (où se trouve config.json)
    return path.resolve(__dirname, relativePath);
}

/**
 * Résoudre récursivement tous les chemins dans un objet
 */
function resolveAllPaths(obj) {
    // Si c'est une string, résoudre le chemin
    if (typeof obj === 'string') {
        return resolvePath(obj);
    }
    
    // Si ce n'est pas un objet, retourner tel quel
    if (typeof obj !== 'object' || obj === null) {
        return obj;
    }
    
    // Si c'est un array, résoudre chaque élément
    if (Array.isArray(obj)) {
        return obj.map(item => resolveAllPaths(item));
    }
    
    // Si c'est un objet, résoudre chaque propriété
    const resolved = {};
    for (const [key, value] of Object.entries(obj)) {
        // Ne pas résoudre les champs "description"
        if (key === 'description') {
            resolved[key] = value;
        } else {
            resolved[key] = resolveAllPaths(value);
        }
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
    
    // Résoudre tous les chemins relatifs
    const config = {
        ...rawConfig,
        paths: resolveAllPaths(rawConfig.paths),
        servers: rawConfig.servers  // Pas de résolution pour les serveurs
    };
    
    // Afficher les chemins résolus
    console.log('📂 MIDI Repository:', config.paths.midiRepository);
    console.log('🔌 WebSocket:', `${config.servers.websocket.host}:${config.servers.websocket.port}`);
    
    return config;
}

module.exports = { loadConfig, getConfigPath };

