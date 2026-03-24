const fs = require('fs').promises;
const path = require('path');
const fsSync = require('fs');

// Charger la config pour obtenir le chemin MIDI
const { loadConfig } = require('../../config-loader.js');
const config = loadConfig();
const MIDI_REPO_PATH = process.env.MECAVIV_COMPOSITIONS_PATH || config.paths.midiRepository;

console.log('📁 MIDI Repository Path:', MIDI_REPO_PATH);

/**
 * Chemins candidats JSON livret (voir docs/CONDUCTOR_CUES_PROTOCOL.md).
 */
function conductorCueCandidatePaths(midiFullPath) {
    const dir = path.dirname(midiFullPath);
    const ext = path.extname(midiFullPath);
    const base = path.basename(midiFullPath, ext);
    const siblingJsonDir = path.resolve(dir, '..', 'json');
    return [
        path.join(dir, `${base}_conductor-cues.json`),
        path.join(dir, 'conductor-cues.json'),
        path.join(dir, `${base}.json`),
        path.join(siblingJsonDir, `${base}_conductor-cues.json`),
        path.join(siblingJsonDir, 'conductor-cues.json'),
        path.join(siblingJsonDir, `${base}.json`),
    ];
}

async function hasConductorCuesJson(midiFullPath) {
    for (const p of conductorCueCandidatePaths(midiFullPath)) {
        try {
            const st = await fs.stat(p);
            if (st.isFile()) return true;
        } catch (_) {
            /* absent */
        }
    }
    return false;
}

/**
 * Lit et parse le premier JSON conductor-cues trouvé pour un fichier MIDI donné (chemin absolu).
 * @returns {Promise<{ path: string, doc: object } | null>}
 */
async function readConductorCueDocument(midiAbsPath) {
    for (const p of conductorCueCandidatePaths(midiAbsPath)) {
        try {
            const raw = await fs.readFile(p, 'utf8');
            const doc = JSON.parse(raw);
            return { path: p, doc };
        } catch (_) {
            /* absent ou JSON invalide */
        }
    }
    return null;
}

function safeResolveMidiRelative(repoRoot, relPath) {
    if (typeof relPath !== 'string' || relPath.includes('..')) return null;
    const abs = path.resolve(repoRoot, relPath.replace(/\\/g, '/'));
    const rootAbs = path.resolve(repoRoot);
    if (!abs.startsWith(rootAbs)) return null;
    return abs;
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
                const title = path.basename(entry.name, path.extname(entry.name));
                const microtonal = await hasConductorCuesJson(fullPath);

                files.push({
                    title: title,
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
                path: file.path,
                microtonal: !!file.microtonal
            });
        });
        
        // Convertir en array, ordre stable par nom de dossier
        const categories = Object.values(categoriesMap);
        categories.sort((a, b) => String(a.name).localeCompare(String(b.name), undefined, { sensitivity: 'base' }));

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

/**
 * GET /api/midi/conductor-cues?path=<chemin relatif du .mid/.midi dans le dépôt>
 * Retourne le JSON du livret (schéma CONDUCTOR_CUES_PROTOCOL) ou 404.
 */
async function getConductorCues(req, res) {
    try {
        const u = new URL(req.url, 'http://localhost');
        const rel = u.searchParams.get('path');
        if (!rel) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'missing path query' }));
            return;
        }
        const midiAbs = safeResolveMidiRelative(MIDI_REPO_PATH, rel);
        if (!midiAbs) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'invalid path' }));
            return;
        }
        if (!fsSync.existsSync(midiAbs)) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'midi not found' }));
            return;
        }
        const found = await readConductorCueDocument(midiAbs);
        if (!found) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'no conductor cues file' }));
            return;
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            conductorPath: path.relative(MIDI_REPO_PATH, found.path).replace(/\\/g, '/'),
            document: found.doc,
        }));
    } catch (error) {
        console.error('❌ getConductorCues:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

module.exports = {
    getMidiFilesList,
    getConductorCues,
};

