# Implementation Status

Mise à jour après les gates exécutés sur cette machine Linux le 25 septembre 2026.

| Gate | État | Note |
|---|---|---|
| G00 Repository | DONE | Structure, logo, icônes, inventaire 24 postes et règles Cursor vérifiés |
| G01 Mock Linux | DONE | `bun test` : 19 tests. 3 salles, 24 postes, états online/offline/locked/controlled/error, actions simulées |
| G02 UI production | DONE | Vue salle et vue Tous, sélection, miniatures simulées, confirmations reboot/extinction, journal d'audit. Logo dans l'interface et favicon |
| G03 Backend Tauri | DONE | Détection Veyon, TCP 11100 avec délai, vue/contrôle via `remoteaccess`, hôtes limités au parc. `cargo test` : 7 tests |
| G04 WebAPI proxy | DONE | Client Rust vers `127.0.0.1:11080` uniquement : AuthKeys, cache, réauthentification, framebuffer JPEG, ScreenLock, TextMessage, OpenWebsite, Reboot, PowerDown. La clé n'est pas dans le frontend |
| G05 Clients 24 PC | DONE | Scripts client corrigés (`$host` réservé retiré), `/S /NoMaster /ApplyConfig`, clé publique seule, pare-feu 11100, WebAPI désactivé. Validation sur de vrais PC : BLOCKED |
| G06 Formateur | DONE | Installation complète, conservation de la paire existante, export public seulement, WebAPI local, pare-feu 11080 bloqué en entrée, répertoire 24 machines. Validation Windows : BLOCKED |
| G07 Packaging Windows | DONE | NSIS, éditeur BIMLéman, icône, CI Windows + CI Linux. L'artefact `.exe` n'est pas produit sur cette machine : BLOCKED jusqu'au runner Windows |
| G08 Sécurité | DONE | Scan automatisé : pas de clé privée dans le frontend ni d'export `teacher/private`. Audit sans miniature ni consigne. Permissions par salle testées |
| G09 Recette physique | BLOCKED | Nécessite le poste formateur Windows et les 24 PC Veyon. Script prêt : `deploy/common/Test-Pilot.ps1`. Voir `docs/RECETTE-FINALE.md` |

## Vérifié ici

- `bun test`
- `bun run typecheck`
- `bun run build`
- `cargo test` dans `apps/desktop/src-tauri` (inclut la compilation)

## Bloqué, et pourquoi

- Installateur NSIS `.exe` : Tauri doit le produire sur Windows. Le workflow `.github/workflows/windows-release.yml` le fera sur un tag `v*` ou via `workflow_dispatch`.
- Voir, Aider, Figer, message, URL, redémarrage et extinction réels : ils appellent Veyon. Aucun `veyon-wcli.exe` ni PC élève n'est disponible ici.
- Pare-feu, import de clé et test TCP 11100 : PowerShell validé statiquement, pas exécuté sur Windows.
