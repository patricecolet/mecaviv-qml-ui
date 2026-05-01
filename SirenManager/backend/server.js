const express = require('express');
const WebSocket = require('ws');
const dgram = require('dgram');
const cors = require('cors');
const SshProxy = require('./ssh-proxy');
const config = require('./config.json');

const app = express();
app.use(cors());
// Default Express limit is 100KB — too small for base64-encoded MIDI uploads.
app.use(express.json({ limit: '50mb' }));

const HTTP_PORT = config.ports.http || 8005;
const WS_PORT = config.ports.websocket || 8006;
const UDP_PORT = config.ports.udp || 8000;

// Initialize SSH proxy
const sshProxy = new SshProxy(config);

// HTTP Routes for SSH operations
app.post('/api/ssh/execute', async (req, res) => {
    try {
        const { machineType, command } = req.body;
        const output = await sshProxy.executeCommand(machineType, command);
        res.json({ success: true, output });
    } catch (error) {
        console.error('[SirenManager Backend] SSH error:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/ssh/download', async (req, res) => {
    try {
        const { machineType, remotePath } = req.body;
        const content = await sshProxy.downloadFile(machineType, remotePath);
        res.json({ success: true, content });
    } catch (error) {
        console.error('[SirenManager Backend] SSH error:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/ssh/upload', async (req, res) => {
    try {
        const { machineType, remotePath, content, contentBase64 } = req.body;
        const buffer = contentBase64
            ? Buffer.from(contentBase64, 'base64')
            : Buffer.from(content, 'utf8');
        console.log(`[SirenManager Backend] upload: machine=${machineType} path=${remotePath} bytes=${buffer.length} (${contentBase64 ? 'base64' : 'utf8'})`);
        await sshProxy.uploadFile(machineType, remotePath, buffer);
        console.log(`[SirenManager Backend] upload OK: ${remotePath}`);
        res.json({ success: true });
    } catch (error) {
        console.error('[SirenManager Backend] SSH error:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

// POST /api/ssh/sync-dir
// Body: { sourceMachine, sourcePath, targets: [{ machineType, remotePath }, …] }
// Tars the source dir on the master, pipes the buffer into `tar x` on each
// target. Returns per-target success/error so the UI can show partial results.
app.post('/api/ssh/sync-dir', async (req, res) => {
    try {
        const { sourceMachine, sourcePath, targets } = req.body;
        console.log(`[SirenManager Backend] sync-dir: source=${sourceMachine}:${sourcePath} → ${targets.length} target(s)`);
        const tarBuffer = await sshProxy.tarRemote(sourceMachine, sourcePath);
        console.log(`[SirenManager Backend] sync-dir: tarball size=${tarBuffer.length}`);

        const results = [];
        for (const tgt of targets) {
            try {
                await sshProxy.untarRemote(tgt.machineType, tgt.remotePath, tarBuffer);
                results.push({ machine: tgt.machineType, success: true });
                console.log(`[SirenManager Backend] sync-dir: ✓ ${tgt.machineType}`);
            } catch (e) {
                results.push({ machine: tgt.machineType, success: false, error: e.message });
                console.log(`[SirenManager Backend] sync-dir: ✗ ${tgt.machineType}: ${e.message}`);
            }
        }
        res.json({ success: true, tarSize: tarBuffer.length, results });
    } catch (error) {
        console.error('[SirenManager Backend] sync-dir error:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

// Start HTTP server
app.listen(HTTP_PORT, () => {
    console.log(`[SirenManager Backend] HTTP server listening on port ${HTTP_PORT}`);
});

// WebSocket server for UDP proxy and real-time communication
const wss = new WebSocket.Server({ port: WS_PORT });

// UDP socket is bound LAZILY: only when at least one WebSocket client is
// connected (i.e. WASM/browser mode that actually needs UDP relayed). This
// avoids competing with a desktop SirenManager process for port 8000 — the
// firmware sends to a hardcoded set of client IPs on 8000, and two listeners
// on the same port would split the inbound traffic between them.
let udpSocket = null;
let wsClientCount = 0;

function ensureUdpBound() {
    if (udpSocket) return;
    udpSocket = dgram.createSocket('udp4');
    udpSocket.bind(UDP_PORT, () => {
        console.log(`[SirenManager Backend] UDP socket bound to port ${UDP_PORT} (WS client connected)`);
    });
    udpSocket.on('error', (err) => {
        console.error('[SirenManager Backend] UDP socket error:', err);
    });
    udpSocket.on('message', (msg, rinfo) => {
        const data = {
            type: 'udp_receive',
            data: msg.toString('hex'),
            address: rinfo.address,
            port: rinfo.port
        };
        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify(data));
            }
        });
    });
}

function maybeReleaseUdp() {
    if (wsClientCount === 0 && udpSocket) {
        udpSocket.close(() => {
            console.log(`[SirenManager Backend] UDP socket released (no WS clients)`);
        });
        udpSocket = null;
    }
}

wss.on('connection', (ws) => {
    wsClientCount++;
    console.log(`[SirenManager Backend] WebSocket client connected (total ${wsClientCount})`);
    ensureUdpBound();

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message.toString());

            if (data.type === 'udp_send') {
                if (!udpSocket) {
                    ws.send(JSON.stringify({ type: 'error', message: 'UDP socket not bound' }));
                    return;
                }
                const packet = Buffer.from(data.data, 'hex');
                const address = data.address;
                const port = data.port;

                udpSocket.send(packet, port, address, (err) => {
                    if (err) {
                        console.error('[SirenManager Backend] UDP send error:', err);
                        ws.send(JSON.stringify({ type: 'error', message: err.message }));
                    }
                });
            }
        } catch (error) {
            console.error('[SirenManager Backend] WebSocket message error:', error);
            ws.send(JSON.stringify({ type: 'error', message: error.message }));
        }
    });

    ws.on('close', () => {
        wsClientCount = Math.max(0, wsClientCount - 1);
        console.log(`[SirenManager Backend] WebSocket client disconnected (remaining ${wsClientCount})`);
        maybeReleaseUdp();
    });
});

console.log(`[SirenManager Backend] WebSocket server listening on port ${WS_PORT}`);
console.log(`[SirenManager Backend] UDP socket will bind to port ${UDP_PORT} on first WebSocket connection`);
console.log('[SirenManager Backend] Backend service started');
