# BIMLéman View Room natif

Cette livraison remplace uniquement la présentation du véritable Master C++/Qt.
`Program.cs`, `BIMLeman.nsi` et `branding-update.yml` sont historiques : le workflow
legacy n'est plus déclenché par les modifications natives.

## Résultat vérifié

La compilation native complète, le packaging NSIS, le script pilote avec sauvegarde
privée et le retour arrière sur Windows 2022 ont réussi dans le
[run 38762378877](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38762378877).
Le [rapport avec captures et limites](evidence/PILOT-DELIVERY.md) distingue cette
réussite technique de la recette client. Le demandeur a confirmé Veyon 4.11.3 et
un usage strictement non commercial. Le candidat et ses sources sont publiés
dans les artefacts de ce run ; la recette du réseau client reste à réaliser.
La [préversion GitHub](https://github.com/winterbim/BIMLeman--View-Room/releases/tag/native-v4.11.3-fe9f2d92-pilot)
conserve aussi les binaires, sources, preuves et empreintes.
La [commande PowerShell unique](evidence/INSTALL-PILOT.md) démarre l'installation
pilote avec les contrôles et la sauvegarde préalables.

## Sources et compilation

- Veyon v4.11.3 : `0c629d9931810a5974038fc1a207d52fbd0e65f6` et ses sous-modules.
- Interception : `39eecbbc46a52e0402f783b872ef62b0254a896a` (bibliothèque utilisateur).
- Windows 2022, MinGW64 ; Windows 10 1809 ou ultérieur pour le candidat ; versions et SHA256 complets dans `msys2-lock.json`.
- `build.sh` compile explicitement `veyon-master`, puis tous les autres composants
  et plugins natifs. `package_native.py` résout récursivement les imports DLL dans
  le seul préfixe verrouillé, inclut plateformes Qt, QCA/OpenSSL, traductions et licences.
- Les fichiers modifiés portent une notice datée ; la police DejaVu Sans est fournie avec sa licence.
- Aucune clé réelle, aucun identifiant du client dans les archives.
- Écran de démarrage : le splash natif existant `master/resources/splash.png`.
- Icône Windows : `master/data/veyon-master.ico` ; Qt : ressource dédiée au Master.
- `QCoreApplication` conserve les noms historiques pour retrouver la configuration.
- `--bimleman-self-test` utilise l'authentification et les contrôles d'accès ordinaires.
  Ne jamais lancer le test complet `Test-NativeInstaller.ps1` hors runner jetable.

## Validation et droit de diffusion

Un run vert signifie que les contrôles qu'il a exécutés ont réussi, pas que le
réseau du client est certifié. Le manifeste distingue `windowsValidated`,
`clientValidated` et `redistributionAuthorized`. La diffusion des installateurs
est désactivée tant que la variable GitHub `BIMLEMAN_INTERCEPTION_REDISTRIBUTION`
ne vaut pas `non-commercial`, conformément à la déclaration du demandeur tracée
dans `distribution-policy.json`. Le manifeste indique ce périmètre explicitement.

Veyon permet la dérivation sous GPL-2.0-or-later ; les mentions, COPYING et le
dialogue juridique d'origine sont conservés. Les archives de sources et scripts,
y compris les sources des bibliothèques MSYS2, sont publiées dans l'artefact
`BIMLeman-Native-Veyon-Sources` du même run, avant le candidat binaire.
Le manifeste donne leurs SHA256 ; `SOURCES.txt` installé indique leur emplacement.
Les deux artefacts restent disponibles 90 jours : conserver les deux pour toute
redistribution ultérieure. L'installation ne nécessite pas de télécharger les
archives de sources, qui restent accessibles au même endroit et aux mêmes comptes.
La licence propriétaire historique de ce dépôt ne couvre pas cette dérivation.
Interception prévoit LGPLv3 et la redistribution des actifs binaires associés
pour l'usage non commercial lorsque les pilotes sont accédés via sa bibliothèque
et son API ; Veyon utilise cette API. Il annonce une licence distincte pour l'usage commercial :
https://github.com/oblitum/Interception#license . L'autorisation dont bénéficierait
le Veyon officiel ne démontre pas celle de ce distributeur indépendant. Aucun
droit commercial n'est supposé acquis. Les textes LGPLv3, GPLv3 et les conditions
Interception sont aussi installés dans `licenses/interception`. Qt est redistribué dynamiquement avec
ses notices et sources ; ni restriction de modification ni licence propriétaire
supplémentaire ne doit être imposée à ces composants.

## Détection non destructive chez le client

Sur PowerShell Windows x64 : `& .\Get-VeyonInstallation.ps1`.
Ce script lit les chemins, la version et le SHA256 du Master et l'état du service.
Il ne lance ni CLI Veyon ni service et ne lit pas le contenu des clés.
Si l'installation est absente ou ambiguë, il refuse de choisir.
Le demandeur a confirmé la version affichée 4.11.3. La révision du fichier reste
vérifiée automatiquement et doit être exactement 4.11.3.0. Cette concordance
de version ne remplace pas la recette fonctionnelle du réseau client.

## Installation et retour arrière

1. Le téléchargement automatique utilise exclusivement `build-native-veyon.yml`,
   son artefact natif et son manifeste, jamais le lanceur .NET.
2. Par défaut `Install-From-GitHub.ps1` exige les validations Windows ET client ET
   les droits de redistribution. Il refuse si une porte n'est pas satisfaite.
   `-Pilot` autorise seulement une recette parallèle après validation technique
   et juridique ; il ne certifie pas les fonctionnalités du réseau client.
3. `Install-Safe.ps1` vérifie chaque SHA256, la version Veyon exacte 4.11.3.0 (y compris la révision),
   la fermeture de Master/Configurator et l'absence du dossier candidat.
4. Il sauvegarde installation, ProgramData/Veyon, AppData/Veyon, registre des
   deux portées et chemins de clés personnalisés, avec ACL limitée au compte,
   à SYSTEM et aux Administrateurs. Tout échec de sauvegarde bloque l'installation.
5. L'installation est par utilisateur, dans un nouveau dossier versionné
   `%LOCALAPPDATA%\Programs\BIMLemanNative\<buildId>`. Aucun service, pilote,
   pare-feu ou poste élève n'est modifié ; aucun démarrage automatique.
6. Pour revenir à l'application officielle : fermer le candidat puis lancer
   `Uninstall-Safe.ps1 -BuildId <buildId>`. Le raccourci Veyon original reste utilisable.
   La désinstallation ne retire que les fichiers connus du candidat, son raccourci
   et sa propre entrée de désinstallation. Elle conserve les sauvegardes.
7. Le lancement du Master peut enregistrer les paramètres partagés de Veyon
   (comportement upstream). Si une restauration de paramètres est nécessaire,
   conserver d'abord l'état courant puis réimporter les `.reg` du dossier de
   sauvegarde sous le même compte, et avec élévation pour HKLM. Restaurer les
   dossiers sauvegardés seulement après comparaison, jamais automatiquement.
   L'installation initiale n'écrase aucun fichier officiel ; aucune réinstallation
   de service n'est nécessaire pour revenir au Master original.

## Recette sur le PC formateur (PENDING-HARDWARE)

Noter version originale et version candidate, compte, date, salle et poste pilote.
Vérifier icône du fichier/raccourci/barre des tâches, splash et titre en français.
Comparer avec le Master officiel : annuaire/salles, connexion et miniatures,
visualisation distante, clavier/souris avec consentement, fin de prise de main,
message et verrouillage/déverrouillage d'un poste pilote autorisé. Vérifier les
fonctionnalités utilisées par ce client (démo, transfert, etc.). Ne lancer aucune
extinction/redémarrage sans fenêtre autorisée. Désinstaller le candidat puis
retester le Master officiel et l'authentification avec les clés préservées.
Joindre le compte rendu signé au commit et aux SHA256 du candidat avant de marquer
`clientValidated`. Ne pas transformer cette liste en preuve de réussite.
