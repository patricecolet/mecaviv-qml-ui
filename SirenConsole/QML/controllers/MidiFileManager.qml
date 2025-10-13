import QtQuick 2.15

QtObject {
    id: root
    
    // Propriétés
    property var categories: []
    property var files: []
    property string selectedCategory: ""
    property string selectedFile: ""
    property bool loading: false
    property string error: ""
    
    // Référence au WebSocketManager (sera injecté)
    property var websocketManager: null
    
    // Signals
    signal filesLoaded()
    signal fileSelected(string filePath)
    signal loadError(string errorMessage)
    
    // Charger la liste des catégories et fichiers depuis l'API REST
    function loadMidiFiles() {
        loading = true
        error = ""
        
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        processFiles(response)
                        filesLoaded()
                    } catch (e) {
                        error = "Erreur de parsing: " + e.message
                        loadError(error)
                    }
                } else {
                    error = "Erreur HTTP: " + xhr.status
                    loadError(error)
                }
            }
        }
        
        xhr.open("GET", "http://localhost:3000/api/midi/files")
        xhr.send()
    }
    
    // Traiter les fichiers reçus et créer les catégories
    function processFiles(response) {
        var categoriesMap = {}
        var allFiles = []
        
        for (var i = 0; i < response.files.length; i++) {
            var file = response.files[i]
            allFiles.push(file)
            
            // Grouper par catégorie
            if (!categoriesMap[file.category]) {
                categoriesMap[file.category] = {
                    name: file.category,
                    displayName: getCategoryDisplayName(file.category),
                    count: 0,
                    files: []
                }
            }
            categoriesMap[file.category].count++
            categoriesMap[file.category].files.push(file)
        }
        
        // Convertir en array
        var cats = []
        for (var cat in categoriesMap) {
            cats.push(categoriesMap[cat])
        }
        
        // Trier par nom
        cats.sort(function(a, b) {
            return a.displayName.localeCompare(b.displayName)
        })
        
        categories = cats
        files = allFiles
    }
    
    // Obtenir le nom d'affichage d'une catégorie
    function getCategoryDisplayName(category) {
        switch(category) {
            case "louette": return "🎵 Louette"
            case "patwave": return "🌊 Patwave"
            case "covers": return "🎸 Covers"
            default: return "📁 " + category
        }
    }
    
    // Charger un fichier MIDI (envoie message WebSocket à PureData)
    function loadMidiFile(filePath) {
        if (!websocketManager) {
            error = "WebSocket non connecté"
            loadError(error)
            return
        }
        
        selectedFile = filePath
        fileSelected(filePath)
        
        // Envoi du message WebSocket MIDI_FILE_LOAD
        var message = {
            "type": "MIDI_FILE_LOAD",
            "path": filePath
        }
        
        websocketManager.sendMessage(JSON.stringify(message))
        console.log("MIDI file load requested:", filePath)
    }
    
    // Obtenir les fichiers d'une catégorie
    function getFilesForCategory(categoryName) {
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].name === categoryName) {
                return categories[i].files
            }
        }
        return []
    }
    
    // Formater le nom de fichier pour affichage
    function formatFileName(fileName) {
        // Retirer l'extension .midi/.mid
        var name = fileName.replace(/\.(midi|mid)$/i, "")
        // Retirer le chemin
        var parts = name.split("/")
        return parts[parts.length - 1]
    }
}

