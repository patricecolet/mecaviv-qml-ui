// API REST pour la gestion des presets
// Serveur Node.js simple pour les presets

const express = require('express');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PRESETS_FILE = path.join(__dirname, 'presets.json');

// Middleware
app.use(express.json());

function createDefaultPresets() {
    return {
        presets: [
            {
                id: "preset_001",
                name: "Configuration Théâtre",
                description: "Setup pour spectacle théâtral",
                created: new Date().toISOString(),
                modified: new Date().toISOString(),
                version: "1.0",
                pupitres: [
                    {
                        id: "P1",
                        assignedSirenes: [1],
                        vstEnabled: true,
                        udpEnabled: true,
                        rtpMidiEnabled: true,
                        controllerMapping: {
                            joystickX: { cc: 1, curve: "linear" },
                            joystickY: { cc: 2, curve: "parabolic" },
                            fader: { cc: 3, curve: "hyperbolic" },
                            selector: { cc: 4, curve: "s curve" },
                            pedalId: { cc: 5, curve: "linear" }
                        }
                    }
                ]
            },
            {
                id: "preset_002",
                name: "Configuration Studio",
                description: "Setup pour enregistrement studio",
                created: new Date().toISOString(),
                modified: new Date().toISOString(),
                version: "1.0",
                pupitres: [
                    {
                        id: "P1",
                        assignedSirenes: [1],
                        vstEnabled: false,
                        udpEnabled: true,
                        rtpMidiEnabled: false,
                        controllerMapping: {
                            joystickX: { cc: 10, curve: "parabolic" },
                            joystickY: { cc: 11, curve: "hyperbolic" },
                            fader: { cc: 12, curve: "linear" },
                            selector: { cc: 13, curve: "s curve" },
                            pedalId: { cc: 14, curve: "linear" }
                        }
                    }
                ]
            }
        ]
    };
}

// Initialiser le fichier presets s'il n'existe pas
async function initializePresetsFile() {
    try {
        await fs.access(PRESETS_FILE);
    } catch (error) {
        // Fichier n'existe pas, le créer avec des presets par défaut
        const defaultPresets = createDefaultPresets();
        await writePresets(defaultPresets);
        console.log("📁 Fichier presets.json créé avec les presets par défaut");
    }
}

async function healPresetsFile(originalError) {
    console.warn("⚠️ Fichier presets corrompu, tentative d'auto-réparation:", originalError.message);
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupPath = `${PRESETS_FILE}.corrupted-${timestamp}`;
    
    try {
        // Essayer de sauvegarder le fichier corrompu
        try {
            await fs.rename(PRESETS_FILE, backupPath);
            console.warn(`📦 Copie du fichier corrompu vers ${backupPath}`);
        } catch (renameError) {
            // Si le fichier n'existe pas ou est déjà renommé, continuer
            console.warn("⚠️ Impossible de sauvegarder le fichier corrompu:", renameError.message);
        }
    } catch (error) {
        // Ignorer les erreurs de sauvegarde
    }
    
    // Régénérer avec les valeurs par défaut (utilise l'écriture atomique)
    const defaultPresets = createDefaultPresets();
    await writePresets(defaultPresets);
    console.warn("✅ Fichier presets régénéré avec les valeurs par défaut");
    return defaultPresets;
}

// Lire tous les presets
async function readPresets() {
    try {
        const data = await fs.readFile(PRESETS_FILE, 'utf8');
        const parsed = JSON.parse(data);
        
        // Valider la structure
        if (!parsed || typeof parsed !== 'object') {
            throw new Error('Structure invalide: pas un objet');
        }
        if (!Array.isArray(parsed.presets)) {
            throw new Error('Structure invalide: presets n\'est pas un tableau');
        }
        
        return parsed;
    } catch (error) {
        console.error("❌ Erreur lecture presets:", error);
        return await healPresetsFile(error);
    }
}

// Écrire les presets (écriture atomique)
async function writePresets(data) {
    const tempFile = `${PRESETS_FILE}.tmp`;
    
    try {
        // Valider que le JSON est valide avant l'écriture
        const jsonString = JSON.stringify(data, null, 2);
        JSON.parse(jsonString); // Vérifier que c'est du JSON valide
        
        // Écriture atomique : écrire dans un fichier temporaire puis renommer
        await fs.writeFile(tempFile, jsonString, 'utf8');
        await fs.rename(tempFile, PRESETS_FILE);
        
        return true;
    } catch (error) {
        console.error("❌ Erreur écriture presets:", error);
        
        // Nettoyer le fichier temporaire s'il existe
        try {
            await fs.unlink(tempFile);
        } catch (unlinkError) {
            // Ignorer l'erreur de suppression du fichier temporaire
        }
        
        return false;
    }
}

