#!/usr/bin/env node

/**
 * Script de test pour le mode jeu - Format binaire
 * 
 * Usage: node test-game-notes.js
 */

const WebSocket = require('ws');

const WS_URL = 'ws://localhost:10002';

// Gamme Do majeur
const NOTES = [60, 62, 64, 65, 67, 69, 71, 72];
const INTERVAL = 500; // ms entre chaque note
const VELOCITY = 100;

console.log('🎮 Test du Mode Jeu - Format Binaire\n');

const ws = new WebSocket(WS_URL);

ws.on('open', () => {
    console.log('✅ Connecté à SirenePupitre\n');
    console.log('📊 Envoi de', NOTES.length, 'notes...\n');
    
    NOTES.forEach((note, index) => {
        setTimeout(() => {
            // Créer le buffer binaire simple (3 bytes)
            const buffer = Buffer.from([
                0x03,       // Type NOTE_ON
                note,       // Note MIDI
                VELOCITY    // Velocity
            ]);
            
            console.log(`🎵 [${index + 1}/${NOTES.length}] Note ${note} → bytes: [0x03, ${note}, ${VELOCITY}]`);
            
            ws.send(buffer);
        }, index * INTERVAL);
    });
    
    // Fermer après avoir envoyé toutes les notes
    setTimeout(() => {
        console.log('\n✅ Test terminé !');
        console.log('📊 Total:', NOTES.length, 'notes envoyées');
        console.log('📦 Taille totale:', NOTES.length * 3, 'bytes');
        console.log('🚀 Débit:', (NOTES.length * 3) / (NOTES.length * INTERVAL / 1000), 'bytes/sec\n');
        ws.close();
    }, NOTES.length * INTERVAL + 1000);
});

ws.on('error', (error) => {
    console.error('❌ Erreur WebSocket:', error.message);
    console.error('💡 Assure-toi que SirenePupitre est lancé et en mode jeu');
    process.exit(1);
});

ws.on('close', () => {
    console.log('👋 Déconnexion');
    process.exit(0);
});

