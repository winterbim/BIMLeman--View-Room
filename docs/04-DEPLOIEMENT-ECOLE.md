# Déploiement école

## Étape 1 — Poste formateur

PowerShell administrateur :

```powershell
.\deploy\teacher\Install-Teacher.ps1 -VeyonInstaller "C:\Deploy\veyon-x.y.z-win64-setup.exe"
```

Le script crée la paire teacher seulement si elle n'existe pas et exporte la clé publique.

## Étape 2 — Pilote élève

```powershell
.\deploy\client\Install-Client.ps1 `
  -Room A -Seat 1 `
  -VeyonInstaller "C:\Deploy\veyon-x.y.z-win64-setup.exe" `
  -ConfigPath "C:\Deploy\veyon-config.json" `
  -PublicKeyPath "C:\Deploy\teacher-public.key"
```

Tester complètement le pilote avant la salle entière.

## Étape 3 — Répertoire Veyon

Sur le formateur :

```powershell
.\deploy\common\Create-NetworkObjects.ps1 -ClearExisting
```

## Étape 4 — Salle A

Déployer A01..A08 puis exécuter :

```powershell
.\deploy\common\Test-AllComputers.ps1
```

Le rapport global attend finalement 24/24 sur TCP 11100.

## Étape 4b — Pare-feu

Les scripts formateur et client appellent `deploy/common/Set-VeyonFirewall.ps1`.

- Clients : entrée TCP 11100 autorisée sur les profils Domaine et Privé.
- Tous les postes : entrée TCP 11080 bloquée. Le WebAPI du formateur reste utilisable en local.

## Étape 5 — Application

Installer le `.exe` BIMLéman View Room produit par GitHub Actions. Au premier lancement en production, l'application doit détecter Veyon et passer du mode mock au mode réel.
