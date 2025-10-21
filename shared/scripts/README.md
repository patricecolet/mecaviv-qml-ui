# Scripts de conversion partagés

Scripts utilitaires pour convertir des modèles 3D au format Qt Quick 3D.

## 📁 Contenu

### `convert-mesh.sh`

Script générique de conversion `.obj` → `.mesh` pour Qt Quick 3D.

**Usage** :
```bash
./convert-mesh.sh <fichier.obj> <nom_final.mesh>
```

**Exemples** :
```bash
# Convertir un modèle Piano
./convert-mesh.sh Piano.obj Piano.mesh

# Convertir une clef de Sol
./convert-mesh.sh TrebleKey.obj TrebleKey.mesh
```

**Prérequis** :
- Qt 6.10+ avec Quick3D installé
- L'outil `balsam` (inclus avec Qt Quick 3D)

**Fonctionnalités** :
- Détection automatique de `balsam` dans les installations Qt
- Gestion des fichiers temporaires
- Nettoyage automatique après conversion
- Support multi-plateforme (macOS, Linux)

### `convert-clefs.sh`

Script spécialisé pour convertir les clefs musicales (Sol et Fa).

**Usage** :
```bash
./convert-clefs.sh
```

**Prérequis** :
- Fichiers sources `.obj` dans `SirenePupitre/QML/utils/meshes/` :
  - `TrebleKey.obj` (Clé de Sol)
  - `BassKey.obj` (Clé de Fa)

**Résultat** :
- Génère `TrebleKey.mesh` et `BassKey.mesh`
- Fichiers placés dans le même dossier que les sources

## 🔧 Installation de balsam

`balsam` est inclus avec Qt Quick 3D. Si vous avez installé Qt 6.10+ avec le module Quick3D, vous l'avez déjà.

**Chemins typiques** :
- macOS : `$HOME/Qt/6.10.0/macos/bin/balsam`
- Linux : `$HOME/Qt/6.10.0/gcc_64/bin/balsam`

## 📝 Notes

- Les fichiers `.mesh` sont binaires et optimisés pour Qt Quick 3D
- Les modèles 3D convertis restent locaux dans chaque projet (non partagés)
- Ces scripts sont réutilisables pour tout modèle 3D du projet

## 🎯 Usage dans QML

```qml
Model {
    source: "qrc:/QML/utils/meshes/TrebleKey.mesh"
    scale: Qt.vector3d(80, 80, 80)
    materials: PrincipledMaterial {
        baseColor: "#DADADA"
    }
}
```

