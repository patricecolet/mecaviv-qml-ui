# Test du Mode Jeu - Format Binaire

## 📦 Format Binaire pour les Notes MIDI

### **Structure (3 bytes)**

```
[0x03, note, velocity]
```

**Détails :**
- **0x03** = Type NOTE_ON (1 byte)
- **note** = Note MIDI 0-127 (1 byte)
- **velocity** = Vélocité 0-127 (1 byte)

### **Exemples**

#### Note Do (60) avec vélocité 100:
```
[0x03, 60, 100]
```

#### Note La (69) avec vélocité 100:
```
[0x03, 69, 100]
```

#### Note Sol (67) avec vélocité 80:
```
[0x03, 67, 80]
```

## 🎮 Test avec Node.js

### **Script de test**

```bash
cd /Users/patricecolet/repo/mecaviv-qml-ui/SirenePupitre
node test-game-notes.js
```

### **Ce que fait le script**

- Se connecte à SirenePupitre (port 10002)
- Envoie 8 notes (gamme Do majeur)
- Une note toutes les 500ms
- Format binaire optimisé (8 bytes par note)

### **Notes de la gamme Do majeur**

```
Index 0 → 60 (Do)
Index 1 → 62 (Ré)
Index 2 → 64 (Mi)
Index 3 → 65 (Fa)
Index 4 → 67 (Sol)
Index 5 → 69 (La)
Index 6 → 71 (Si)
Index 7 → 72 (Do aigu)
```

## 📊 Comparaison Performance

### **JSON (ancien format)**
```
{"midiNote":69.5,"velocity":100,"controllers":{...}}
```
**Taille : ~50 bytes**

### **Binaire (nouveau format)**
```
[0x03, 69, 100]
```
**Taille : 3 bytes**

**Gain : 94% de réduction** 🚀

## 🎯 Étapes de Test

1. **Lance SirenePupitre**
2. **Active le mode jeu** (bouton en haut à droite)
3. **Lance le script de test** :
   ```bash
   node test-game-notes.js
   ```
4. **Observe** : Les cubes devraient apparaître et descendre !

## 🐛 Debug

### **Console SirenePupitre**

Tu devrais voir :
```
🎮 Mode jeu: ACTIVÉ
🎵 Note MIDI binaire: 60 vel: 100 ts: 0
🎵 GameMode - Événement MIDI reçu: {"midiNote":60,"velocity":100,"timestamp":0}
🎮 GameMode - Nombre d'événements MIDI: 1
🎵 Note MIDI binaire: 62 vel: 100 ts: 0
🎮 GameMode - Nombre d'événements MIDI: 2
...
```

### **Si tu ne vois rien**

1. Vérifie que le mode jeu est activé
2. Vérifie la connexion WebSocket (port 10002)
3. Vérifie le format binaire (3 bytes exactement)
4. Vérifie que le premier byte est 0x03

## 📝 Prochaines Étapes

- [ ] Ajouter le timestamp réel (millisecondes depuis le début)
- [ ] Envoyer plusieurs notes en rafale
- [ ] Tester avec des notes fractionnelles (69.5, etc.)
- [ ] Optimiser le débit (plus de notes/seconde)
