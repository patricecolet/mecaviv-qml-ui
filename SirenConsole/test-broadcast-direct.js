#!/usr/bin/env node

// Script pour forcer l'envoi de PUPITRE_CONNECTED directement depuis le serveur
// Ce script doit être exécuté depuis le répertoire webfiles où se trouve server.js

const pupitreId = process.argv[2] || 'P1';

// Charger le serveur et accéder à broadcastToClients
// Note: Ceci nécessite que le serveur soit en cours d'exécution
// On va plutôt utiliser une connexion WebSocket directe

console.log(`⚠️  Pour que ce script fonctionne, le serveur doit être redémarré avec le nouveau code.`);
console.log(`📤 Sinon, utilisez: curl -k -X POST "https://127.0.0.1:8001/api/test/pupitre-connected" -H "Content-Type: application/json" -d '{"pupitreId":"${pupitreId}"}'`);
console.log(`\n💡 Le serveur doit être redémarré pour que l'endpoint /api/test/pupitre-connected soit disponible.`);
