// WebSocket Helper - Utilise window.QmlWebSocket défini dans le HTML
// Compatible avec Qt WebAssembly

.pragma library

function connect(url, onOpenCb, onCloseCb, onMessageCb, onErrorCb) {
    // Connexion WebSocket
    
    try {
        // Utiliser window.QmlWebSocket défini dans appSirenConsole.html
        var success = QmlWebSocket.connect(url, onOpenCb, onCloseCb, onMessageCb, onErrorCb);
        return success;
    } catch (e) {
        // Exception WebSocket
        if (onErrorCb) onErrorCb(e.toString());
        return false;
    }
}

function send(message) {
    try {
        return QmlWebSocket.send(message);
    } catch (e) {
        console.error("❌ [WebSocketHelper] Erreur send:", e);
        return false;
    }
}

function close() {
    try {
        QmlWebSocket.close();
    } catch (e) {
        console.error("❌ [WebSocketHelper] Erreur close:", e);
    }
}

function isConnected() {
    try {
        return QmlWebSocket.isConnected();
    } catch (e) {
        return false;
    }
}
