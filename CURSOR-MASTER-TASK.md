# CURSOR MASTER TASK — Exécution autonome

Tu es l'agent principal de **BIMLéman View Room**. Tu dois prendre ce repository et l'amener jusqu'à un état production sans redemander au propriétaire les choix déjà tranchés.

## Objectif concret

Créer une application Windows installable sur le PC du formateur qui affiche les 3 salles et leurs 24 PC, permet de visualiser les postes, d'ouvrir la prise de contrôle Veyon, puis d'exécuter les fonctions pédagogiques autorisées : verrouillage, déverrouillage, message, ouverture d'URL, redémarrage et extinction.

## Stratégie

### G00 — Repository
- vérifier structure, scripts, assets et licences ;
- corriger tout chemin cassé ;
- créer `IMPLEMENTATION_STATUS.md` si absent.

### G01 — Mock Linux
- faire fonctionner `bun install`, `bun test`, `bun run dev` ;
- afficher exactement 24 machines en 3 salles ;
- toutes les actions doivent fonctionner en simulation ;
- les états offline/locked/controlled doivent être visibles.

### G02 — UI production
- utiliser le logo fourni ;
- identité visuelle propre, moderne, orientée centre de formation/BIM ;
- page salle, vue Tous, état réseau, sélection multiple ;
- confirmations fortes pour reboot/shutdown.

### G03 — Backend Tauri
- aucun secret dans le frontend ;
- toutes les opérations Veyon passent par des commandes Rust ;
- détection de `veyon-wcli.exe` ;
- contrôle et vue via `remoteaccess control/view` ;
- timeouts et erreurs propres.

### G04 — Veyon WebAPI proxy
- implémenter un proxy LOCAL sur le poste formateur, pas un WebAPI exposé sur les 24 clients ;
- authentification AuthKeys avec clé privée chargée côté backend uniquement ;
- cache de connexion par machine ;
- framebuffer JPEG redimensionné pour miniatures ;
- features ScreenLock, TextMessage, OpenWebsite, Reboot et PowerDown ;
- réauthentification automatique si connexion expirée ;
- ne jamais logger la clé privée.

Référence d'API : `/api/v1/authentication/<HOST>`, `Connection-Uid`, `/api/v1/framebuffer`, `/api/v1/feature/<UUID>`.

### G05 — Déploiement 24 clients
- fiabiliser les scripts PowerShell ;
- vérifier installation silencieuse `/S /NoMaster /ApplyConfig=<ABSOLUTE_PATH>` ;
- importer seulement `teacher/public` ;
- test TCP 11100 ;
- rapport CSV global 24/24.

### G06 — Poste formateur
- script d'installation Veyon complet ;
- génération de la paire teacher si absente ;
- export de la clé publique ;
- aucune régénération destructrice si une clé existe déjà ;
- création des 3 emplacements et 24 machines ;
- sauvegarde de la configuration.

### G07 — Packaging Windows
- Tauri NSIS ;
- icône BIMLéman View Room fournie dans `src-tauri/icons` ;
- raccourci application ;
- nom éditeur et identifiant cohérents ;
- GitHub Actions Windows ;
- artefact `.exe` téléchargeable.

### G08 — Sécurité
- audit secrets ;
- permissions par salle ;
- aucune fonction cachée de surveillance ;
- audit events sans contenu d'écran ;
- aucune exposition Internet des PC élèves ;
- WebAPI bind localhost uniquement ou filtré strictement.

### G09 — Recette
- écrire `docs/RECETTE-FINALE.md` avec cases PASS/FAIL/PENDING-HARDWARE ;
- tests 1 PC, 8 PC puis 24 PC ;
- ne jamais inventer un PASS matériel.

## Travail autonome

Quand un choix de code non métier est nécessaire, choisis la solution maintenable et documente-la. Ne demande pas à l'utilisateur de choisir une bibliothèque, une structure de fichier ou un nom interne.

Si une opération exige les vrais PC Windows, termine tout ce qui peut l'être localement et marque précisément le seul test physique restant.
