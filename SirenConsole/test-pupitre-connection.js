#!/usr/bin/env node

// Script temporaire pour tester l'envoi de messages PUPITRE_CONNECTED
// Usage: node test-pupitre-connection.js P1

const WebSocket = require('ws');

const pupitreId = process.argv[2] || 'P1';
const wsUrl = 'wss://127.0.0.1:8001/ws';

console.log(`Connexion au serveur WebSocket: ${wsUrl}`);
const ws = new WebSocket(wsUrl, {
    rejectUnauthorized: false // Accepter les certificats auto-signés
});

ws.on('open', () => {
    console.log('✅ Connecté au serveur WebSocket');
    
    // S'identifier comme client SirenConsole
    ws.send(JSON.stringify({
        type: 'SIRENCONSOLE_IDENTIFICATION',
        source: 'TEST_SCRIPT',
        timestamp: Date.now()
    }));
    
    // Attendre un peu puis envoyer un message PUPITRE_CONNECTED simulé
    setTimeout(() => {
        console.log(`📤 Envoi PUPITRE_CONNECTED pour ${pupitreId}`);
        ws.send(JSON.stringify({
            type: 'PUPITRE_CONNECTED',
            pupitreId: pupitreId,
            pupitreName: `Pupitre ${pupitreId}`,
            connected: true,
            timestamp: Date.now()
        }));
        
        // Attendre un peu puis fermer
        setTimeout(() => {
            console.log('✅ Message envoyé, fermeture de la connexion');
            ws.close();
            process.exit(0);
        }, 1000);
    }, 500);
});

ws.on('error', (error) => {
    console.error('❌ Erreur WebSocket:', error.message);
    process.exit(1);
});

ws.on('message', (message) => {
    try {
        const data = JSON.parse(message.toString());
        if (data.type === 'INITIAL_STATUS') {
            console.log('📥 INITIAL_STATUS reçu');
        } else if (data.type === 'PUPITRE_STATUS_UPDATE') {
            console.log('📥 PUPITRE_STATUS_UPDATE reçu');
        } else {
            console.log('📥 Message reçu:', data.type);
        }
    } catch (e) {
        // Ignorer les messages non-JSON
    }
});
