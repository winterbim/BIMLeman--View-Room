# AGENTS.md — BIMLéman View Room

Ce fichier s'applique à tous les agents de code (Cursor, Codex, Claude Code, etc.).

## Mission

Livrer une application Windows de supervision pédagogique pour 24 PC / 3 salles en utilisant Veyon comme moteur distant.

## Décisions déjà prises — ne pas les redemander

- Nom produit : **BIMLéman View Room**.
- Développement principal : Linux + Cursor.
- Desktop : Tauri 2 + React + TypeScript.
- Gestion paquets : Bun.
- Production Windows : GitHub Actions Windows + installateur NSIS `.exe`.
- Parc : 24 postes Windows, 3 salles, 8 postes/salle.
- Poste élève : Veyon Service + config + clé publique uniquement.
- Poste formateur : Veyon complet + application + clé privée.
- Linux doit fonctionner en MockAdapter sans Veyon.
- Windows doit utiliser VeyonAdapter.
- Les écrans ne doivent pas être envoyés vers un cloud public.
- Pas de stockage permanent des captures par défaut.

## Méthode agent

1. Lire tout le contexte avant de modifier.
2. Faire un état des lieux et écrire/mettre à jour `IMPLEMENTATION_STATUS.md`.
3. Travailler gate par gate sans demander confirmation pour les décisions déjà documentées.
4. Exécuter les tests après chaque tranche cohérente.
5. Ne jamais masquer un test rouge ou désactiver une protection pour passer un gate.
6. Si Windows est requis mais indisponible, produire le code testable + CI Windows et marquer uniquement le test matériel `PENDING-HARDWARE`.
7. Ne jamais committer de clé privée, mot de passe ou secret.

## Définition de terminé

Le produit n'est RELEASE READY que si :

- `bun test` passe ;
- `bun run build` passe ;
- `cargo check` passe dans `apps/desktop/src-tauri` ;
- la CI Windows génère un NSIS `.exe` ;
- le mode mock affiche 3 salles / 24 PC ;
- le test pilote Windows avec Veyon est documenté comme réussi ;
- les scripts client/formateur passent leur analyse PowerShell ;
- aucune clé privée n'existe dans git.
