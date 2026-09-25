# START HERE

## 1. Ce que tu développes sous Linux

Toute l'interface, le domaine, les états de salle, les actions et les tests sont développés avec 24 PC simulés. Aucune dépendance Veyon n'est nécessaire sur Linux pour travailler.

## 2. Ce qui est installé à l'école

### 24 PC élèves
`deploy/client/Install-Client.ps1` installe Veyon sans Master, applique la configuration et importe uniquement la clé publique.

### PC formateur
`deploy/teacher/Install-Teacher.ps1` installe Veyon complet et crée/conserve la paire de clés teacher. L'application Windows BIMLéman View Room est ensuite installée avec le `.exe` NSIS produit par la CI.

## 3. Pourquoi Veyon

Veyon fournit déjà le service distant, la visualisation/prise de contrôle, le verrouillage, messages, ouverture de sites et actions d'alimentation. BIMLéman View Room est la couche produit et sécurité.

## 4. Déploiement en gates

Ne jamais déployer directement 24 postes non testés :
- Gate pilote : FORMATEUR + SALLE-A-PC01 ;
- Gate salle : 8/8 Salle A ;
- Gate parc : 24/24.

## 5. Ce que Cursor doit faire

Ouvrir la racine du dossier dans Cursor puis demander simplement :

> Lis AGENTS.md et CURSOR-MASTER-TASK.md, reprends le projet au premier gate incomplet et continue jusqu'au maximum testable sur cette machine.

Aucun nouveau cahier des charges n'est nécessaire.
