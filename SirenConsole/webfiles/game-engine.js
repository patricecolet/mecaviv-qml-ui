/**
 * Moteur de Jeu "Siren Hero" 
 * Coordinateur multi-joueurs pour les 7 pupitres
 * 
 * Architecture :
 * - GameEngine (Node.js) = Coordinateur central
 * - PureData (7× Raspberry) = Moteur de jeu individuel (calcul score)
 * - SirenePupitre (QML) = Interface visuelle
 */
class GameEngine {
    constructor(pureDataProxy) {
        this.pureDataProxy = pureDataProxy;
        
        // État du jeu
        this.gameActive = false;
        this.gameMode = null;        // 'practice', 'performance', 'challenge', 'training'
        this.gameDifficulty = null;  // 'easy', 'normal', 'hard', 'expert'
        this.gameStartTime = 0;
        this.currentMidiFile = '';
        
        // Scores des 7 pupitres
        this.playerScores = new Map(); // pupitreId -> scoreData
        
        // Leaderboard
        this.leaderboard = [];
        this.leaderboardTimer = null;
        
        // Configuration
        this.broadcastInterval = 2000; // Leaderboard toutes les 2s
        
        console.log('🎮 GameEngine initialisé');
    }
    
    /**
     * Démarrer une partie multi-joueurs
     */
    startGame(options) {
        const {
            midiFile,
            mode = 'practice',
            difficulty = 'normal',
            countdown = 3,
            lookaheadMs = 2000,
            toleranceMs = 150,
            showNotes = true,
            practiceMode = false
        } = options;
        
        console.log('🎮 GAME_START:', midiFile, '- Mode:', mode, '- Difficulté:', difficulty);
        
        // Initialiser l'état du jeu
        this.gameActive = true;
        this.gameMode = mode;
        this.gameDifficulty = difficulty;
        this.currentMidiFile = midiFile;
        this.playerScores.clear();
        this.leaderboard = [];
        
        // Timestamp de synchronisation (dans countdown secondes)
        const syncTimestamp = Date.now() + (countdown * 1000);
        this.gameStartTime = syncTimestamp;
        
        // Message GAME_START (JSON) à broadcaster
        const gameStartMessage = {
            type: 'GAME_START',
            midiFile: midiFile,
            mode: mode,
            difficulty: difficulty,
            syncTimestamp: syncTimestamp,
            countdown: countdown,
            options: {
                lookaheadMs: lookaheadMs,
                toleranceMs: toleranceMs,
                showNotes: showNotes,
                practiceMode: practiceMode
            }
        };
        
        // Envoyer à tous les pupitres via PureData
        this.pureDataProxy.sendCommand(gameStartMessage);
        
        // Démarrer le broadcast du leaderboard
        this.startLeaderboardBroadcast();
        
        return {
            success: true,
            syncTimestamp: syncTimestamp,
            message: `Partie lancée - Décompte ${countdown}s`
        };
    }
    
    /**
     * Recevoir un update de score d'un pupitre (GAME_SCORE_UPDATE - binaire 0x11)
     * 
     * Format : 14 bytes
     * Offset | Type    | Champ
     * -------|---------|----------------
     * 0      | uint8   | messageType (0x11)
     * 1      | uint8   | pupitreId (1-7)
     * 2      | uint32  | score (LE)
     * 6      | uint16  | combo (LE)
     * 8      | uint16  | maxCombo (LE)
     * 10     | uint8   | accuracy (0-100%)
     * 11     | uint8   | perfect
     * 12     | uint8   | good
     * 13     | uint8   | miss
     */
    handleScoreUpdate(buffer) {
        if (buffer.length < 14) {
            console.error('❌ GAME_SCORE_UPDATE trop court:', buffer.length, 'bytes (attendu 14)');
            return;
        }
        
        const messageType = buffer.readUInt8(0);  // 0x11
        const pupitreId = buffer.readUInt8(1);
        const score = buffer.readUInt32LE(2);
        const combo = buffer.readUInt16LE(6);
        const maxCombo = buffer.readUInt16LE(8);
        const accuracy = buffer.readUInt8(10);   // 0-100%
        const perfect = buffer.readUInt8(11);
        const good = buffer.readUInt8(12);
        const miss = buffer.readUInt8(13);
        
        // Stocker le score
        this.playerScores.set(pupitreId, {
            pupitreId: pupitreId,
            score: score,
            combo: combo,
            maxCombo: maxCombo,
            accuracy: accuracy,
            perfect: perfect,
            good: good,
            miss: miss,
            lastUpdate: Date.now(),
            finished: false
        });
        
        console.log(`🎯 Score P${pupitreId}: ${score}pts, combo ${combo}, acc ${accuracy}%`);
        
        // Mettre à jour le leaderboard
        this.updateLeaderboard();
    }
    
