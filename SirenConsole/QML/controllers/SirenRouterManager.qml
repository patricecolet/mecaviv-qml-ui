import QtQuick 2.15

// Stub pour sirenRouter (à implémenter Phase 4)
// Ce contrôleur gérera les conflits quand plusieurs sources veulent contrôler une sirène
QtObject {
    id: root
    
    // Propriétés
    property bool connected: false
    property string serverUrl: "http://localhost:8002"
    property var activeSirens: ({})
    
    // Signals
    signal conflictDetected(string sirenId, var sources)
    signal claimSuccess(string sirenId, string source)
    signal claimRejected(string sirenId, string reason)
    
    // Fonctions stub
    function claimSiren(sirenId, source, priority) {
        // SirenRouterManager.claimSiren
        // TODO: Implémenter POST /api/sirens/:id/claim
        return true
    }
    
    function releaseSiren(sirenId, source) {
        // SirenRouterManager.releaseSiren
        // TODO: Implémenter POST /api/sirens/:id/release
        return true
    }
    
    function getSirenStatus(sirenId) {
        // SirenRouterManager.getSirenStatus
        // TODO: Implémenter GET /api/sirens/:id
        return {
            id: sirenId,
            owner: null,
            priority: 0,
            available: true
        }
    }
    
    function getAllSirensStatus() {
        // SirenRouterManager.getAllSirensStatus
        // TODO: Implémenter GET /api/sirens/status
        return []
    }
    
    Component.onCompleted: {
        // SirenRouterManager initialized
    }
}
