# Intégration Veyon

## Fonctions retenues

- vue distante ;
- contrôle distant ;
- framebuffer miniature ;
- ScreenLock ;
- TextMessage ;
- OpenWebsite ;
- Reboot ;
- PowerDown.

## WebAPI

Authentification AuthKeys :
- méthode UUID `0c69b301-81b4-42d6-8fae-128cdd113314` ;
- POST `/api/v1/authentication/<HOST>` ;
- le backend envoie `keyname` + la clé privée PEM ;
- la réponse fournit `connection-uid` ;
- le header `Connection-Uid` est réutilisé pour framebuffer/features.

Framebuffer :
`GET /api/v1/framebuffer?format=jpeg&quality=40&width=320`

Features :
- ScreenLock `ccb535a2-1d24-4cc1-a709-8b47d2b2ac79`
- Reboot `4f7d98f0-395a-4fff-b968-e49b8d0f748c`
- PowerDown `6f5a27a0-0e2f-496e-afcc-7aae62eede10`
- OpenWebsite `8a11a75d-b3db-48b6-b9cb-f8422ddd5b0c`
- TextMessage `e75ae9c8-ac17-4d00-8f0d-019348346208`

L'implémentation conserve la clé privée uniquement dans le backend Rust (`apps/desktop/src-tauri`). Le frontend ne reçoit jamais `keydata`. Le client HTTP n'accepte qu'une base `http://127.0.0.1` ou `http://localhost`, ne suit pas les redirections, et réauthentifie si la connexion est expirée. Les erreurs renvoyées à l'interface sont rédigées sans contenu de clé.

Le poste formateur active `WebAPI/HttpServerEnabled` sur le port 11080 et bloque ce port en entrée. Veyon ne publie pas d'adresse d'écoute séparée : le pare-feu est donc la barrière réseau, et l'application ne contacte que la boucle locale. Les 24 clients ont `WebAPI/HttpServerEnabled` à `false`.
