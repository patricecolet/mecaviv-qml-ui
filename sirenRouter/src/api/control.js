/**
 * API de contrôle des sirènes - Gestion des takeovers
 */

const express = require('express');
const router = express.Router();

// État des connexions actives
const activeConnections = new Map(); // sireneId -> { sourceId, timestamp, metadata }

// Notifications WebSocket
let notifyConsoles = () => {};

function setNotifyFunction(notifyFn) {
    notifyConsoles = notifyFn;
}

/**
 * POST /api/control/request
 * Demande de contrôle d'une sirène - Système simple "dernier arrivé, premier servi"
 */
router.post('/request', async (req, res) => {
    try {
        const { sourceId, sireneId, metadata = {} } = req.body;
        
        if (!sourceId || !sireneId) {
            return res.status(400).json({
                error: 'sourceId et sireneId requis'
            });
        }
        
        console.log(`🎛️ Demande de contrôle: ${sourceId} → S${sireneId}`);
        
        const currentConnection = activeConnections.get(sireneId);
        const requestId = generateRequestId();
        
        // Si la sirène est libre
        if (!currentConnection) {
            // Accorder le contrôle immédiatement
            activeConnections.set(sireneId, {
                sourceId,
                timestamp: Date.now(),
                requestId,
                metadata
            });
            
            console.log(`✅ Contrôle accordé: ${sourceId} → S${sireneId}`);
            
            // Notifier les consoles
            notifyConsoles({
                type: 'control_granted',
                data: {
                    sireneId,
                    sourceId,
                    requestId,
                    timestamp: Date.now()
                }
            });
            
            return res.json({
                status: 'granted',
                requestId,
                sireneId,
                sourceId,
                grantedAt: new Date().toISOString()
            });
        }
        
        // Si la sirène est occupée - takeover avec timeout
        const currentSource = currentConnection.sourceId;
        const { force = false, timeout = 5000 } = req.body;
        
        console.log(`🔄 Demande de takeover: ${currentSource} → ${sourceId} (S${sireneId}) [force: ${force}, timeout: ${timeout}ms]`);
        
        if (force) {
            // Mode forçage - pas d'attente
            console.log(`🔨 Forçage du takeover: ${currentSource} → ${sourceId} (S${sireneId})`);
            
            // Notifier la source actuelle qu'elle est déconnectée de force
            notifyConsoles({
                type: 'control_force_revoked',
                data: {
                    sireneId,
                    sourceId: currentSource,
                    reason: 'force_takeover',
                    newController: sourceId,
                    requestId: currentConnection.requestId,
                    timestamp: Date.now()
                }
            });
            
            // Accorder immédiatement le contrôle à la nouvelle source
            activeConnections.set(sireneId, {
                sourceId,
                timestamp: Date.now(),
                requestId,
                metadata
            });
            
            console.log(`✅ Contrôle forcé: ${currentSource} → ${sourceId} (S${sireneId})`);
            
            // Notifier les consoles
            notifyConsoles({
                type: 'control_granted',
                data: {
                    sireneId,
                    sourceId,
                    requestId,
                    timestamp: Date.now(),
                    previousController: currentSource,
                    forced: true
                }
            });
            
            return res.json({
                status: 'granted',
                requestId,
                sireneId,
                sourceId,
                grantedAt: new Date().toISOString(),
                takeover: true,
                forced: true,
                previousController: currentSource
            });
        } else {
            // Mode normal - attendre confirmation avec timeout
            console.log(`⏱️ Takeover normal avec timeout de ${timeout}ms`);
            
            // Notifier la source actuelle qu'elle doit se déconnecter
            notifyConsoles({
                type: 'control_revoked',
                data: {
                    sireneId,
                    sourceId: currentSource,
                    reason: 'new_source_request',
                    newController: sourceId,
                    requestId: currentConnection.requestId,
                    timestamp: Date.now()
                }
            });
            
            // Attendre la confirmation avec timeout
            const confirmationReceived = await waitForConfirmation(currentSource, sireneId, timeout);
            
            if (confirmationReceived) {
                // Confirmation reçue - accorder le contrôle
                activeConnections.set(sireneId, {
                    sourceId,
                    timestamp: Date.now(),
                    requestId,
                    metadata
                });
                
                console.log(`✅ Contrôle transféré (confirmé): ${currentSource} → ${sourceId} (S${sireneId})`);
                
                // Notifier les consoles
                notifyConsoles({
                    type: 'control_granted',
                    data: {
                        sireneId,
                        sourceId,
                        requestId,
                        timestamp: Date.now(),
                        previousController: currentSource
                    }
                });
                
                return res.json({
                    status: 'granted',
                    requestId,
                    sireneId,
                    sourceId,
                    grantedAt: new Date().toISOString(),
                    takeover: true,
                    previousController: currentSource
                });
            } else {
                // Timeout - forcer la libération
                console.log(`⏰ Timeout - forçage du takeover: ${currentSource} → ${sourceId} (S${sireneId})`);
                
                // Notifier la source actuelle qu'elle est déconnectée de force
                notifyConsoles({
                    type: 'control_force_revoked',
                    data: {
                        sireneId,
                        sourceId: currentSource,
                        reason: 'timeout_force',
                        newController: sourceId,
                        requestId: currentConnection.requestId,
                        timestamp: Date.now()
                    }
                });
                
                // Accorder le contrôle après timeout
                activeConnections.set(sireneId, {
                    sourceId,
                    timestamp: Date.now(),
                    requestId,
                    metadata
                });
                
                console.log(`✅ Contrôle forcé (timeout): ${currentSource} → ${sourceId} (S${sireneId})`);
                
                // Notifier les consoles
                notifyConsoles({
                    type: 'control_granted',
                    data: {
                        sireneId,
                        sourceId,
                        requestId,
                        timestamp: Date.now(),
                        previousController: currentSource,
                        timeoutForced: true
                    }
                });
                
                return res.json({
                    status: 'granted',
                    requestId,
                    sireneId,
                    sourceId,
                    grantedAt: new Date().toISOString(),
                    takeover: true,
                    timeoutForced: true,
                    previousController: currentSource
                });
            }
        }
        
    } catch (error) {
        console.error('Erreur lors de la demande de contrôle:', error);
        res.status(500).json({
            error: 'Erreur interne du serveur'
        });
    }
});

