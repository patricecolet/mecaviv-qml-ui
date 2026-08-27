const express = require('express');
const path = require('path');
const fs = require('fs');
const fsp = require('fs/promises');
const os = require('os');
const net = require('net');
// bluetoothctl est le seul appel a un binaire externe de ce serveur : la charge
// du casque n'existe nulle part ailleurs que dans BlueZ.
const execFile = require('util').promisify(require('child_process').execFile);
const app = express();
const port = parseInt(process.env.WEB_PORT || '8010', 10);

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
const INJECTION_SNIPPET = `\n<!-- INJECTED_LOGGING -->\n<script>\n(function(){\n  function postLog(type, msg, extra){\n    try{\n      fetch('/log', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ type, message: msg, data: extra||null, timestamp: new Date().toLocaleTimeString() })});\n    }catch(e){}\n  }\n  const origErr = console.error, origWarn = console.warn, origLog = console.log;\n  console.error = function(){ postLog('error', Array.from(arguments).join(' ')); origErr.apply(console, arguments); };\n  console.warn  = function(){ postLog('warning', Array.from(arguments).join(' ')); origWarn.apply(console, arguments); };\n  console.log   = function(){ postLog('info', Array.from(arguments).join(' ')); origLog.apply(console, arguments); };\n  window.addEventListener('error', function(e){ postLog('error', e.message+' @'+e.filename+':'+e.lineno+':'+e.colno); });\n  window.addEventListener('unhandledrejection', function(e){ postLog('error', 'UnhandledRejection '+e.reason); });\n  console.log('[Injected] Logging navigateur initialisé');\n  \n  // Web MIDI : on note seulement si l'API existe. Surtout PAS de\n  // requestMIDIAccess() — l'appel déclenche une demande d'autorisation à chaque\n  // chargement de page, insupportable en kiosque, alors que l'application ne s'en\n  // sert pas : tout le MIDI arrive de PD par le WebSocket.\n  postLog('info', 'Web MIDI API: ' + (navigator && navigator.requestMIDIAccess ? 'présente (non utilisée)' : 'absente'));\n})();\n</script>\n`;

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
        // Comme pour le wasm : sans ça, le kiosque ressert la page injectée
        // d'avant le déploiement et on debug une version qui n'existe plus.
        res.setHeader('Cache-Control', 'no-cache');
        res.send(out);
    });
}

// ---------------------------------------------------------------------------
// Infos système (Raspberry Pi) — lues dans /proc et /sys, sans dépendance ni sudo.
// Hors Linux (poste de dev), les valeurs indisponibles retombent à 0 / null :
// ces routes ne doivent jamais lever, le monitoring est informatif.
// ---------------------------------------------------------------------------

async function readTemperature() {
    try {
        const raw = await fsp.readFile('/sys/class/thermal/thermal_zone0/temp', 'utf8');
        return Math.round(parseInt(raw, 10) / 100) / 10;
    } catch (e) {
        return 0;
    }
}

// Occupation CPU = delta entre deux instantanés de /proc/stat.
// Plus juste que loadavg, et sans le coût d'un `top -bn1`.
let previousCpu = null;

async function readCpu() {
    try {
        const line = (await fsp.readFile('/proc/stat', 'utf8')).split('\n')[0];
        const fields = line.trim().split(/\s+/).slice(1).map(Number);
        const total = fields.reduce((a, b) => a + b, 0);
        const idle = fields[3] + (fields[4] || 0); // idle + iowait
        const snapshot = { total, idle };
        const previous = previousCpu;
        previousCpu = snapshot;
        if (!previous) return 0;
        const deltaTotal = total - previous.total;
        const deltaIdle = idle - previous.idle;
        if (deltaTotal <= 0) return 0;
        return Math.round((1 - deltaIdle / deltaTotal) * 1000) / 10;
    } catch (e) {
        return 0;
    }
}

async function readMemory() {
    try {
        const meminfo = await fsp.readFile('/proc/meminfo', 'utf8');
        const value = (key) => {
            const match = meminfo.match(new RegExp('^' + key + ':\\s+(\\d+)', 'm'));
            return match ? parseInt(match[1], 10) : 0;
        };
        const total = value('MemTotal');
        const available = value('MemAvailable');
        if (!total) return 0;
        return Math.round((1 - available / total) * 1000) / 10;
    } catch (e) {
        return 0;
    }
}

// Compteurs RX/TX de la première interface active hors loopback.
async function readNetwork() {
    try {
        const lines = (await fsp.readFile('/proc/net/dev', 'utf8')).split('\n').slice(2);
        for (const name of ['eth0', 'wlan0']) {
            const line = lines.find(l => l.trim().startsWith(name + ':'));
            if (!line) continue;
            const fields = line.split(':')[1].trim().split(/\s+/);
            return `RX:${fields[0]} TX:${fields[8]}`;
        }
        return 'N/A';
    } catch (e) {
        return 'N/A';
    }
}

// Cache court : le QML interroge toutes les 5 s, mais rien n'empêche
// plusieurs clients de le faire en même temps.
let systemInfoCache = { at: 0, data: null };

