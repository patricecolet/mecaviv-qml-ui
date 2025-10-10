# TODO - Roadmap Globale du Monorepo

Tâches et améliorations futures pour l'ensemble du système mecaviv-qml-ui.

## 🎯 Priorités Actuelles

### Phase 1 - Stabilisation et Tests ✅

- [x] Migration vers monorepo
- [x] Scripts de build centralisés
- [x] Documentation de base
- [ ] Tests d'intégration entre les 4 applications
- [ ] Documentation des cas d'usage (scénarios concert)
- [ ] Validation du système complet en production

### Phase 2 - Optimisations et Performances 🚀

#### SirenePupitre
- [ ] Optimisation des animations 3D (réduire la latence)
- [ ] Amélioration du rendu des caractères accentués dans LEDText3D
- [ ] Zoom dynamique sur ambitus selon levier de vitesse
- [ ] Cache des clefs 3D pour performance
- [ ] Mode plein écran optimisé pour Raspberry Pi

#### SirenConsole
- [ ] Implémentation des connexions WebSocket réelles avec pupitres
- [ ] Messages MIDI binaires temps réel
- [ ] Synchronisation des données en temps réel
- [ ] Interface mobile responsive
- [ ] Sauvegarde cloud des configurations

#### pedalierSirenium
- [ ] Finaliser le mapping note→Y sur la portée (clef + ambitus)
- [ ] Appliquer la courbe de pitch bend (13 bits, centre 4096)
- [ ] Mode historique focus (clic sur portée → affichage étendu)
- [ ] Quantification rythmique et rendu partition (24 ppq)
- [ ] Figures musicales complètes (ronde, blanche, noire, croche, double)
- [ ] Groupes de croches (beams) et triolets
- [ ] Optimisation latence hot-path binaire MIDI

#### sirenRouter
- [ ] Implémentation complète du service de monitoring
- [ ] Dashboard web interactif
- [ ] Système d'authentification optionnel
- [ ] Logs rotatifs et métriques de performance
- [ ] Client PureData pour communication avec Router

## 🔗 Intégrations

### Communication Inter-Applications
- [ ] Protocole de communication unifié et documenté
- [ ] Messages WebSocket standardisés entre toutes les apps
- [ ] Gestion des erreurs et reconnexions automatiques
- [ ] Heartbeat et détection de déconnexion
- [ ] Buffer de messages pour gestion de la latence

### PureData
- [ ] Patch PureData centralisé pour router-client
- [ ] Communication bidirectionnelle complète avec sirenRouter
- [ ] Gestion des autorisations de contrôle (takeover)
- [ ] Support MIDI multi-sources (Reaper, Sirénium, Pupitres)
- [ ] Routage conditionnel selon priorité

### Monitoring Global
- [ ] Tableau de bord centralisé (dashboard unifié)
- [ ] Vue d'ensemble des 7 sirènes en temps réel
- [ ] Historique des événements et des changements
- [ ] Alertes en cas de problème (sirène déconnectée)
- [ ] Statistiques de performance (latence, CPU, mémoire)

## 🎨 Interface Utilisateur

### Thèmes et Personnalisation
- [ ] Système de thèmes pour toutes les applications
- [ ] Mode sombre/clair configurable
- [ ] Personnalisation des couleurs par utilisateur
- [ ] Sauvegarde des préférences UI
- [ ] Tailles de police ajustables (accessibilité)

### Accessibilité
- [ ] Support clavier complet (navigation sans souris)
- [ ] Raccourcis clavier configurables
- [ ] Mode haute visibilité
- [ ] Support lecteurs d'écran
- [ ] Documentation vidéo des interfaces

## 📱 Déploiement

### Multi-Plateforme
- [ ] Version desktop native (Linux/macOS/Windows)
- [ ] Optimisation pour Raspberry Pi 4/5
- [ ] Application mobile (Android/iOS) pour monitoring
- [ ] PWA (Progressive Web App) pour accès hors-ligne
- [ ] Docker containers pour déploiement simplifié

### Scripts de Déploiement
- [ ] Script d'installation automatisée
- [ ] Déploiement sur Raspberry Pi (image préconfigurée)
- [ ] Service systemd pour auto-démarrage
- [ ] Mise à jour OTA (Over-The-Air)
- [ ] Backup et restauration automatique

## 🧪 Tests et Qualité

### Tests Automatisés
- [ ] Tests unitaires pour chaque composant QML
- [ ] Tests d'intégration WebSocket
- [ ] Tests de charge (7 pupitres simultanés)
- [ ] Tests de latence MIDI
- [ ] Tests de reconnexion réseau

### Monitoring et Debug
- [ ] Logs centralisés pour toutes les applications
- [ ] Système de télémétrie (métriques temps réel)
- [ ] Profiling des performances 3D
- [ ] Détection automatique des problèmes
- [ ] Outil de replay des sessions (debug post-mortem)