/**
 * POST /api/control/release
 * Libération du contrôle d'une sirène
 */
router.post('/release', (req, res) => {
    try {
        const { sourceId, sireneId, requestId } = req.body;
        
        if (!sourceId || !sireneId) {
            return res.status(400).json({
                error: 'sourceId et sireneId requis'
            });
        }
        
        const currentConnection = activeConnections.get(sireneId);
        
        if (!currentConnection) {
            return res.json({
                status: 'already_free',
                sireneId
            });
        }
        
        if (currentConnection.sourceId !== sourceId) {
            return res.status(403).json({
                error: 'Source non autorisée à libérer cette sirène',
                currentController: currentConnection.sourceId
            });
        }
        
        // Libérer la sirène
        activeConnections.delete(sireneId);
        
        console.log(`🔓 Contrôle libéré: ${sourceId} → S${sireneId}`);
        
        // Notifier les consoles
        notifyConsoles({
            type: 'control_released',
            data: {
                sireneId,
                sourceId,
                requestId: currentConnection.requestId,
                timestamp: Date.now()
            }
        });
        
        res.json({
            status: 'released',
            sireneId,
            sourceId,
            releasedAt: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('Erreur lors de la libération:', error);
        res.status(500).json({
            error: 'Erreur interne du serveur'
        });
    }
});

/**
 * GET /api/control/status
 * État des connexions actives
 */
router.get('/status', (req, res) => {
    const connections = {};
    
    for (const [sireneId, connection] of activeConnections.entries()) {
        connections[sireneId] = {
            sourceId: connection.sourceId,
            timestamp: connection.timestamp,
            requestId: connection.requestId,
            priority: connection.priority,
            metadata: connection.metadata
        };
    }
    
    res.json({
        activeConnections: connections,
        totalConnections: activeConnections.size
    });
});

/**
 * POST /api/control/force-release
 * Force la libération d'une sirène (admin uniquement)
 */
router.post('/force-release', (req, res) => {
    try {
        const { sireneId, reason = 'admin_override' } = req.body;
        
        const currentConnection = activeConnections.get(sireneId);
        
        if (!currentConnection) {
            return res.json({
                status: 'already_free',
                sireneId
            });
        }
        
        const sourceId = currentConnection.sourceId;
        const requestId = currentConnection.requestId;
        
        // Force la libération
        activeConnections.delete(sireneId);
        
        console.log(`🔨 Libération forcée: ${sourceId} → S${sireneId} (${reason})`);
        
        // Notifier la source qu'elle a été déconnectée
        notifyConsoles({
            type: 'control_force_revoked',
            data: {
                sireneId,
                sourceId,
                reason,
                requestId,
                timestamp: Date.now()
            }
        });
        
        res.json({
            status: 'force_released',
            sireneId,
            previousController: sourceId,
            reason,
            releasedAt: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('Erreur lors de la libération forcée:', error);
        res.status(500).json({
            error: 'Erreur interne du serveur'
        });
    }
});

/**
 * Générer un ID de requête unique
 */
function generateRequestId() {
    return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Attendre la confirmation de libération avec timeout
 */
async function waitForConfirmation(sourceId, sireneId, timeout) {
    return new Promise((resolve) => {
        const timeoutId = setTimeout(() => {
            console.log(`⏰ Timeout de confirmation pour ${sourceId} → S${sireneId}`);
            resolve(false);
        }, timeout);
        
        // Écouter les libérations de cette source pour cette sirène
        const originalNotify = notifyConsoles;
        notifyConsoles = (notification) => {
            // Appeler la fonction originale
            originalNotify(notification);
            
            // Vérifier si c'est une libération de la source attendue
            if (notification.type === 'control_released' && 
                notification.data.sourceId === sourceId && 
                notification.data.sireneId === sireneId) {
                clearTimeout(timeoutId);
                console.log(`✅ Confirmation reçue de ${sourceId} pour S${sireneId}`);
                notifyConsoles = originalNotify; // Restaurer la fonction originale
                resolve(true);
            }
        };
    });
}

/**
 * Nettoyage périodique des connexions expirées
 */
setInterval(() => {
    const now = Date.now();
    const maxAge = 5 * 60 * 1000; // 5 minutes
    
    for (const [sireneId, connection] of activeConnections.entries()) {
        if (now - connection.timestamp > maxAge) {
            console.log(`🧹 Connexion expirée nettoyée: ${connection.sourceId} → S${sireneId}`);
            activeConnections.delete(sireneId);
            
            notifyConsoles({
                type: 'control_expired',
                data: {
                    sireneId,
                    sourceId: connection.sourceId,
                    requestId: connection.requestId,
                    timestamp: now
                }
            });
        }
    }
}, 60000); // Vérification toutes les minutes

module.exports = { router, setNotifyFunction };
