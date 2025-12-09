const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');
const os = require('os');

class SshProxy {
    constructor(config) {
        this.config = config;
    }

    /**
     * Execute SSH command on remote machine
     */
    async executeCommand(machineType, command) {
        return new Promise((resolve, reject) => {
            const machineConfig = this.getMachineConfig(machineType);
            if (!machineConfig) {
                return reject(new Error(`Unknown machine type: ${machineType}`));
            }

            const conn = new Client();
            let output = '';
            let error = '';

            conn.on('ready', () => {
                conn.exec(command, (err, stream) => {
                    if (err) {
                        conn.end();
                        return reject(err);
                    }

                    stream.on('close', (code, signal) => {
                        conn.end();
                        if (code !== 0) {
                            return reject(new Error(`Command failed with code ${code}: ${error || output}`));
                        }
                        resolve(output);
                    });

                    stream.on('data', (data) => {
                        output += data.toString();
                    });

                    stream.stderr.on('data', (data) => {
                        error += data.toString();
                    });
                });
            });

            conn.on('error', (err) => {
                reject(err);
            });

            // Connect with SSH key
            const sshKeyPath = machineConfig.sshKeyPath.replace('~', os.homedir());
            const privateKey = fs.readFileSync(sshKeyPath, 'utf8');

            conn.connect({
                host: machineConfig.ip,
                username: machineConfig.sshUser,
                privateKey: privateKey,
                readyTimeout: 5000,
                algorithms: {
                    kex: ['diffie-hellman-group1-sha1', 'diffie-hellman-group14-sha1'],
                    cipher: ['aes128-ctr', 'aes192-ctr', 'aes256-ctr', 'aes128-gcm', 'aes256-gcm']
                }
            });
        });
    }

    /**
     * Download file from remote machine
     */
    async downloadFile(machineType, remotePath) {
        return new Promise((resolve, reject) => {
            const machineConfig = this.getMachineConfig(machineType);
            if (!machineConfig) {
                return reject(new Error(`Unknown machine type: ${machineType}`));
            }

            const conn = new Client();

            conn.on('ready', () => {
                conn.sftp((err, sftp) => {
                    if (err) {
                        conn.end();
                        return reject(err);
                    }

                    sftp.readFile(remotePath, (err, data) => {
                        conn.end();
                        if (err) {
                            return reject(err);
                        }
                        resolve(data.toString());
                    });
                });
            });

            conn.on('error', (err) => {
                reject(err);
            });

            const sshKeyPath = machineConfig.sshKeyPath.replace('~', os.homedir());
            const privateKey = fs.readFileSync(sshKeyPath, 'utf8');

            conn.connect({
                host: machineConfig.ip,
                username: machineConfig.sshUser,
                privateKey: privateKey,
                readyTimeout: 5000
            });
        });
    }

    /**
     * Upload file to remote machine
     */
    async uploadFile(machineType, remotePath, content) {
        return new Promise((resolve, reject) => {
            const machineConfig = this.getMachineConfig(machineType);
            if (!machineConfig) {
                return reject(new Error(`Unknown machine type: ${machineType}`));
            }

            const conn = new Client();

            conn.on('ready', () => {
                conn.sftp((err, sftp) => {
                    if (err) {
                        conn.end();
                        return reject(err);
                    }

                    sftp.writeFile(remotePath, content, (err) => {
                        conn.end();
                        if (err) {
                            return reject(err);
                        }
                        resolve();
                    });
                });
            });

            conn.on('error', (err) => {
                reject(err);
            });

            const sshKeyPath = machineConfig.sshKeyPath.replace('~', os.homedir());
            const privateKey = fs.readFileSync(sshKeyPath, 'utf8');

            conn.connect({
                host: machineConfig.ip,
                username: machineConfig.sshUser,
                privateKey: privateKey,
                readyTimeout: 5000
            });
        });
    }

    getMachineConfig(machineType) {
        const machineMap = {
            'linuxMaitre': 'linuxMaitre',
            'raspberryClic': 'raspberryClic',
            's1': 's1',
            's2': 's2',
            's3': 's3',
            's4': 's4',
            's5': 's5',
            's6': 's6',
            's7': 's7',
            'voitureA': 'voitureA',
            'voitureB': 'voitureB',
            'pavillon1': 'pavillon1',
            'pavillon2': 'pavillon2'
        };

        const configKey = machineMap[machineType];
        return configKey ? this.config.machines[configKey] : null;
    }
}

module.exports = SshProxy;


