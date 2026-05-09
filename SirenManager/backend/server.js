const express = require('express');
const WebSocket = require('ws');
const dgram = require('dgram');
const cors = require('cors');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
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
// Body: { sourceMachine, sourcePath, targets: [{ machineType, remotePath }, …],
//         mirror?: bool, mirrorPattern?: string (glob like "*.mid") }
// Tars the source dir on the master, pipes the buffer into `tar x` on each
// target. When `mirror` is true, each target's files matching `mirrorPattern`
// that are NOT in the source dir get rm'd before the untar — so the sync
// becomes a true mirror, not just additive. Returns per-target success/error
// + `removed` count so the UI can show what was deleted.
app.post('/api/ssh/sync-dir', async (req, res) => {
    try {
        const { sourceMachine, sourcePath, targets,
                mirror = false, mirrorPattern, dryRun = false } = req.body;
        console.log(`[SirenManager Backend] sync-dir: source=${sourceMachine}:${sourcePath} → ${targets.length} target(s)${mirror ? ` mirror=${mirrorPattern}` : ''}${dryRun ? ' DRY-RUN' : ''}`);

        if (mirror && !mirrorPattern) {
            return res.status(400).json({ success: false,
                error: 'mirrorPattern is required when mirror=true' });
        }
        if (dryRun && !mirror) {
            return res.status(400).json({ success: false,
                error: 'dryRun only meaningful when mirror=true' });
        }

        // When mirroring, fetch the source file list FIRST. If the master is
        // unreachable we want to abort before touching any target — otherwise
        // an empty source list would look like "everything is orphan" and
        // wipe targets clean.
        let sourceFiles = null;
        if (mirror) {
            sourceFiles = await sshProxy.listFiles(sourceMachine, sourcePath, mirrorPattern);
            console.log(`[SirenManager Backend] sync-dir: source has ${sourceFiles.length} file(s) matching ${mirrorPattern}`);
        }

        // Skip the actual tar in dry-run mode: we only want the orphan list
        // for each target, no data transfer needed.
        const tarBuffer = dryRun ? null : await sshProxy.tarRemote(sourceMachine, sourcePath);
        if (tarBuffer) {
            console.log(`[SirenManager Backend] sync-dir: tarball size=${tarBuffer.length}`);
        }

        const results = [];
        for (const tgt of targets) {
            try {
                let removed = 0;
                let orphans = [];
                if (mirror) {
                    const targetFiles = await sshProxy.listFiles(tgt.machineType, tgt.remotePath, mirrorPattern);
                    const sourceSet = new Set(sourceFiles);
                    orphans = targetFiles.filter((f) => !sourceSet.has(f));
                    if (orphans.length > 0 && !dryRun) {
                        await sshProxy.removeFiles(tgt.machineType, tgt.remotePath, orphans);
                        removed = orphans.length;
                        console.log(`[SirenManager Backend] sync-dir: ${tgt.machineType} - removed ${removed} orphan(s): ${orphans.join(', ')}`);
                    } else if (orphans.length > 0) {
                        console.log(`[SirenManager Backend] sync-dir: ${tgt.machineType} - WOULD remove ${orphans.length} orphan(s) (dry-run)`);
                    }
                }
                if (!dryRun) {
                    await sshProxy.untarRemote(tgt.machineType, tgt.remotePath, tarBuffer);
                }
                results.push({ machine: tgt.machineType, success: true,
                               removed, orphans, dryRun });
                console.log(`[SirenManager Backend] sync-dir: ✓ ${tgt.machineType}${removed > 0 ? ` (-${removed})` : ''}${dryRun ? ' (dry-run)' : ''}`);
            } catch (e) {
                results.push({ machine: tgt.machineType, success: false, error: e.message });
                console.log(`[SirenManager Backend] sync-dir: ✗ ${tgt.machineType}: ${e.message}`);
            }
        }
        res.json({ success: true,
                   tarSize: tarBuffer ? tarBuffer.length : 0,
                   dryRun, results });
    } catch (error) {
        console.error('[SirenManager Backend] sync-dir error:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

// POST /api/keys/export
// Bundles ~/.ssh/id_rsa_sirenes(.pub) + Host blocks from ~/.ssh/config matching
// the siren aliases into a tar.gz dropped in ~/Downloads/. Returns the archive
// path so the UI can offer to reveal it. Used to clone SSH access onto a
// second control machine without redoing ssh-copy-id from scratch (the new
// machine just runs the bundled INSTALL.sh and inherits the same identity).
const SIREN_ALIASES = [
    'linux-maître', 'raspberry-clic',
    'sirene-s1', 'sirene-s2', 'sirene-s3', 'sirene-s4',
    'sirene-s5', 'sirene-s6', 'sirene-s7',
    'voiture-a', 'voiture-b', 'pavillon-1', 'pavillon-2'
];

// Pull every "Host <alias>" block (alias + indented body up to next Host or
// EOF) out of an ssh_config text. Only emits blocks whose alias is in the
// allow-list — avoids leaking unrelated entries the user has on their machine.
function extractHostBlocks(sshConfigText, allowedAliases) {
    const lines = sshConfigText.split('\n');
    const blocks = [];
    let current = null;   // { alias, lines: [] }

    const flush = () => {
        if (current && allowedAliases.includes(current.alias)) {
            // Trim trailing empty lines from the block
            while (current.lines.length > 0 && current.lines[current.lines.length - 1].trim() === '') {
                current.lines.pop();
            }
            blocks.push(current.lines.join('\n'));
        }
        current = null;
    };

    for (const line of lines) {
        const m = line.match(/^\s*Host\s+(.+?)\s*$/);
        if (m) {
            flush();
            // Host directive can list multiple names; we use the first as the key.
            const aliases = m[1].split(/\s+/);
            current = { alias: aliases[0], lines: [line] };
        } else if (current) {
            current.lines.push(line);
        }
    }
    flush();
    return blocks;
}

const INSTALL_SH = `#!/bin/sh
# SirenManager — install SSH keys + Host aliases on a second control machine.
# Compat: macOS 10.15+, Linux. POSIX sh only.
set -e

GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
NC='\\033[0m'
info() { printf "\${GREEN}[INFO]\${NC} %s\\n" "$1"; }
warn() { printf "\${YELLOW}[WARN]\${NC} %s\\n" "$1"; }
err()  { printf "\${RED}[ERR]\${NC} %s\\n" "$1"; }

ask() {
    printf "%s [y/N] " "$1"
    read answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

DIR=$(cd "$(dirname "$0")" && pwd)
SSH_DIR="$HOME/.ssh"
KEY_NAME="id_rsa_sirenes"
CFG="$SSH_DIR/config"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# ---- Step 1: install the private + public key ----
if [ -f "$SSH_DIR/$KEY_NAME" ]; then
    warn "$SSH_DIR/$KEY_NAME existe déjà."
    if ask "Écraser ?"; then
        cp "$DIR/$KEY_NAME" "$SSH_DIR/$KEY_NAME"
        cp "$DIR/$KEY_NAME.pub" "$SSH_DIR/$KEY_NAME.pub"
        chmod 600 "$SSH_DIR/$KEY_NAME"
        chmod 644 "$SSH_DIR/$KEY_NAME.pub"
        info "Clé écrasée."
    else
        info "Skip clé."
    fi
else
    cp "$DIR/$KEY_NAME" "$SSH_DIR/$KEY_NAME"
    cp "$DIR/$KEY_NAME.pub" "$SSH_DIR/$KEY_NAME.pub"
    chmod 600 "$SSH_DIR/$KEY_NAME"
    chmod 644 "$SSH_DIR/$KEY_NAME.pub"
    info "Clé installée: $SSH_DIR/$KEY_NAME"
fi

# ---- Step 2: install Host aliases (skip the ones already present) ----
touch "$CFG"
chmod 600 "$CFG"

# Existing Host names in $CFG, space-separated.
EXISTING=$(awk '/^[[:space:]]*Host[[:space:]]+/ { for(i=2;i<=NF;i++) print $i }' "$CFG" | tr '\\n' ' ')
TO_ADD=""
while IFS= read -r line; do
    case "$line" in
        "Host "*|"  Host "*)
            for a in $(printf "%s" "$line" | sed 's/^[[:space:]]*Host[[:space:]]*//'); do
                if printf " %s " "$EXISTING" | grep -q " $a "; then
                    warn "Host '$a' déjà présent dans $CFG, skip"
                else
                    TO_ADD="$TO_ADD $a"
                fi
            done
            ;;
    esac
done < "$DIR/ssh_config_sirens"

if [ -z "$TO_ADD" ]; then
    info "Tous les Host alias sont déjà dans $CFG."
elif [ "$EXISTING" = "" ] || [ "$(echo $TO_ADD | wc -w)" = "$(awk '/^[[:space:]]*Host[[:space:]]+/' "$DIR/ssh_config_sirens" | wc -l)" ]; then
    info "Aliases à ajouter:$TO_ADD"
    if ask "Append au $CFG ?"; then
        printf "\\n# SirenManager — added %s\\n" "$(date +%Y-%m-%d)" >> "$CFG"
        cat "$DIR/ssh_config_sirens" >> "$CFG"
        info "Aliases ajoutés à $CFG."
    else
        info "Skip aliases."
    fi
else
    warn "Conflit partiel — certains Host sont déjà là, d'autres non."
    warn "À toi de merger manuellement: ouvre $CFG et $DIR/ssh_config_sirens."
fi

info "Terminé. Test: ssh linux-maître 'echo OK' (réseau requis)"
`;

const README_TXT = `SirenManager — archive de clés SSH

CONTENU
-------
  id_rsa_sirenes        — clé privée OpenSSH (mode 600 attendu)
  id_rsa_sirenes.pub    — clé publique
  ssh_config_sirens     — blocs "Host <alias>" pour les 13 sirènes (algos legacy SHA-1)
  INSTALL.sh            — script POSIX d'installation interactif (macOS 10.15+, Linux)
  README.txt            — ce fichier

USAGE
-----
  $ tar xzf sirenmanager-keys-*.tar.gz
  $ cd sirenmanager-keys-*
  $ ./INSTALL.sh

Le script demande confirmation avant d'écraser quoi que ce soit dans
~/.ssh/. Idempotent: les Host alias déjà présents sont skip.

SÉCURITÉ
--------
La clé privée donne un accès root à toutes les sirènes. À transférer
via canal sûr (USB, scp, AirDrop), jamais par email/Slack/git.

Si la machine cible doit utiliser une AUTRE clé, la procédure persist-key
côté Artila doit être ré-appliquée pour snapshot la nouvelle authorized_keys
(voir README projet, section "SSH key persistence").
`;

app.post('/api/keys/export', async (req, res) => {
    try {
        const home = os.homedir();
        const sshDir = path.join(home, '.ssh');
        const keyPath = path.join(sshDir, 'id_rsa_sirenes');
        const pubPath = keyPath + '.pub';
        const cfgPath = path.join(sshDir, 'config');

        if (!fs.existsSync(keyPath) || !fs.existsSync(pubPath)) {
            return res.status(404).json({
                success: false,
                error: `Clé absente: ${keyPath}. Lance d'abord scripts/setup-ssh.sh.`
            });
        }

        // Build the bundle in a temp dir, then tar.gz it into ~/Downloads/.
        const ts = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '_');
        const stem = `sirenmanager-keys-${ts}`;
        const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sirenmanager-keys-'));
        const tmpBundle = path.join(tmpRoot, stem);
        fs.mkdirSync(tmpBundle);

        // 1. Keys
        fs.copyFileSync(keyPath, path.join(tmpBundle, 'id_rsa_sirenes'));
        fs.chmodSync(path.join(tmpBundle, 'id_rsa_sirenes'), 0o600);
        fs.copyFileSync(pubPath, path.join(tmpBundle, 'id_rsa_sirenes.pub'));
        fs.chmodSync(path.join(tmpBundle, 'id_rsa_sirenes.pub'), 0o644);

        // 2. Host blocks (only siren aliases). Normalize IdentityFile paths
        // to "~/.ssh/id_rsa_sirenes" so the bundle is portable across hosts
        // (the source machine's absolute /Users/<name>/.ssh/... won't resolve
        // on the receiving machine if the user name differs).
        let blocks = [];
        if (fs.existsSync(cfgPath)) {
            const cfgText = fs.readFileSync(cfgPath, 'utf8');
            blocks = extractHostBlocks(cfgText, SIREN_ALIASES);
        }
        const blocksNormalized = blocks.map(b =>
            b.replace(/^(\s*IdentityFile\s+).*id_rsa_sirenes(\.pub)?\s*$/gm,
                      '$1~/.ssh/id_rsa_sirenes$2'));
        const blocksText = blocksNormalized.length > 0
            ? blocksNormalized.join('\n\n') + '\n'
            : '# (no Host blocks found in ~/.ssh/config — run scripts/setup-ssh.sh --config first)\n';
        fs.writeFileSync(path.join(tmpBundle, 'ssh_config_sirens'), blocksText);

        // 3. INSTALL.sh + README
        fs.writeFileSync(path.join(tmpBundle, 'INSTALL.sh'), INSTALL_SH, { mode: 0o755 });
        fs.writeFileSync(path.join(tmpBundle, 'README.txt'), README_TXT);

        // 4. Tar.gz into ~/Downloads (or ~ if Downloads doesn't exist)
        const downloadsDir = path.join(home, 'Downloads');
        const outDir = fs.existsSync(downloadsDir) ? downloadsDir : home;
        const outPath = path.join(outDir, stem + '.tar.gz');

        const r = spawnSync('tar', ['czf', outPath, '-C', tmpRoot, stem], { stdio: 'pipe' });
        if (r.status !== 0) {
            return res.status(500).json({
                success: false,
                error: `tar failed: ${r.stderr ? r.stderr.toString() : 'unknown'}`
            });
        }
        // Best-effort cleanup of tmp.
        fs.rmSync(tmpRoot, { recursive: true, force: true });

        const aliasesFound = blocks.length;
        console.log(`[SirenManager Backend] keys/export: ${outPath} (${aliasesFound} aliases)`);
        res.json({ success: true, path: outPath, aliasesFound });
    } catch (error) {
        console.error('[SirenManager Backend] keys/export error:', error.message);
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
