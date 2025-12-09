const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

// Port HTTP configurable via variable d'environnement ou argument
const PORT = parseInt(process.env.PORT || process.argv[2] || 8081, 10);
const WEBSOCKET_PORT = parseInt(process.env.WEBSOCKET_PORT || 8006, 10);

// Headers de sécurité pour WebAssembly
function setSecurityHeaders(response) {
    // Headers CORS pour développement local
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    // Headers pour WebAssembly (optionnels en développement)
    // response.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    // response.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    // response.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
}

// MIME types
const mimeTypes = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.wasm': 'application/wasm',
    '.svg': 'image/svg+xml',
    '.json': 'application/json',
    '.css': 'text/css',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf'
};

// Serveur HTTP pour servir les fichiers statiques
const server = http.createServer((req, res) => {
    console.log(`📥 ${req.method} ${req.url}`);
    
    // Appliquer les headers de sécurité
    setSecurityHeaders(res);
    
    // Gestion OPTIONS (CORS preflight)
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    let filePath = '.' + req.url;
    
    // Route principale - servir index.html ou appSirenManager.html directement
    if (req.url === '/' || req.url === '' || req.url === '/index.html') {
        // Vérifier si index.html existe, sinon servir directement appSirenManager.html
        if (fs.existsSync('./index.html')) {
            filePath = './index.html';
        } else {
            filePath = './appSirenManager.html';
        }
    }
    
    // Normaliser le chemin
    filePath = path.normalize(filePath);
    
    // Vérifier que le fichier est dans le répertoire webfiles (sécurité)
    const safePath = path.resolve(filePath);
    const basePath = path.resolve('.');
    if (!safePath.startsWith(basePath)) {
        res.writeHead(403, { 'Content-Type': 'text/html' });
        res.end('<h1>403 - Forbidden</h1>', 'utf-8');
        return;
    }
    
    const extname = String(path.extname(filePath)).toLowerCase();
    const contentType = mimeTypes[extname] || 'application/octet-stream';
    
    // Headers spéciaux pour WebAssembly
    const headers = {
        'Content-Type': contentType
    };
    
    if (extname === '.wasm') {
        headers['Content-Type'] = 'application/wasm';
    }
    
    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                console.log(`❌ 404: ${req.url}`);
                res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
                res.end(`
                    <!DOCTYPE html>
                    <html>
                    <head><title>404 - File Not Found</title></head>
                    <body style="font-family: Arial; padding: 20px; background: #1e1e1e; color: white;">
                        <h1>404 - Fichier non trouvé</h1>
                        <p>L'URL demandée n'existe pas : <code>${req.url}</code></p>
                        <p><a href="/" style="color: #4a90e2;">Retour à l'accueil</a> | <a href="/appSirenManager.html" style="color: #4a90e2;">Application SirenManager</a></p>
                    </body>
                    </html>
                `, 'utf-8');
            } else {
                console.log(`❌ 500: ${error.message}`);
                res.writeHead(500, { 'Content-Type': 'text/html; charset=utf-8' });
                res.end(`<h1>500 - Server Error</h1><p>${error.code}</p>`, 'utf-8');
            }
        } else {
            console.log(`✅ 200: ${req.url} (${(content.length / 1024).toFixed(2)} KB)`);
            res.writeHead(200, headers);
            res.end(content, 'utf-8');
        }
    });
});

server.listen(PORT, (error) => {
    if (error) {
        console.error(`❌ Erreur lors du démarrage du serveur sur le port ${PORT}:`, error.message);
        console.error(`💡 Le port ${PORT} est peut-être déjà utilisé.`);
        console.error(`💡 Essayez avec un autre port: PORT=8082 node server.js`);
        process.exit(1);
    }
    
    console.log(`\n===========================================`);
    console.log(`🚀 SirenManager - Serveur de développement`);
    console.log(`===========================================`);
    console.log(`📡 HTTP:     http://localhost:${PORT}/`);
    console.log(`📡 HTTP:     http://localhost:${PORT}/appSirenManager.html`);
    console.log(`🔌 WebSocket: ws://localhost:${WEBSOCKET_PORT}/`);
    console.log(`\n💡 Ouvrez http://localhost:${PORT}/ dans votre navigateur`);
    console.log(`\n📝 Note: Pour le proxy SSH, démarrez aussi le backend:`);
    console.log(`   cd ../backend && npm install && node server.js`);
    console.log(`\n💡 Pour utiliser un autre port:`);
    console.log(`   PORT=8082 node server.js`);
    console.log(`===========================================\n`);
});

// Serveur WebSocket pour le proxy UDP et communication backend
const wss = new WebSocket.Server({ port: WEBSOCKET_PORT });

wss.on('connection', (ws) => {
    console.log(`🔌 WebSocket client connected (${wss.clients.size} clients)`);
    
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message.toString());
            console.log(`📨 WebSocket message: ${data.type}`);
            
            // Forward messages to backend if needed
            if (data.type === 'ping') {
                ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
            }
        } catch (error) {
            console.error(`❌ WebSocket error: ${error.message}`);
            ws.send(JSON.stringify({ type: 'error', message: error.message }));
        }
    });
    
    ws.on('close', () => {
        console.log(`🔌 WebSocket client disconnected (${wss.clients.size} clients)`);
    });
    
    ws.on('error', (error) => {
        console.error(`❌ WebSocket error: ${error.message}`);
    });
});

console.log(`🔌 WebSocket server listening on port ${WEBSOCKET_PORT}`);