## 📚 Documentation

### Documentation Utilisateur
- [ ] Guide de démarrage rapide (Quick Start)
- [ ] Tutoriels vidéo pour chaque application
- [ ] Manuel utilisateur complet (PDF)
- [ ] FAQ et résolution de problèmes courants
- [ ] Exemples de configurations (presets commentés)

### Documentation Développeur
- [ ] Architecture détaillée avec diagrammes UML
- [ ] Guide de contribution au projet
- [ ] Standards de code et conventions
- [ ] Documentation API complète (REST + WebSocket)
- [ ] Exemples de code et snippets réutilisables

## 🔐 Sécurité

### Authentification et Autorisation
- [ ] Système d'authentification pour SirenConsole
- [ ] Gestion des rôles (admin, opérateur, viewer)
- [ ] Logs d'audit des actions (qui a fait quoi)
- [ ] Chiffrement des communications WebSocket (WSS)
- [ ] Protection contre les injections et XSS

### Isolation et Sandboxing
- [ ] Isolation des processus (chaque app dans son container)
- [ ] Limites de ressources (CPU, mémoire) par app
- [ ] Sandbox WebAssembly sécurisé
- [ ] Validation stricte des messages WebSocket

## 🎵 Fonctionnalités Musicales Avancées

### Visualisation
- [ ] Spectrogramme en temps réel
- [ ] Analyse harmonique (détection d'accords)
- [ ] Visualisation de la phase de rotation des sirènes
- [ ] Représentation 3D du champ sonore
- [ ] Enveloppes ADSR visualisées

### Contrôle Avancé
- [ ] Séquenceur intégré (patterns rythmiques)
- [ ] Modulation LFO configurable
- [ ] Mapping MIDI CC avancé (courbes personnalisées)
- [ ] Macro-contrôles (un contrôle → plusieurs paramètres)
- [ ] Morphing entre presets (transition douce)

### Enregistrement et Export
- [ ] Enregistrement des sessions (automation)
- [ ] Export MIDI des séquences
- [ ] Export audio (via PureData)
- [ ] Export des configurations en JSON
- [ ] Import de séquences depuis DAW

## 🌐 Réseau et Distribution

### Architecture Distribuée
- [ ] Support multi-machines (cluster de Raspberry Pi)
- [ ] Load balancing pour haute disponibilité
- [ ] Synchronisation horaire (NTP) pour latence minimale
- [ ] Découverte automatique des nœuds (mDNS/Bonjour)
- [ ] Failover automatique en cas de panne

### Streaming et Remote
- [ ] Streaming audio/vidéo des performances
- [ ] Contrôle à distance via Internet (tunnel sécurisé)
- [ ] Collaboration multi-utilisateurs
- [ ] Partage de presets en ligne (bibliothèque communautaire)

## 🔧 Infrastructure

### CI/CD
- [ ] Pipeline de build automatisé (GitHub Actions)
- [ ] Tests automatiques à chaque commit
- [ ] Déploiement automatique (staging/production)
- [ ] Releases versionnées avec changelog
- [ ] Artifacts de build stockés (binaries, WASM)

### Monitoring Production
- [ ] Uptime monitoring (disponibilité)
- [ ] Alertes en cas de problème
- [ ] Métriques de performance en production
- [ ] Logs centralisés (ELK stack ou équivalent)
- [ ] Dashboard de monitoring (Grafana)

## 📝 Roadmap par Version

### v1.1 - Stabilisation (Q2 2025)
- Tests d'intégration complets
- Documentation utilisateur
- Optimisations de performance
- Correction des bugs critiques

### v1.2 - Monitoring Avancé (Q3 2025)
- sirenRouter complet et fonctionnel
- Dashboard de monitoring unifié
- Logs centralisés
- Métriques en temps réel

### v2.0 - Fonctionnalités Avancées (Q4 2025)
- Séquenceur intégré
- Enregistrement et export
- Version mobile
- Architecture distribuée

### v3.0 - Écosystème Complet (2026)
- Bibliothèque de presets communautaire
- Streaming et collaboration
- IA pour génération de patterns
- Support de nouveaux types de sirènes

## 🎯 Objectifs à Long Terme

1. **Système Robuste et Fiable** : Zéro downtime en concert
2. **Interface Intuitive** : Utilisable par des non-techniciens
3. **Performance Optimale** : Latence < 10ms pour contrôles critiques
4. **Extensible** : Architecture modulaire pour ajout facile de fonctionnalités
5. **Open Source** : Communauté de contributeurs actifs

---

**Note** : Cette roadmap est évolutive. Les priorités peuvent changer selon les besoins des performances et les retours utilisateurs.


