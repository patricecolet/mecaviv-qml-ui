const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();
const port = 8010;

// Middleware pour parser le JSON
app.use(express.json());

// Middleware d'en-têtes nécessaires pour Qt WASM (COOP/COEP/CORS)
app.use((req, res, next) => {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
    res.setHeader('Vary', 'Origin');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }
    next();
});

// Système de logs
const browserLogs = [];

app.post('/log', (req, res) => {
    const logEntry = req.body || {};
    logEntry.timestamp = logEntry.timestamp || new Date().toLocaleTimeString();
    logEntry.type = logEntry.type || 'info';
    browserLogs.push(logEntry);
    
    // Afficher dans la console du serveur
    const { timestamp, type, message = '' } = logEntry;
    const data = logEntry.data ? JSON.stringify(logEntry.data) : '';
    
    const color = {
        'error': '\x1b[31m',   // Rouge
        'warning': '\x1b[33m', // Jaune
        'info': '\x1b[32m'     // Vert
    }[type] || '\x1b[37m';     // Blanc par défaut
    
    const reset = '\x1b[0m';
    console.log(`${color}[${timestamp}] ${type.toUpperCase()}:${reset} ${message}${data ? ' - ' + data : ''}`);
    
    // Garder seulement les 100 dernières entrées
    if (browserLogs.length > 300) {
        browserLogs.shift();
    }
    
    res.json({ status: 'logged' });
});

// Endpoint pour récupérer les logs
app.get('/logs', (req, res) => {
    res.json(browserLogs);
});

// Injection d'un script de logging dans l'HTML généré par Qt (sans modifier le fichier source)
const INJECTION_SNIPPET = `\n<!-- INJECTED_LOGGING -->\n<script>\n(function(){\n  function postLog(type, msg, extra){\n    try{\n      fetch('/log', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ type, message: msg, data: extra||null, timestamp: new Date().toLocaleTimeString() })});\n    }catch(e){}\n  }\n  const origErr = console.error, origWarn = console.warn, origLog = console.log;\n  console.error = function(){ postLog('error', Array.from(arguments).join(' ')); origErr.apply(console, arguments); };\n  console.warn  = function(){ postLog('warning', Array.from(arguments).join(' ')); origWarn.apply(console, arguments); };\n  console.log   = function(){ postLog('info', Array.from(arguments).join(' ')); origLog.apply(console, arguments); };\n  window.addEventListener('error', function(e){ postLog('error', e.message+' @'+e.filename+':'+e.lineno+':'+e.colno); });\n  window.addEventListener('unhandledrejection', function(e){ postLog('error', 'UnhandledRejection '+e.reason); });\n  console.log('[Injected] Logging navigateur initialisé');\n  \n  // Test Web MIDI API (côté navigateur)\n  try {\n    if (navigator && navigator.requestMIDIAccess) {\n      postLog('info', 'Web MIDI API: disponible');\n      navigator.requestMIDIAccess({ sysex: false }).then(access => {\n        const inputs = Array.from(access.inputs.values()).map(i => ({id:i.id,name:i.name,manufacturer:i.manufacturer}));\n        const outputs = Array.from(access.outputs.values()).map(o => ({id:o.id,name:o.name,manufacturer:o.manufacturer}));\n        postLog('info', 'Web MIDI: accès OK', {inputs, outputs});\n      }).catch(err => {\n        postLog('warning', 'Web MIDI: accès refusé ou erreur: '+(err && err.message ? err.message : err));\n      });\n    } else {\n      postLog('warning', 'Web MIDI API: non disponible (navigateur)');\n    }\n  } catch(e) {\n    postLog('error', 'Web MIDI test exception: '+e);\n  }\n})();\n</script>\n`;

function serveWithInjection(filePath, res) {
    fs.readFile(filePath, 'utf8', (err, html) => {
        if (err) {
            res.status(404).send('File Not Found');
            return;
        }
        // Injecter juste avant </head> si possible, sinon au début du <body>
        let out = html;
        if (html.includes('</head>')) {
            out = html.replace('</head>', INJECTION_SNIPPET + '</head>');
        } else if (html.includes('<body')) {
            out = html.replace(/<body[^>]*>/, match => match + INJECTION_SNIPPET);
        } else {
            out = INJECTION_SNIPPET + html;
        }
        res.setHeader('Content-Type', 'text/html');
        res.send(out);
    });
}

// Route HTML principale avec injection
app.get(['/','/qmlwebsocketserver.html'], (req, res) => {
    const filePath = path.join(__dirname, 'qmlwebsocketserver.html');
    serveWithInjection(filePath, res);
});

// Servir les fichiers statiques restants (js/wasm/assets)
app.use(express.static(__dirname));

// Route pour les logs en temps réel (SSE)
app.get('/logs/stream', (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    
    const sendLog = (log) => {
        res.write(`data: ${JSON.stringify(log)}\n\n`);
    };
    
    // Envoyer les logs existants
    browserLogs.forEach(sendLog);
    
    // Keep-alive
    const interval = setInterval(() => {
        res.write(':\n\n');
    }, 30000);
    
    req.on('close', () => {
        clearInterval(interval);
    });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 Serveur démarré sur http://localhost:${port}`);
    console.log(`📋 Logs du navigateur disponibles sur http://localhost:${port}/logs`);
    console.log(`📊 Stream de logs sur http://localhost:${port}/logs/stream`);
    console.log(`🌐 Application principale sur http://localhost:${port}/qmlwebsocketserver.html`);
});
