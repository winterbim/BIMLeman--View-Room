# Proof Ledger — architecture BIMLéman View Room

| ID | Level | Claim | Gate (what proves it) | Status | Evidence |
|----|-------|-------|------------------------|--------|----------|
| P1 | Micro | Un effet qui ne change pas l'état n'est pas un succès | `bun test` le 2026-09-25 | EVIDENCED | 2026-09-25 `bun test` exit 0 → 20 passed, 0 fail ; ligne `(pass) an effect that does not change state is not recorded as success` |
| P2 | Micro | Une salle ajoutée après création de session ne donne aucun droit | `bun test` le 2026-09-25 | EVIDENCED | 2026-09-25 `bun test` exit 0 → 20 passed, 0 fail ; ligne `(pass) restricted teacher actions are refused and audited` |
| P3 | Meso | L'interface compile avec domain, session et adaptateur séparés | `bun run typecheck` puis `bun run build` | EVIDENCED | 2026-09-25 `bun run typecheck` exit 0 ; `bun run build` exit 0 → vite `40 modules transformed` |
| P4 | Meso | Le figé distant Veyon est réellement actif sur un poste élève | `deploy/common/Test-Pilot.ps1 -Role Teacher` | BLOCKED | 2026-09-25 bloqué par l'absence de poste formateur Windows et de PC Veyon ; la preuve P1 ne couvre que l'état local de l'adaptateur |
