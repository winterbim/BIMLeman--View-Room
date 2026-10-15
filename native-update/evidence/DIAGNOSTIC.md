# Preuves du diagnostic natif — 15 octobre 2026

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
