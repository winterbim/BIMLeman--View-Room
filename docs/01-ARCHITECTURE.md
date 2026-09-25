# Architecture technique

BIMLéman View Room sépare quatre étapes, sur le modèle de VEOR 0.4 : une proposition n'est pas une autorisation, un appel réussi n'est pas une preuve, et une information incertaine ne peut qu'interdire davantage.

VEOR n'est pas embarqué dans l'application. Il n'y a pas de moteur d'orchestration générique ici. Les quatre rôles sont du code BIMLéman.

```text
Interface React
  proposition : poste, action, confirmation
        │
        ▼
@bimleman/session
  autorité déterministe : salle autorisée, message, URL, confirmation
  puis preuve locale : l'état annoncé correspond à l'action
        │
        ▼
@bimleman/veyon-adapter
  effet seulement
  MockVeyonAdapter sous Linux
  VeyonWindowsAdapter sous Windows
        │
        ▼
Tauri / Rust
  clé privée, WebAPI 127.0.0.1, remoteaccess, journal fichier
```

`@bimleman/domain` porte l'inventaire, les types et les règles pures. Il n'appelle ni le réseau ni Veyon.

Une salle ajoutée après la création de la session ne donne aucun droit : la liste autorisée est copiée et gelée. Une action inconnue échoue. Un adaptateur qui répond sans changer l'état n'est pas journalisé comme un succès.

Cette preuve est locale. Elle ne démontre pas que l'écran distant est réellement figé. Cette vérification reste matérielle.

## Poste formateur

- BIMLéman View Room (Tauri/React)
- Veyon complet
- `teacher/private`, lue seulement par le backend Rust
- Veyon WebAPI en proxy local pour les miniatures et les fonctions
- inventaire de 24 machines

## Postes élèves

- Veyon Service
- `teacher/public`
- TCP 11100 accessible depuis le réseau pédagogique
- TCP 11400 seulement si la démonstration Veyon est utilisée
- aucun serveur BIMLéman
- WebAPI désactivé

## WebAPI

L'application parle à un WebAPI sur le poste formateur, lié à la boucle locale. Ce service se connecte ensuite aux Veyon Servers des clients. Les 24 postes n'exposent pas ce HTTP.

## Contrôle temps réel

`veyon-wcli remoteaccess control <host>` ouvre l'aide. `remoteaccess view <host>` ouvre la vue. Ces commandes passent par Rust, qui refuse un hôte hors du parc.
