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
    signal filesLoaded(var files)
    signal fileSelected(string filePath)
    signal loadError(string errorMessage)
    
    // Détecter l'URL API selon l'environnement
    function getApiUrl() {
        // Détection automatique : localhost = dev, sinon = prod
        var currentUrl = Qt.application.arguments.length > 0 ? 
                         Qt.application.arguments[0] : ""
        
        // En WebAssembly, utiliser window.location depuis le contexte global
        // Fallback intelligent : si on tourne sur localhost, c'est du dev
        // Sinon, c'est la prod (Raspberry Pi sur réseau local)
        
        // Pour dev : http://localhost:8001
        // Pour prod : utiliser l'URL courante (ex: http://192.168.1.100:8001)
        return "http://localhost:8001"  // Le serveur tourne toujours localement
    }
    
    // Charger la liste des catégories et fichiers depuis l'API REST
    function loadMidiFiles() {
        loading = true
        error = ""
        
        var apiUrl = getApiUrl()
        
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        processFiles(response)
                        filesLoaded(files)
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
        
        var url = apiUrl + "/api/midi/files"
        // Loading MIDI files
        xhr.open("GET", url)
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
        
        // Fichiers MIDI traités
    }
    
    // Demander le chargement des fichiers (alias pour loadMidiFiles)
    function requestFiles() {
        loadMidiFiles()
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
    
    // Charger un fichier MIDI (envoie via HTTP POST au proxy)
    function loadMidiFile(filePath) {
        selectedFile = filePath
        fileSelected(filePath)
        
        // Commande à envoyer à PureData
        var command = {
            "type": "MIDI_FILE_LOAD",
            "path": filePath
        }
        
        // Envoyer via HTTP POST au proxy server.js
        var apiUrl = getApiUrl()
        var xhr = new XMLHttpRequest()
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    // MIDI file load requested
                } else {
                    error = "Erreur envoi commande: HTTP " + xhr.status
                    loadError(error)
                }
            }
        }
        
        xhr.open("POST", apiUrl + "/api/puredata/command")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(command))
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

