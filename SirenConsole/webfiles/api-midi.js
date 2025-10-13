const fs = require('fs').promises;
const path = require('path');

// Chemin vers le repository MIDI (depuis config.js)
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || path.resolve(__dirname, '../../../mecaviv/compositions');

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
                
                files.push({
                    name: entry.name,
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

