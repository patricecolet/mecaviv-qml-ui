// WebSocket Helper - Utilise l'API JavaScript native WebSocket
// Compatible avec Qt WebAssembly

.pragma library

var socket = null;
var callbacks = {
    onOpen: null,
    onClose: null,
    onMessage: null,
    onError: null
};

function connect(url, onOpenCb, onCloseCb, onMessageCb, onErrorCb) {
    console.log("🔌 [WebSocketHelper] Connexion à:", url);
    
    callbacks.onOpen = onOpenCb;
    callbacks.onClose = onCloseCb;
    callbacks.onMessage = onMessageCb;
    callbacks.onError = onErrorCb;
    
    try {
        socket = new WebSocket(url);
        
        socket.onopen = function() {
            console.log("✅ [WebSocketHelper] Connecté:", url);
            if (callbacks.onOpen) callbacks.onOpen();
        };
        
        socket.onclose = function(event) {
            console.log("❌ [WebSocketHelper] Déconnecté:", event.code, event.reason);
            if (callbacks.onClose) callbacks.onClose();
        };
        
        socket.onmessage = function(event) {
            console.log("📥 [WebSocketHelper] Message reçu:", event.data.substring(0, 100));
            if (callbacks.onMessage) callbacks.onMessage(event.data);
        };
        
        socket.onerror = function(error) {
            console.error("❌ [WebSocketHelper] Erreur:", error);
            if (callbacks.onError) callbacks.onError(error.toString());
        };
        
        return true;
    } catch (e) {
        console.error("❌ [WebSocketHelper] Exception:", e);
        if (callbacks.onError) callbacks.onError(e.toString());
        return false;
    }
}

function send(message) {
    if (socket && socket.readyState === WebSocket.OPEN) {
        console.log("📤 [WebSocketHelper] Envoi:", message.substring(0, 100));
        socket.send(message);
        return true;
    } else {
        console.error("❌ [WebSocketHelper] Socket non connecté, readyState:", socket ? socket.readyState : "null");
        return false;
    }
}

function close() {
    if (socket) {
        console.log("🔌 [WebSocketHelper] Fermeture");
        socket.close();
        socket = null;
    }
}

function isConnected() {
    return socket && socket.readyState === WebSocket.OPEN;
}

function getReadyState() {
    if (!socket) return -1;
    return socket.readyState;
}

