// API REST pour la gestion des presets
// Serveur Node.js simple pour les presets

const express = require('express');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PRESETS_FILE = path.join(__dirname, 'presets.json');

// Middleware
app.use(express.json());

// Initialiser le fichier presets s'il n'existe pas
async function initializePresetsFile() {
    try {
        await fs.access(PRESETS_FILE);
    } catch (error) {
        // Fichier n'existe pas, le créer avec des presets par défaut
        const defaultPresets = {
            presets: [
                {
                    id: "preset_001",
                    name: "Configuration Théâtre",
                    description: "Setup pour spectacle théâtral",
                    created: new Date().toISOString(),
                    modified: new Date().toISOString(),
                    version: "1.0",
                    config: {
                        pupitres: [
                            {
                                id: "P1",
                                assignedSirenes: [1, 2, 3],
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
                    }
                },
                {
                    id: "preset_002",
                    name: "Configuration Studio",
                    description: "Setup pour enregistrement studio",
                    created: new Date().toISOString(),
                    modified: new Date().toISOString(),
                    version: "1.0",
                    config: {
                        pupitres: [
                            {
                                id: "P1",
                                assignedSirenes: [4, 5, 6],
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
                }
            ]
        };
        
        await fs.writeFile(PRESETS_FILE, JSON.stringify(defaultPresets, null, 2));
        console.log("📁 Fichier presets.json créé avec les presets par défaut");
    }
}

// Lire tous les presets
async function readPresets() {
    try {
        const data = await fs.readFile(PRESETS_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.error("❌ Erreur lecture presets:", error);
        return { presets: [] };
    }
}

// Écrire les presets
async function writePresets(data) {
    try {
        await fs.writeFile(PRESETS_FILE, JSON.stringify(data, null, 2));
        return true;
    } catch (error) {
        console.error("❌ Erreur écriture presets:", error);
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
            res.status(201).json({ preset: presetData });
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
            res.json({ preset: presetData });
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

// Initialiser le fichier presets (sans démarrer de serveur séparé)
async function initializePresetAPI() {
    await initializePresetsFile();
    console.log(`📁 Fichier presets initialisé: ${PRESETS_FILE}`);
}

// Export pour utilisation dans server.js
module.exports = {
    initializePresetAPI,
    app
};