    /**
     * Recevoir un hit de note (GAME_NOTE_HIT - binaire 0x10)
     * 
     * Format : 9 bytes
     * Offset | Type    | Champ
     * -------|---------|----------------
     * 0      | uint8   | messageType (0x10)
     * 1      | uint8   | pupitreId (1-7)
     * 2      | uint8   | noteNumber (0-127)
     * 3      | uint8   | expectedValue (0-127)
     * 4      | uint8   | actualValue (0-127)
     * 5      | int16   | timingMs (signé, LE)
     * 7      | uint8   | rating (0=miss, 1=good, 2=perfect)
     * 8      | uint8   | scoreGained / 10
     */
    handleNoteHit(buffer) {
        if (buffer.length < 9) {
            console.error('❌ GAME_NOTE_HIT trop court:', buffer.length, 'bytes (attendu 9)');
            return;
        }
        
        const pupitreId = buffer.readUInt8(1);
        const noteNumber = buffer.readUInt8(2);
        const expectedValue = buffer.readUInt8(3);
        const actualValue = buffer.readUInt8(4);
        const timingMs = buffer.readInt16LE(5);
        const rating = buffer.readUInt8(7);      // 0=miss, 1=good, 2=perfect
        const scoreGained = buffer.readUInt8(8) * 10; // × 10 car stocké divisé
        
        const ratingText = ['MISS', 'GOOD', 'PERFECT'][rating] || 'UNKNOWN';
        
        // Log compact (seulement Perfect pour ne pas spam)
        if (rating === 2) {
            console.log(`✨ P${pupitreId} PERFECT: Note ${noteNumber}, ${scoreGained}pts, timing ${timingMs > 0 ? '+' : ''}${timingMs}ms`);
        }
        
        // Ici, on pourrait broadcaster ce hit aux spectateurs
        // ou l'utiliser pour des effets visuels sur la console
    }
    
    /**
     * Fin de partie pour un pupitre (JSON)
     */
    handleGameEnd(message) {
        const { pupitreId, finalScore, accuracy, rank, stats } = message;
        
        console.log(`🏁 P${pupitreId} terminé: ${finalScore}pts, rang ${rank}, acc ${(accuracy*100).toFixed(1)}%`);
        
        // Mettre à jour les stats finales
        if (this.playerScores.has(pupitreId)) {
            const scoreData = this.playerScores.get(pupitreId);
            scoreData.finalScore = finalScore;
            scoreData.accuracy = Math.floor(accuracy * 100);
            scoreData.rank = rank;
            scoreData.stats = stats;
            scoreData.finished = true;
        }
        
        // Vérifier si tous les joueurs ont fini
        const activePlayers = Array.from(this.playerScores.values());
        const allFinished = activePlayers.length > 0 && activePlayers.every(p => p.finished);
        
        if (allFinished) {
            console.log('🎉 Tous les joueurs ont terminé !');
            this.endGame();
        }
    }
    
    /**
     * Mettre à jour le leaderboard
     */
    updateLeaderboard() {
        // Trier par score décroissant
        this.leaderboard = Array.from(this.playerScores.values())
            .sort((a, b) => b.score - a.score)
            .map((player, index) => ({
                rank: index + 1,
                pupitreId: player.pupitreId,
                score: player.score,
                combo: player.maxCombo,
                accuracy: player.accuracy
            }));
    }
    
