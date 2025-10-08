import QtQuick

QtObject {
    id: root
    
    property var logger  // Ajouter la propriété logger
    
    signal batchReady(string batchType, var data)
    
    // Routes enregistrées
    property var routes: ({})
    property var batchBuffer: ({})
    
    // Aplatir les messages JSON en chemins
    function flatten(obj, prefix = "") {
        let results = [];
        
        for (let key in obj) {
            if (!obj.hasOwnProperty(key)) continue;
            
            let path = prefix ? prefix + "." + key : key;
            let value = obj[key];
            
            if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
                // Objet : récursif
                results = results.concat(flatten(value, path));
            } else if (Array.isArray(value)) {
                // Tableau : traiter chaque élément avec leur structure complète
                results.push({ path: path, value: value });
            } else {
                // Valeur simple
                results.push({ path: path, value: value });
            }
        }
        
        return results;
    }
    
    // Dispatcher avec batching pour les messages initiaux
    function dispatchWithBatching(flatMessages) {
        // Remplacer le console.log par un logger
        if (root.logger) {
            root.logger.debug("PARSER", "Dispatch avec batching de", flatMessages.length, "messages");
        }
        
        for (let msg of flatMessages) {
            if (msg.path === "voices" && Array.isArray(msg.value)) {
                root.batchReady("voices", msg.value);
            } else if (msg.path === "clock" && typeof msg.value === 'object') {
                root.batchReady("clock", msg.value);
            }
        }
    }
    
    // Dispatcher normal (pour les updates)
    function dispatchMessages(flatMessages) {
        if (logger) logger.debug("PARSER", "🚨 PARSER dispatch normal de", flatMessages.length, "messages");
        for (let msg of flatMessages) {
            if (logger) logger.debug("PARSER", "🚨 Path:", msg.path, "Value:", msg.value);
            messageRouter.routePathMessage(msg.path, msg.value);
        }
        if (logger) logger.debug("PARSER", "🚨 Émission batch clock");
    }
    
    // Les autres fonctions restent pour compatibilité future
    function registerRoute(pattern, handler) {
        routes[pattern] = handler;
    }
    
    function createRouteGroup(basePattern, handlers) {
        for (let key in handlers) {
            registerRoute(basePattern + "." + key, handlers[key]);
        }
    }
}
