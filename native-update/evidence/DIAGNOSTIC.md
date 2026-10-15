# Preuves du diagnostic natif — 15 octobre 2026

Ce registre retrace les états successifs ; la version 4.11.3 et l'usage strictement
non commercial ont ensuite été déclarés par le demandeur. La politique courante
est documentée dans `../distribution-policy.json` et `../README.md`.

Compte GitHub `winterbim` authentifié ; dépôt initial propre, branche locale main.
Fetch effectué puis suivi de `origin/feature/veyon-native-bimleman` sans écrasement.

## Échecs observés, causes et corrections

| Run | Observation réelle | Correction |
| --- | --- | --- |
| [38740359022](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38740359022) | `The packages ['qtsvg'] were not found while parsing XML of package information!` | qtsvg est une archive de base de Qt 6.8.2, pas un module additionnel. Le catalogue `aqt 3.3.0 list-qt ... --archives` contient qtsvg ; `--modules` ne le contient pas. Version 6.8.2 existante, architecture existante. |
| Analyse sources v4.11.3 | Les scripts officiels Windows utilisent MinGW. Le CMake emploie des options GCC et exige QCA, OpenSSL, VNC, Core5Compat, LinguistTools et GuiPrivate. L'ancien workflow MSVC ne les préparait pas. | Une seule chaîne MinGW64 cohérente avec dépendances MSYS2 verrouillées en version et SHA256, dont Qt 6.11.2-2, QCA 2.3.10-2, OpenSSL 3.6.5-1, libvncserver 0.9.15-3, GCC 16.2.0-6 et CMake 4.4.4-3. Ces versions proviennent du même catalogue, pas d'essais de versions Qt au hasard. Compatibilité finale à prouver par compilation et tests. |
| [38747329469](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38747329469) | Installation des dépendances réussie. Test Python : `FileNotFoundError: [WinError 2]` à `git archive`. | Ajouter explicitement Git for Windows au PATH de MSYS2. |
| [38747927725](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38747927725) | Git fonctionne. Le test de titre échoue avec l'encodage système Windows malgré le fichier UTF-8 correctement modifié. | Lecture explicite UTF-8 et PYTHONUTF8=1. Le test reste actif. |
| [38748451704](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38748451704) | Run intermédiaire remplacé par le correctif UTF-8. | Annulation demandée pour ne pas répéter le défaut connu. |

Les journaux complets initiaux sont conservés hors Git dans `../mission-evidence` ;
les logs GitHub et les artefacts Evidence restent les preuves publiques/autorisées.
Le registre ci-dessus n'affirme pas une compilation réussie.

## Compilation native obtenue, paquet encore incomplet

Run [38749376708](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38749376708),
commit `47fba99` : la cible demandée a réellement terminé avec
`[32/32] Linking CXX executable master\veyon-master.exe`. La preuve complète
est jointe dans `build-master-38749376708.txt` et l'artefact Evidence du run.
La compilation de l'ensemble des plugins a ensuite échoué à `vnckeymap.cpp:1074`
avec `unused-but-set-variable` pour `childCount`, compteur qui n'est jamais lu.
Le compteur et son incrément sans effet sont retirés par le patch UltraVNC ;
`-Werror` reste actif. Ce premier EXE compilé n'a pas encore été démarré ni livré.

La cible Windows 8 définie deux fois dans les CMake upstream est alignée sur
Windows 10, cible du Qt verrouillé ; le PCH officiel rétablit l'inclusion de
Winsock2 avant Windows.h. Aucun masquage d'avertissement n'est ajouté.
L'archive source de chacune des 111 bases de paquets a répondu HTTP 200 au
contrôle du 15 octobre ; voir `dependency-source-availability.json`.

## Vérifications locales réalisées

Deux tests de régression exécutés en échec avant correction puis en réussite :
ressources réelles de l'archive source figée, icône ICO multirésolution, splash,
titre, refus des sources inconnues avant mutation et fichiers juridiques/settings
inchangés. Analyse syntaxique PowerShell et Python ; bash -n ; git diff --check.
Le téléchargement automatique a été exécuté : il refuse en l'absence d'une
livraison native validée. Aucun installateur n'est lancé dans ce cas.

