const express = require('express');
const WebSocket = require('ws');
const dgram = require('dgram');
const cors = require('cors');
const SshProxy = require('./ssh-proxy');
const config = require('./config.json');

const app = express();
app.use(cors());
app.use(express.json());

const HTTP_PORT = config.ports.http || 8005;
const WS_PORT = config.ports.websocket || 8006;
const UDP_PORT = config.ports.udp || 4443;

// Initialize SSH proxy
const sshProxy = new SshProxy(config);

// HTTP Routes for SSH operations
app.post('/api/ssh/execute', async (req, res) => {
    try {
        const { machineType, command } = req.body;
        const output = await sshProxy.executeCommand(machineType, command);
        res.json({ success: true, output });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/ssh/download', async (req, res) => {
    try {
        const { machineType, remotePath } = req.body;
        const content = await sshProxy.downloadFile(machineType, remotePath);
        res.json({ success: true, content });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/ssh/upload', async (req, res) => {
    try {
        const { machineType, remotePath, content } = req.body;
        await sshProxy.uploadFile(machineType, remotePath, content);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Start HTTP server
app.listen(HTTP_PORT, () => {
    console.log(`[SirenManager Backend] HTTP server listening on port ${HTTP_PORT}`);
});

// WebSocket server for UDP proxy and real-time communication
const wss = new WebSocket.Server({ port: WS_PORT });

// UDP socket for proxy
const udpSocket = dgram.createSocket('udp4');
udpSocket.bind(UDP_PORT, () => {
    console.log(`[SirenManager Backend] UDP socket bound to port ${UDP_PORT}`);
});

wss.on('connection', (ws) => {
    console.log('[SirenManager Backend] WebSocket client connected');

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message.toString());
            
            if (data.type === 'udp_send') {
                // Forward UDP packet
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
        console.log('[SirenManager Backend] WebSocket client disconnected');
    });
});

// Forward received UDP packets to WebSocket clients
udpSocket.on('message', (msg, rinfo) => {
    const data = {
        type: 'udp_receive',
        data: msg.toString('hex'),
        address: rinfo.address,
        port: rinfo.port
    };

    // Broadcast to all connected WebSocket clients
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(data));
        }
    });
});

console.log(`[SirenManager Backend] WebSocket server listening on port ${WS_PORT}`);
console.log('[SirenManager Backend] Backend service started');


