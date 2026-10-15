# Livraison pilote native — 15 octobre 2026

**BUILD, INSTALLATION PILOTE ET RETOUR ARRIÈRE WINDOWS : PASS. RECETTE SALLE : PENDING-HARDWARE.**

Le demandeur a confirmé Veyon **4.11.3** et un **usage strictement non commercial**.
Ces déclarations sont tracées dans [distribution-policy.json](../distribution-policy.json).
L'installateur contrôle encore la révision numérique réelle **4.11.3.0** avant tout changement.
Une concordance de version ne démontre pas le fonctionnement du réseau de la salle.

- [Run Windows réussi 38762378877](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38762378877).
- [Préversion GitHub et fichiers conservés](https://github.com/winterbim/BIMLeman--View-Room/releases/tag/native-v4.11.3-fe9f2d92-pilot).
- Commit compilé : `fe9f2d92e182d9d885f107834fe37f1863914b65`.
- [Candidat binaire et scripts](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38762378877/artifacts/11986234095),
  [sources correspondantes](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38762378877/artifacts/11986269047),
  [preuves originales](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38762378877/artifacts/11986508381).
- Installateur : `BIMLeman-4.11.3-fe9f2d92-setup.exe`, **33 001 999 octets**.
- SHA256 installateur : `c3a72b6d060dab2c616d5c1eae3e648f6a478463101cac43b21652b85840a7d5`.
- Master natif PE32+ x64, sous-système GUI ; SHA256 compilé et installé identique :
  `34a84722ea205d68373f6cf44214c12ecbfd3d422ffd18ca9af1e5ad01d01d51`.
- Qt exécuté : **6.11.2**, Veyon : **4.11.3** ; 365 fichiers installés, dont 82 DLL.
- Installateur et application **non signés Authenticode**.

## Contrôles réellement exécutés

| Contrôle | Preuve et résultat |
| --- | --- |
| Vraie compilation native | Master puis tous les composants/plugins compilés ; journaux complets dans Evidence. |
| Détection de version | L'EXE officiel réel affiche `FileVersion=4.11.3` mais ses champs PE numériques valent `4.11.3.0` ; [détection](windows-38762378877/official-detection.json) vérifiée sous Windows. |
| Démarrage sans outils | PATH limité à Windows et variables Qt retirées ; interface native démarrée normalement. |
| Branding | Titre réel `BIMLéman View Room`, icône PE comparée pixel à pixel, icône Qt et splash comparés aux SHA256 des ressources ; [diagnostic natif](windows-38762378877/native-smoke.json). |
| Fonctions chargées | 38 fonctions natives enregistrées, dont RemoteView, RemoteControl, ScreenLock et TextMessage ; aucune commande distante du réseau client testée ici. |
| Installation NSIS | Installation parallèle, refus de destination personnalisée et refus d'écrasement du candidat. |
| Commande pilote réelle | `Install-Safe.ps1 -Pilot` exécuté : sauvegarde complète, ACL privée contrôlée, Master sauvegardé identique, clés éphémères hors répertoires standard sauvegardées, tous les fichiers de sauvegarde vérifiés par SHA256. |
| Porte production | Appel sans `-Pilot` refusé avant installation, car `clientValidated=false`. |
| Retour arrière | Désinstallation répétée ; exécutable de désinstallation retiré après sa sortie, dossier candidat disparu, fichier témoin des données partagées conservé. |
| Veyon officiel | Tous les fichiers et l'état du service de référence conservés ; CLI et fenêtre Master officielles rouvertes après le premier retour arrière ; intégrité revérifiée après le second. |

Le [résultat de recette](windows-38762378877/windows-tests.json) conserve
`safePilotWrapper=PASS`, `windowsValidated=true` dans le manifeste et
`clientValidated=false`. Les tests ont employé un runner GitHub Windows 2022
jetable avec Veyon officiel 4.11.3.0 et une paire de clés créée uniquement pour
ce test ; aucune clé ni machine du client n'a été utilisée ou modifiée.

## Diffusion et limites

Interception prévoit la redistribution pour l'usage non commercial sous ses
[conditions publiées](https://github.com/oblitum/Interception#license).
La diffusion de ce candidat est limitée au cadre déclaré ; aucun droit commercial
n'est revendiqué. Veyon, ses attributions et son COPYING sont conservés.
Les textes Interception, LGPLv3 et GPLv3 sont installés avec les autres licences.
Les bibliothèques sont liées dynamiquement et leurs sources correspondantes sont
disponibles avec le candidat, sans restriction supplémentaire de modification.
Le [manifeste](windows-38762378877/manifest.json) référence les deux archives de
sources et leurs SHA256. Les artefacts Actions expirent après 90 jours ; conserver
binaires, sources et notices ensemble lors de toute redistribution. La préversion
GitHub conserve également les neuf fichiers de livraison : installateur, trois
scripts, manifeste, deux archives sources, archive de preuves et SHA256SUMS.
Les deux archives téléchargées ont été comparées au manifeste ; elles contiennent
les sources natives complètes et les **112** paquets sources de dépendances.
Les neuf empreintes GitHub (digest serveur) ont été revérifiées après l'envoi
complet de l'archive de dépendances de **1 020 539 099 octets** : elles
concordent toutes avec `SHA256SUMS.txt` et le manifeste local.

La recette réelle sur le PC formateur et un poste pilote autorisé reste obligatoire :
annuaire, miniatures, authentification, visualisation, contrôle clavier/souris,
message, verrouillage/déverrouillage, autres fonctions utilisées et retour au
Master officiel. Aucun succès sur ces postes n'est revendiqué. Ne pas définir
`clientValidated=true` sans compte rendu rattaché à ce commit et à ses empreintes.

Installation, sauvegarde et retour arrière : [procédure](../README.md#installation-et-retour-arrière).
Commande PowerShell unique : [installation pilote](INSTALL-PILOT.md).
Le téléchargement du script figé a été comparé à son SHA256 et sa syntaxe analysée.
Le script de récupération a été exécuté face au candidat publié sans `-Pilot` :
il refuse effectivement l'installation de production tant que la recette client manque.
Le [premier rapport](WINDOWS-REPORT.md) décrit le run antérieur, dont la diffusion
était encore bloquée avant les réponses du demandeur ; il reste conservé comme historique.
