# Recette technique Windows — 15 octobre 2026

> Rapport historique du premier run réussi, avant confirmation de version et
> d'usage non commercial. État courant : [livraison pilote](PILOT-DELIVERY.md).

**BUILD ET RECETTE AUTOMATISÉE : PASS. LIVRAISON CLIENT : BLOQUÉE.**

- Run : https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38754270228
- Commit compilé et testé : `75fb1886a46592b48bd09e1cc2561bca95f1fb39`.
- Veyon source : v4.11.3, `0c629d9931810a5974038fc1a207d52fbd0e65f6`.
- Plateforme de test : runner GitHub hébergé Windows 2022 x64, environnement jetable.
- Vrai EXE compilé : `veyon-master.exe`, PE32+ x64, sous-système Windows GUI 2.
- SHA256 du Master compilé **identique à celui installé** :
  `9c25f648220c45b830043165d96ec4f3382880e59e7aec6cb549adc18eb13aee`.
- Installateur NSIS généré et exécuté : `BIMLeman-4.11.3-75fb1886-setup.exe`,
  33 005 345 octets. Installateur/application non signés Authenticode.
- Runtime installé : 361 fichiers, dont 82 DLL ; source de ces nombres : installed-files.json.
- Qt exécuté : 6.11.2 ; version Veyon exécutée : 4.11.3.
- Artefact original des preuves : https://github.com/winterbim/BIMLeman--View-Room/actions/runs/38754270228/artifacts/11982938304
  (SHA256 ZIP `eec2d4eb6df321a925a933a6b48f0ed3531c7a9ab701218be9810af4a21683ee`).

## Résultats réellement vérifiés

| Contrôle | Résultat et limite |
| --- | --- |
| Compilation Master | PASS, cible explicite `veyon-master`, pas un lanceur .NET. |
| Tous les composants/plugins | PASS, y compris UltraVNC, LDAP, WebAPI et traductions. |
| Dépendances | Imports PE inspectés récursivement ; DLL manquante non système refusée. Démarrage avec PATH limité à Windows, sans outils de build ni QT_PLUGIN_PATH. |
| Icône Windows | MATCHED, extraction de la ressource PE et comparaison pixel à pixel avec l'ICO BIMLéman. |
| Icône Qt et splash | PASS, ressources chargées comparées par SHA256 aux images préparées ; captures jointes. |
| Titre principal | PASS, propriété réelle de la fenêtre : BIMLéman View Room. La capture QWidget ne comprend pas la décoration/titre Windows. |
| Fonctions natives disponibles | 38 fonctions enregistrées ; RemoteView, RemoteControl, ScreenLock et TextMessage explicitement exigées. Aucun test de commande distante sur le réseau client. |
| Installation parallèle | PASS dans un nouveau dossier par utilisateur ; destination forcée non autorisée et écrasement du même candidat refusés. |
| Désinstallation | PASS ; fichier témoin des données partagées conservé. |
| Veyon officiel préexistant | Version officielle 4.11.3.0 installée comme référence dans le runner. Tous ses fichiers et l'état de son service inchangés après désinstallation du candidat ; CLI puis fenêtre Master officielle rouvertes. |
| Authentification | Méthode native et paire de clés éphémères de test ; aucun contournement des contrôles d'accès. Aucune clé réelle du client employée. |
| Pilotage réseau réel | PENDING-HARDWARE. Connexion aux PC, images et commandes dans les salles non testées ici. |
| Sauvegarde client/retour de paramètres réels | Scripts préparés et analysés syntaxiquement ; pas exécutés sur le formateur. Le test ci-dessus valide l'installation/désinstallation parallèle, pas une restauration de clés réelles. |

## Pourquoi aucun installateur n'est publié

L'étape d'upload de l'installateur et des sources correspondantes est **SKIPPED**,
conformément à la porte `BIMLEMAN_INTERCEPTION_REDISTRIBUTION`. Le run vert ne
constitue pas une autorisation de distribution commerciale.

La licence GPL de Veyon autorise des dérivations avec ses obligations ; COPYING,
attributions, notices de modification et sources correspondantes sont conservés
ou préparés. Interception annonce des conditions distinctes d'usage commercial :
https://github.com/oblitum/Interception#license . Aucune autorisation applicable
à cette redistribution personnalisée n'a été fournie. Aucun droit commercial
n'est supposé acquis et aucun binaire Interception personnalisé n'est publié.
Les archives de sources ont été produites pendant le run ; elles ne sont pas
présentées comme des téléchargements disponibles, l'upload étant bloqué.
Le SHA256 de l'installateur n'a pas été exporté dans l'artefact Evidence ; seule
sa taille et son exécution sont attestées par le journal. Le hash du Master est,
lui, conservé et comparé au fichier réellement installé.

La version du PC formateur reste inconnue. Le script d'installation exige
4.11.3.0 exactement, y compris la révision, et Windows 10 1809 ou ultérieur.
Le client doit ensuite valider la recette réseau du README et le retour au
Master officiel. `clientValidated` reste faux ; aucune installation de production
n'est donc autorisée par le script. Aucun service ni poste de l'école n'a été modifié.

La commande de récupération, exécutée après ce run vert, refuse effectivement
l’installation puisqu’aucun installateur autorisé n’est publié. Le script de
récupération est figé au commit 75fb1886 et son SHA256 est
`f0e6ad7379348000d8355b71a4d790863f338d6f2604f12a77abaaf63242f963`.

Les copies JSON et textuelles de ce dossier sont normalisées pour lecture ; l'artefact GitHub
ci-dessus conserve les preuves originales. Les images sont des captures réelles
produites dans le runner, pas des maquettes.