    /**
     * Broadcaster le leaderboard (GAME_LEADERBOARD - binaire 0x12)
     * 
     * Format : 1 + (N × 9) bytes
     * Header: 1 byte (messageType 0x12)
     * Par joueur (9 bytes) :
     *   Offset | Type    | Champ
     *   -------|---------|----------------
     *   0      | uint8   | rank (1-7)
     *   1      | uint8   | pupitreId (1-7)
     *   2      | uint32  | score (LE)
     *   6      | uint16  | combo (LE)
     *   8      | uint8   | accuracy (0-100%)
     */
    broadcastLeaderboard() {
        if (!this.gameActive || this.leaderboard.length === 0) return;
        
        // Taille: 1 byte header + (9 bytes × N joueurs)
        const bufferSize = 1 + (this.leaderboard.length * 9);
        const buffer = Buffer.allocUnsafe(bufferSize);
        
        // Header
        buffer.writeUInt8(0x12, 0); // messageType
        
        // Chaque joueur (9 bytes)
        let offset = 1;
        this.leaderboard.forEach((player) => {
            buffer.writeUInt8(player.rank, offset);           // rank (1 byte)
            buffer.writeUInt8(player.pupitreId, offset + 1);  // pupitreId (1 byte)
            buffer.writeUInt32LE(player.score, offset + 2);   // score (4 bytes)
            buffer.writeUInt16LE(player.combo, offset + 6);   // combo (2 bytes)
            buffer.writeUInt8(player.accuracy, offset + 8);   // accuracy (1 byte)
            offset += 9;
        });
        
        // Envoyer via PureData (qui broadcast à tous les pupitres)
        this.pureDataProxy.broadcastBinaryToClients(buffer);
        
        console.log(`📊 Leaderboard broadcast: ${this.leaderboard.length} joueurs (${bufferSize} bytes)`);
    }
    
    /**
     * Démarrer le broadcast périodique du leaderboard
     */
    startLeaderboardBroadcast() {
        if (this.leaderboardTimer) {
            clearInterval(this.leaderboardTimer);
        }
        
        this.leaderboardTimer = setInterval(() => {
            this.broadcastLeaderboard();
        }, this.broadcastInterval);
        
        console.log('📊 Leaderboard broadcast démarré (toutes les', this.broadcastInterval, 'ms)');
    }
    
    /**
     * Arrêter le broadcast du leaderboard
     */
    stopLeaderboardBroadcast() {
        if (this.leaderboardTimer) {
            clearInterval(this.leaderboardTimer);
            this.leaderboardTimer = null;
        }
    }
    
    /**
     * Mettre en pause (JSON)
     */
    pauseGame(paused = true) {
        const message = {
            type: 'GAME_PAUSE',
            paused: paused
        };
        
        this.pureDataProxy.sendCommand(message);
        console.log(paused ? '⏸ Jeu en pause' : '▶ Jeu repris');
        
        return { success: true };
    }
    
    /**
     * Annuler la partie (JSON)
     */
    abortGame(reason = 'Aborted by server') {
        const message = {
            type: 'GAME_ABORT',
            reason: reason
        };
        
        this.pureDataProxy.sendCommand(message);
        this.endGame();
        
        console.log('🛑 Partie annulée:', reason);
        return { success: true, reason: reason };
    }
    
    /**
     * Terminer la partie
     */
    endGame() {
        this.stopLeaderboardBroadcast();
        
        // Broadcast leaderboard final
        this.broadcastLeaderboard();
        
        this.gameActive = false;
        
        console.log('🏁 Partie terminée');
        console.log('📊 Classement final:');
        this.leaderboard.forEach((player, index) => {
            console.log(`   ${index + 1}. P${player.pupitreId}: ${player.score}pts (combo ${player.combo}, acc ${player.accuracy}%)`);
        });
        
        return {
            success: true,
            leaderboard: this.leaderboard,
            duration: Date.now() - this.gameStartTime
        };
    }
    
    /**
     * Obtenir l'état du jeu
     */
    getGameState() {
        return {
            active: this.gameActive,
            mode: this.gameMode,
            difficulty: this.gameDifficulty,
            midiFile: this.currentMidiFile,
            startTime: this.gameStartTime,
            playerCount: this.playerScores.size,
            leaderboard: this.leaderboard,
            players: Array.from(this.playerScores.values())
        };
    }
    
    /**
     * Traiter un message binaire de jeu
     */
    handleBinaryGameMessage(buffer) {
        if (buffer.length === 0) return;
        
        const messageType = buffer.readUInt8(0);
        
        switch (messageType) {
            case 0x10: // GAME_NOTE_HIT
                this.handleNoteHit(buffer);
                break;
                
            case 0x11: // GAME_SCORE_UPDATE
                this.handleScoreUpdate(buffer);
                break;
                
            default:
                // Pas un message binaire de jeu, ignorer
                break;
        }
    }
    
    /**
     * Traiter un message JSON de jeu
     */
    handleJsonGameMessage(message) {
        if (!message || !message.type) return;
        
        switch (message.type) {
            case 'GAME_END':
                this.handleGameEnd(message);
                break;
                
            default:
                // Message JSON non géré par GameEngine
                break;
        }
    }
}

module.exports = GameEngine;