async function readSystemInfo() {
    const now = Date.now();
    if (systemInfoCache.data && now - systemInfoCache.at < 1000) {
        return systemInfoCache.data;
    }
    const [temperature, cpu, memory, network] = await Promise.all([
        readTemperature(), readCpu(), readMemory(), readNetwork()
    ]);
    const data = { temperature, cpu, memory, uptime: os.uptime(), network };
    systemInfoCache = { at: now, data };
    return data;
}

// L'adresse du serveur WebSocket suit celle par laquelle la page a été demandée.
// Sans ça, le `ws://localhost:10000` de config.js est compilé dans le wasm : la
// page servie par le Raspberry ferait chercher Pure Data sur la machine du
// navigateur, et changer l'IP du Pi imposerait un rebuild.
app.get('/api/config', (req, res) => {
    const wsPort = parseInt(process.env.WS_PORT || '10000', 10);
    const host = (req.hostname || 'localhost');
    res.json({ websocketUrl: `ws://${host}:${wsPort}` });
});

// État du lien RTP-MIDI. On parle directement à la socket de contrôle de
// rtpmidid plutôt que d'appeler `rtpmidid-cli` : le binaire n'est pas exécutable
// par tout le monde et ce droit-là est un réglage manuel qu'un redéploiement ne
// remet pas. La socket, elle, est créée par le service --user lui-même.
const RTPMIDID_SOCKET = process.env.RTPMIDID_SOCKET ||
    path.join(process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid ? process.getuid() : 1000}`, 'rtpmidid.sock');

function readRtpStatus() {
    return new Promise((resolve) => {
        const done = (v) => { try { sock.destroy(); } catch (e) {} resolve(v); };
        const timer = setTimeout(() => done({ available: false, peers: [] }), 1500);
        let buf = '';
        const sock = net.connect(RTPMIDID_SOCKET);
        sock.on('error', () => { clearTimeout(timer); done({ available: false, peers: [] }); });
        sock.on('connect', () => sock.write(JSON.stringify({ method: 'status', params: [] }) + '\n'));
        sock.on('data', (chunk) => {
            buf += chunk.toString();
            // La réponse tient en un objet JSON ; on attend qu'il soit complet.
            try {
                const parsed = JSON.parse(buf);
                clearTimeout(timer);
                const router = (parsed.result && parsed.result.router) || [];
                done({
                    available: true,
                    // Les entrées sans nom ni statut sont les moitiés ALSA
                    // internes du routeur : elles doublent chaque pair sans rien
                    // dire de plus. Et on ne garde du nom que le pair distant,
                    // le côté local étant toujours nous.
                    peers: router
                        .filter((r) => r.name && r.status)
                        .map((r) => ({
                            name: r.name.split('<->').pop().trim(),
                            status: r.status,
                            recv: r.stats ? r.stats.recv : 0,
                            sent: r.stats ? r.stats.sent : 0
                        }))
                });
            } catch (e) { /* pas encore complet */ }
        });
    });
}

// Casque Bluetooth : nom et niveau de batterie, via bluetoothctl. La batterie
// n'est exposee par BlueZ (org.bluez.Battery1) que si `Experimental = true`
// dans /etc/bluetooth/main.conf -- la phase deps du deploiement s'en charge.
// Rend `connected: false` quand rien n'est appaire ou connecte : l'ecran masque
// alors la ligne au lieu d'afficher un tiret de plus.
async function readBluetoothAudio() {
    try {
        const { stdout: devs } = await execFile('bluetoothctl', ['devices', 'Connected']);
        const line = devs.split('\n').find(l => l.startsWith('Device '));
        if (!line) return { connected: false };
        const [, mac, ...nameParts] = line.trim().split(' ');
        const name = nameParts.join(' ');
        let battery = null;
        try {
            const { stdout: info } = await execFile('bluetoothctl', ['info', mac]);
            const m = info.match(/Battery Percentage:.*\((\d+)\)/);
            if (m) battery = parseInt(m[1], 10);
        } catch (e) { /* le peripherique ne rapporte pas sa charge */ }
        return { connected: true, name, mac, battery };
    } catch (e) {
        return { connected: false };
    }
}

app.get('/api/bluetooth', async (req, res) => {
    res.json(await readBluetoothAudio());
});

app.get('/api/rtp', async (req, res) => {
    res.json(await readRtpStatus());
});

app.get('/api/temperature', async (req, res) => {
    res.json({ temperature: await readTemperature() });
});

app.get('/api/system-info', async (req, res) => {
    res.json(await readSystemInfo());
});

// Route HTML principale avec injection
app.get(['/','/qmlwebsocketserver.html'], (req, res) => {
    const filePath = path.join(__dirname, 'qmlwebsocketserver.html');
    serveWithInjection(filePath, res);
});

// Servir les fichiers statiques restants (js/wasm/assets).
// no-cache sur le wasm et la glue JS : sans ça le navigateur ressert
// l'ancien binaire après un déploiement et on croit que le rsync a raté.
app.use(express.static(__dirname, {
    setHeaders: (res, filePath) => {
        if (/\.(wasm|js)$/.test(filePath)) {
            res.setHeader('Cache-Control', 'no-cache');
        }
    }
}));

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
    console.log(`🌡️  Infos système sur http://localhost:${port}/api/system-info`);
    console.log(`🌐 Application principale sur http://localhost:${port}/qmlwebsocketserver.html`);
    // Amorce le delta CPU pour que la première requête renvoie une vraie valeur
    readCpu();
});
