# Recette finale — BIMLéman View Room

Les cases PASS ci-dessous correspondent à des commandes exécutées sur la machine de développement Linux le 25 septembre 2026. Aucun PASS n'est inscrit pour un poste Windows ou un PC élève qui n'a pas été testé.

## Linux / CI

- [x] PASS — `bun test` (19 tests, 0 échec)
- [x] PASS — `bun run typecheck`
- [x] PASS — `bun run build`
- [x] PASS — `cargo test` dans `apps/desktop/src-tauri` (7 tests, 0 échec)
- [x] PASS — inventaire code : 3 salles / 24 PC, états hors ligne et erreur simulés
- [x] PASS — logo `apps/desktop/public/logo.png`, favicon, `src-tauri/icons/icon.ico`
- [ ] PENDING-HARDWARE — workflow GitHub Actions Windows et artefact NSIS `.exe`

## Pilote Windows

À lancer après installation : `deploy/common/Test-Pilot.ps1 -Role Teacher` puis `-Role Client` sur `SALLE-A-PC01`.

- [ ] PENDING-HARDWARE — Veyon détecté
- [ ] PENDING-HARDWARE — TCP 11100 SALLE-A-PC01
- [ ] PENDING-HARDWARE — Voir
- [ ] PENDING-HARDWARE — Aider / contrôle
- [ ] PENDING-HARDWARE — Figer / défiger
- [ ] PENDING-HARDWARE — Message
- [ ] PENDING-HARDWARE — Ouvrir URL
- [ ] PENDING-HARDWARE — Reboot
- [ ] PENDING-HARDWARE — Shutdown avec confirmation

## Salle A

- [ ] PENDING-HARDWARE — 8/8 visibles
- [ ] PENDING-HARDWARE — 8/8 joignables (`Test-AllComputers.ps1` doit finir par un échec tant que le parc n'est pas complet : code de sortie 2)
- [ ] PENDING-HARDWARE — action groupée verrouillage
- [ ] PENDING-HARDWARE — charge réseau acceptable

## Parc

- [ ] PENDING-HARDWARE — 24/24 inventoriés dans Veyon
- [ ] PENDING-HARDWARE — 24/24 TCP 11100
- [ ] PENDING-HARDWARE — salles séparées correctement
- [ ] PENDING-HARDWARE — aucune clé privée sur client (`Test-Pilot.ps1 -Role Client`)
- [ ] PENDING-HARDWARE — installateur Windows validé sur le poste formateur

## Ordre de validation matérielle

1. Poste formateur : `deploy/teacher/Install-Teacher.ps1`.
2. Pilote `SALLE-A-PC01` : `deploy/client/Install-Client.ps1`.
3. `deploy/common/Test-Pilot.ps1`.
4. Salle A complète, puis salles B et C.
5. `deploy/common/Test-AllComputers.ps1` jusqu'à 24/24.
6. Installer le `.exe` produit par la CI et passer l'application en mode réel.