// Générer un ID unique
function generateId() {
    return 'preset_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// GET /api/presets - Récupérer tous les presets
app.get('/api/presets', async (req, res) => {
    try {
        console.log("📥 GET /api/presets");
        const data = await readPresets();
        res.json(data);
    } catch (error) {
        console.error("❌ Erreur GET presets:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// GET /api/presets/:id - Récupérer un preset spécifique
app.get('/api/presets/:id', async (req, res) => {
    try {
        const presetId = req.params.id;
        console.log("📥 GET /api/presets/" + presetId);
        
        const data = await readPresets();
        const preset = data.presets.find(p => p.id === presetId);
        
        if (preset) {
            res.json(preset);
        } else {
            res.status(404).json({ error: "Preset non trouvé" });
        }
    } catch (error) {
        console.error("❌ Erreur GET preset:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// POST /api/presets - Créer un nouveau preset
app.post('/api/presets', async (req, res) => {
    try {
        console.log("📤 POST /api/presets");
        
        const presetData = req.body;
        
        // Validation basique
        if (!presetData.name) {
            return res.status(400).json({ error: "Le nom du preset est requis" });
        }
        
        const data = await readPresets();
        
        // Générer un ID unique
        presetData.id = generateId();
        presetData.created = new Date().toISOString();
        presetData.modified = new Date().toISOString();
        presetData.version = presetData.version || "1.0";
        
        // Ajouter le preset
        data.presets.push(presetData);
        
        if (await writePresets(data)) {
            console.log("✅ Preset créé:", presetData.id);
            res.status(201).json(presetData);
        } else {
            res.status(500).json({ error: "Erreur sauvegarde" });
        }
    } catch (error) {
        console.error("❌ Erreur POST preset:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// PUT /api/presets/:id - Mettre à jour un preset
app.put('/api/presets/:id', async (req, res) => {
    try {
        const presetId = req.params.id;
        console.log("📝 PUT /api/presets/" + presetId);
        
        const presetData = req.body;
        
        const data = await readPresets();
        const presetIndex = data.presets.findIndex(p => p.id === presetId);
        
        if (presetIndex === -1) {
            return res.status(404).json({ error: "Preset non trouvé" });
        }
        
        // Mettre à jour le preset
        presetData.id = presetId;
        presetData.modified = new Date().toISOString();
        
        // Conserver la date de création
        if (data.presets[presetIndex].created) {
            presetData.created = data.presets[presetIndex].created;
        }
        
        data.presets[presetIndex] = presetData;
        
        if (await writePresets(data)) {
            console.log("✅ Preset mis à jour:", presetId);
            res.json(presetData);
        } else {
            res.status(500).json({ error: "Erreur sauvegarde" });
        }
    } catch (error) {
        console.error("❌ Erreur PUT preset:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// DELETE /api/presets/:id - Supprimer un preset
app.delete('/api/presets/:id', async (req, res) => {
    try {
        const presetId = req.params.id;
        console.log("🗑️ DELETE /api/presets/" + presetId);
        
        const data = await readPresets();
        const presetIndex = data.presets.findIndex(p => p.id === presetId);
        
        if (presetIndex === -1) {
            return res.status(404).json({ error: "Preset non trouvé" });
        }
        
        // Supprimer le preset
        data.presets.splice(presetIndex, 1);
        
        if (await writePresets(data)) {
            console.log("✅ Preset supprimé:", presetId);
            res.status(204).send();
        } else {
            res.status(500).json({ error: "Erreur sauvegarde" });
        }
    } catch (error) {
        console.error("❌ Erreur DELETE preset:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// Nettoyer les fichiers temporaires orphelins
async function cleanupTempFiles() {
    try {
        const dir = path.dirname(PRESETS_FILE);
        const files = await fs.readdir(dir);
        const tempFiles = files.filter(f => f === 'presets.json.tmp');
        
        for (const file of tempFiles) {
            try {
                await fs.unlink(path.join(dir, file));
                console.log(`🧹 Fichier temporaire nettoyé: ${file}`);
            } catch (e) {
                // Ignorer les erreurs de suppression
            }
        }
    } catch (error) {
        // Ignorer les erreurs de nettoyage
    }
}

// Initialiser le fichier presets (sans démarrer de serveur séparé)
async function initializePresetAPI() {
    // Nettoyer les fichiers temporaires au démarrage
    await cleanupTempFiles();
    
    await initializePresetsFile();
    console.log(`📁 Fichier presets initialisé: ${PRESETS_FILE}`);
}

// Export pour utilisation dans server.js
module.exports = {
    initializePresetAPI,
    app,
    readPresets,
    writePresets,
    createDefaultPresets
};
