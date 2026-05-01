// SSH proxy backed by the system `ssh` / `scp` binaries via child_process.
// This intentionally delegates all auth, key selection, port and host alias
// decisions to the user's ~/.ssh/config — we don't read keys ourselves. If
// a host's Host entry in ~/.ssh/config defines IdentityFile / User / Port,
// it Just Works.
//
// To target a config alias rather than user@ip, set `sshAlias` in
// backend/config.json for that machine. Otherwise we fall back to user@ip.
//
// Uploads pipe content through `ssh host 'cat > remotePath'` instead of
// scp — busybox sirens often ship without scp, and the legacy SireneControlMac
// app does the same (see its README).

const { exec, spawn } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

class SshProxy {
    constructor(config) {
        this.config = config;
    }

    sshTarget(machineType) {
        const cfg = this.getMachineConfig(machineType);
        if (!cfg) throw new Error(`Unknown machine type: ${machineType}`);
        // Prefer an explicit ~/.ssh/config alias when configured.
        if (cfg.sshAlias && cfg.sshAlias.length > 0) return cfg.sshAlias;
        return `${cfg.sshUser}@${cfg.ip}`;
    }

    sshOpts() {
        // BatchMode=yes makes ssh fail fast on missing keys / password prompts
        // (we don't have a TTY). ConnectTimeout caps the wait when a host is
        // unreachable so the HTTP request doesn't hang for 30+ seconds.
        //
        // We deliberately don't override KexAlgorithms / HostKeyAlgorithms /
        // PubkeyAcceptedAlgorithms — the Artila M508 sirens need legacy SHA-1
        // versions of those, but it's the user's ~/.ssh/config Host entries
        // that should declare them (per-host, not global). Hardcoding them
        // here both duplicated the alias config AND broke on newer OpenSSH
        // versions where some of the older algorithm names are no longer
        // recognized as input.
        return [
            '-o', 'BatchMode=yes',
            '-o', 'ConnectTimeout=5',
            '-o', 'StrictHostKeyChecking=accept-new',
            '-o', 'ForwardX11=no'   // some user configs enable X11 forwarding globally; the sirens have no xauth
        ];
    }

    async executeCommand(machineType, command) {
        const target = this.sshTarget(machineType);
        return new Promise((resolve, reject) => {
            const args = [...this.sshOpts(), target, command];
            const child = spawn('ssh', args);
            let stdout = '', stderr = '';
            child.stdout.on('data', (d) => { stdout += d.toString(); });
            child.stderr.on('data', (d) => { stderr += d.toString(); });
            child.on('error', reject);
            child.on('close', (code) => {
                if (code !== 0) {
                    return reject(new Error(`ssh exited ${code}: ${stderr.trim() || stdout.trim() || 'no output'}`));
                }
                resolve(stdout);
            });
        });
    }

    async downloadFile(machineType, remotePath) {
        // `cat remotePath` over ssh — works on busybox where scp may be absent.
        const target = this.sshTarget(machineType);
        return new Promise((resolve, reject) => {
            const args = [...this.sshOpts(), target, 'cat', this.shellQuote(remotePath)];
            const child = spawn('ssh', args);
            const chunks = [];
            let stderr = '';
            child.stdout.on('data', (d) => chunks.push(d));
            child.stderr.on('data', (d) => { stderr += d.toString(); });
            child.on('error', reject);
            child.on('close', (code) => {
                if (code !== 0) {
                    return reject(new Error(`ssh cat exited ${code}: ${stderr.trim() || 'no output'}`));
                }
                resolve(Buffer.concat(chunks).toString('utf8'));
            });
        });
    }

    async uploadFile(machineType, remotePath, content) {
        // Pipe local content into a remote `cat > path`.
        const target = this.sshTarget(machineType);
        return new Promise((resolve, reject) => {
            const args = [...this.sshOpts(), target, `cat > ${this.shellQuote(remotePath)}`];
            const child = spawn('ssh', args);
            let stderr = '';
            child.stderr.on('data', (d) => { stderr += d.toString(); });
            child.on('error', reject);
            child.on('close', (code) => {
                if (code !== 0) {
                    return reject(new Error(`ssh upload exited ${code}: ${stderr.trim() || 'no output'}`));
                }
                resolve();
            });
            child.stdin.end(content);
        });
    }

    shellQuote(s) {
        // Single-quote and escape any embedded single quotes for a remote shell.
        return `'${String(s).replace(/'/g, `'\\''`)}'`;
    }

    getMachineConfig(machineType) {
        const map = {
            linuxMaitre: 'linuxMaitre',
            raspberryClic: 'raspberryClic',
            s1: 's1', s2: 's2', s3: 's3', s4: 's4', s5: 's5', s6: 's6', s7: 's7',
            voitureA: 'voitureA', voitureB: 'voitureB',
            pavillon1: 'pavillon1', pavillon2: 'pavillon2'
        };
        const k = map[machineType];
        return k ? this.config.machines[k] : null;
    }
}

module.exports = SshProxy;
