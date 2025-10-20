const fs = require('fs').promises;
const path = require('path');

// Charger la config pour obtenir le chemin MIDI
const { loadConfig } = require('../../config-loader.js');
const config = loadConfig();
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || config.paths.midiRepository;

console.log('📁 MIDI Repository Path:', MIDI_REPO_PATH);

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
                // Fichier MIDI trouvé
                const relativePath = path.relative(baseDir, fullPath);
                const categoryName = category || 'uncategorized';
                
                // Extraire le titre (nom du fichier sans extension)
                const title = path.basename(entry.name, path.extname(entry.name));
                
                files.push({
                    title: title,
                    path: relativePath.replace(/\\/g, '/'), // Unix paths
                    category: categoryName.split('/')[0], // Première partie du chemin
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
 * Retourne la liste au format MIDI_FILES_LIST (pour le protocole WebSocket)
 */
async function getMidiFilesList(req, res) {
    try {
        console.log('📂 Scanning MIDI files...');
        const files = await scanDirectory(MIDI_REPO_PATH);
        
        // Grouper par catégorie
        const categoriesMap = {};
        files.forEach(file => {
            if (!categoriesMap[file.category]) {
                categoriesMap[file.category] = {
                    name: file.category,
                    files: []
                };
            }
            categoriesMap[file.category].files.push({
                title: file.title,
                path: file.path
            });
        });
        
        // Convertir en array
        const categories = Object.values(categoriesMap);
        
        console.log(`✅ Found ${files.length} MIDI files in ${categories.length} categories`);
        
        // Format conforme au protocole MIDI_FILES_LIST
        const response = {
            type: "MIDI_FILES_LIST",
            categories: categories
        };
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
    } catch (error) {
        console.error('❌ Error loading MIDI files:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            type: "ERROR",
            message: error.message
        }));
    }
}

module.exports = {
    getMidiFilesList
};

