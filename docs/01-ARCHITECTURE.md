# Architecture technique

## Poste formateur

- BIMLéman View Room (Tauri/React)
- Veyon complet
- `teacher/private`
- Veyon WebAPI en mode proxy local pour framebuffer + features
- inventaire 24 machines

## Postes élèves

- Veyon Service
- `teacher/public`
- TCP 11100 accessible depuis le réseau pédagogique
- TCP 11400 si démonstration utilisée
- aucun serveur BIMLéman

## WebAPI

Le design cible privilégie le mode **Proxy** sur le poste formateur : l'application parle à un WebAPI local qui se connecte ensuite aux Veyon Servers des clients. Cela évite d'exposer un serveur WebAPI HTTP/SSL sur chacun des 24 postes.

La clé privée est utilisée exclusivement côté backend Tauri/proxy et n'est jamais transmise au React frontend.

## Contrôle temps réel

Pour l'aide interactive, `veyon-wcli remoteaccess control <host>` ouvre le contrôle distant Veyon. Pour une simple vue, `remoteaccess view <host>`.