## Points externes non démontrés

Version client inconnue ; recette réseau et retour au Master officiel sur le
formateur non exécutés. Interception annonce des conditions commerciales
spécifiques ; l'autorisation de ce distributeur n'est pas disponible. La variable
GitHub de redistribution reste absente. Ni main ni les services de l'école n'ont
été modifiés. Le workflow legacy .NET ne se déclenche plus automatiquement.

## Suite de la boucle de compilation

| Run | Échec exact observé | Correction appliquée |
| --- | --- | --- |
| 38748531812 | `_WIN32_WINNT` défini deux fois (Windows 8 et 10), puis ordre Winsock incompatible sans PCH | Aligner les deux définitions CMake sur 0x0A00, rétablir le PCH officiel incluant winsock2.h en premier. |
| 38749376708 | Master lié ; compteur UltraVNC `childCount` incrémenté mais jamais lu | Retirer ce compteur sans effet ; conserver les avertissements comme erreurs. |
| 38750266782 | Anciennes définitions C de d3des.c refusées en C23 | Fixer C17, sans toucher au code cryptographique. GCC documente le passage à C23 par défaut depuis GCC 15 : https://gcc.gnu.org/gcc-15/porting_to.html . |
| 38751561012 | Ligne lupdate estimée à 51 328 caractères ; QBitArray incomplet lors d'une substitution de template dans WebApiHttpServer.cpp | Fichier réponse lupdate documenté par Qt (https://doc.qt.io/qt-6/linguist-lupdate.html), inclusion explicite de QBitArray avant QtHttpServer. |
| 38753007638 | Correctif WebAPI compilé ; lupdate échoue à 0xc0000135 après la correction de la ligne de commande | Inspection PE de lupdate.exe : dépendance Qt6Qml.dll absente. Ajouter le paquet qt6-declarative exact du même catalogue, verrouillé ; contrôler lupdate/lrelease avant compilation. |

Le verrouillage courant contient **116 paquets**, environ 244 Mio téléchargés.
L'ajout QML sert à Linguist ; l'application conserve le parcours natif C++/Qt.
Les journaux complets et artefacts des runs sont accessibles dans GitHub Actions.
La réussite du premier Master n'est pas présentée comme une réussite des tests
GUI, du paquet complet ou du réseau client.

## Recette du script pilote après clarification de l'usage

Run [38760750742](https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38760750742) :
compilation, packaging, démarrage natif et premier retour au Master officiel
réussis. La nouvelle vérification de porte production a échoué car le dossier
candidat subsistait après désinstallation. NSIS documente que `_?=` désactive
l'exécution temporaire nécessaire à l'auto-suppression ; le script attendait bien
la fin mais ne supprimait pas ensuite cet exécutable connu. Correction : supprimer
uniquement `Uninstall.exe` après sa sortie, puis le dossier seulement s'il est vide.
Les fichiers ajoutés par l'utilisateur ne sont jamais supprimés récursivement.
Référence : https://nsis.sourceforge.io/Auto-uninstall_old_before_installing_new .
Le test exige désormais explicitement l'absence du dossier, avant la seconde
installation. Les codes Robocopy de réussite 0 à 7 sont également normalisés
après contrôle, sans ignorer les échecs de sauvegarde (codes >= 8).

Inspection supplémentaire de l'EXE officiel extrait de l'installateur vérifié
SHA256 `6acad4fc310e915a631477373f7649d51b74fbe8c41c5b0ab38d2fa852876b73` :
la chaîne `FileVersion` vaut `4.11.3`, tandis que les champs numériques PE valent
`4.11.3.0` (MS=0x0004000b, LS=0x00030000). PowerShell distingue ces deux versions.
Le détecteur doit lire les quatre champs numériques, sans inventer ni ignorer
la révision. Le run 38762164678, lancé avec l'ancien détecteur, est arrêté avant
de répéter ce refus connu. Le prochain test Windows exige les deux valeurs sur
l'EXE officiel réel avant toute installation du candidat.
