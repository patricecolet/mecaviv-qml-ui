const fs = require('fs').promises;
const path = require('path');

// Charger la config pour obtenir le chemin MIDI
const { loadConfig } = require('../../config-loader.js');
const config = loadConfig();
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || config.paths.midiRepository;

console.log('📁 MIDI Repository Path:', MIDI_REPO_PATH);

async function hasConductorCuesJson(midiFullPath) {
    const dir = path.dirname(midiFullPath);
    const ext = path.extname(midiFullPath);
    const base = path.basename(midiFullPath, ext);
    const siblingJsonDir = path.resolve(dir, '..', 'json');
    const candidates = [
        path.join(dir, `${base}_conductor-cues.json`),
        path.join(dir, 'conductor-cues.json'),
        path.join(dir, `${base}.json`),
        // Compat historique: dossiers séparés .../midi/<piece>.midi + .../json/<piece>.json
        path.join(siblingJsonDir, `${base}_conductor-cues.json`),
        path.join(siblingJsonDir, 'conductor-cues.json'),
        path.join(siblingJsonDir, `${base}.json`),
    ];
    for (const p of candidates) {
        try {
            const st = await fs.stat(p);
            if (st.isFile()) return true;
        } catch (_) {}
    }
    return false;
}

/**
 * Scanner un répertoire récursivement pour trouver les fichiers MIDI
 */
async function scanDirectory(dir, category = '', baseDir = dir) {
    const files = [];
    
    try {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            
            if (entry.isDirectory()) {
                // Récursion dans les sous-dossiers
                const subCategory = category ? `${category}/${entry.name}` : entry.name;
                const subFiles = await scanDirectory(fullPath, subCategory, baseDir);
                files.push(...subFiles);
            } else if (entry.isFile() && /\.(midi?|mid)$/i.test(entry.name)) {
                const relativePath = path.relative(baseDir, fullPath).replace(/\\/g, '/');
                const categoryName = (category && category.replace(/\\/g, '/')) || 'uncategorized';
                const microtonal = await hasConductorCuesJson(fullPath);
                files.push({
                    name: entry.name,
                    path: relativePath,
                    category: categoryName,
                    microtonal: microtonal,
                    fullPath: fullPath
                });
            }
        }
    } catch (error) {
        console.error(`❌ Erreur scan ${dir}:`, error.message);
    }
    
    return files;
}

/**
 * GET /api/midi/files
 * Retourne la liste de tous les fichiers MIDI disponibles
 */
async function getMidiFiles(req, res) {
    try {
        console.log('📂 Scanning MIDI files...');
        const files = await scanDirectory(MIDI_REPO_PATH);
        
        console.log(`✅ Found ${files.length} MIDI files`);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: true,
            count: files.length,
            files: files,
            repositoryPath: MIDI_REPO_PATH
        }));
    } catch (error) {
        console.error('❌ Error loading MIDI files:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: false,
            error: error.message
        }));
    }
}

/**
 * GET /api/midi/categories
 * Retourne la liste des catégories disponibles
 */
async function getMidiCategories(req, res) {
    try {
        const files = await scanDirectory(MIDI_REPO_PATH);
        
        // Grouper par catégorie
        const categoriesMap = {};
        files.forEach(file => {
            if (!categoriesMap[file.category]) {
                categoriesMap[file.category] = {
                    name: file.category,
                    count: 0,
                    files: []
                };
            }
            categoriesMap[file.category].count++;
            categoriesMap[file.category].files.push(file);
        });
        
        // Convertir en array
        const categories = Object.values(categoriesMap);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: true,
            categories: categories
        }));
    } catch (error) {
        console.error('❌ Error loading categories:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: false,
            error: error.message
        }));
    }
}

module.exports = {
    getMidiFiles,
    getMidiCategories
};

