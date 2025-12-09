#!/usr/bin/env node

// Script de test simple pour vérifier que le serveur fonctionne

const http = require('http');

const PORT = 8080;

console.log('🧪 Test du serveur SirenManager...\n');

const testUrls = [
    '/',
    '/index.html',
    '/appSirenManager.html',
    '/appSirenManager.js',
    '/appSirenManager.wasm',
    '/qtloader.js'
];

let testsCompleted = 0;
let testsPassed = 0;
let testsFailed = 0;

function testUrl(url) {
    return new Promise((resolve) => {
        const options = {
            hostname: 'localhost',
            port: PORT,
            path: url,
            method: 'GET'
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => {
                data += chunk;
            });
            res.on('end', () => {
                const success = res.statusCode === 200;
                if (success) {
                    testsPassed++;
                    console.log(`✅ ${url.padEnd(30)} [${res.statusCode}] ${(data.length / 1024).toFixed(2)} KB`);
                } else {
                    testsFailed++;
                    console.log(`❌ ${url.padEnd(30)} [${res.statusCode}]`);
                }
                testsCompleted++;
                resolve();
            });
        });

        req.on('error', (error) => {
            testsFailed++;
            console.log(`❌ ${url.padEnd(30)} [ERROR] ${error.message}`);
            testsCompleted++;
            resolve();
        });

        req.setTimeout(5000, () => {
            testsFailed++;
            console.log(`❌ ${url.padEnd(30)} [TIMEOUT]`);
            testsCompleted++;
            req.destroy();
            resolve();
        });

        req.end();
    });
}

async function runTests() {
    console.log(`📡 Test des URLs sur http://localhost:${PORT}/\n`);

    // Vérifier d'abord si le serveur répond
    try {
        await testUrl('/');
    } catch (error) {
        console.error(`\n❌ Le serveur ne répond pas sur le port ${PORT}`);
        console.error(`   Assurez-vous que le serveur est démarré :`);
        console.error(`   node server.js\n`);
        process.exit(1);
    }

    // Tester toutes les URLs
    for (const url of testUrls) {
        await testUrl(url);
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    // Résumé
    console.log('\n' + '='.repeat(50));
    console.log(`📊 Résultats :`);
    console.log(`   ✅ Réussis : ${testsPassed}`);
    console.log(`   ❌ Échoués : ${testsFailed}`);
    console.log(`   📦 Total   : ${testsCompleted}`);
    console.log('='.repeat(50) + '\n');

    if (testsFailed > 0) {
        console.log('⚠️  Certains fichiers sont manquants ou le serveur ne répond pas correctement.');
        console.log('   Vérifiez que tous les fichiers sont présents dans webfiles/');
        process.exit(1);
    } else {
        console.log('✅ Tous les tests sont passés ! Le serveur fonctionne correctement.\n');
        console.log('🌐 Ouvrez http://localhost:8080/ dans votre navigateur\n');
        process.exit(0);
    }
}

runTests();


