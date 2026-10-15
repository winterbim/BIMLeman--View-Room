# BIMLéman View Room — distribution native Veyon

## Cible
Remplacer l'interface formateur Tauri par un fork maintenu de Veyon Master, avec branding BIMLéman View Room. Conserver le service Veyon sur les PC élèves.

## Contraintes bloquantes avant livraison
- Identifier la version/tag exact de Veyon correspondant au parc (diagnostic : 4.11.3).
- Vérifier la licence et les avis de copyright du code et des ressources; conserver les avis, le texte de licence et l'accès aux sources correspondantes lors de la distribution.
- Ne jamais renommer arbitrairement le service Veyon ni changer son protocole, ses clés, ses ports ou ses paramètres.
- Ne pas écraser la version Veyon Master qui fonctionne avant preuve d'une mise à niveau compatible.
- Aucun succès déclaré sans build Windows et test réel de visualisation/contrôle sur SALLE-A-PC01.

## Implémentation attendue
1. Forker la source officielle Veyon à un tag figé et consigner son SHA et sa licence.
2. Rebrander la fenêtre Veyon Master : titre BIMLéman View Room, icône, splash/ressources, nom visible et métadonnées Windows.
3. Créer des ressources graphiques originales BIMLéman et remplacer uniquement les ressources autorisées.
4. Construire un paquet Windows signé si certificat disponible, avec identité d'application distincte et détection d'installation antérieure.
5. Prévoir une migration transactionnelle avec sauvegarde et retour arrière. Ne pas supprimer Veyon existant sans consentement.
6. Valider la lecture des salles, l'authentification et la vue/contrôle réel avant livraison.
7. Publier l'artefact CI avec version, empreinte SHA-256 et procédure de mise à jour.

## Gates
G0 : source/tag/licences vérifiés.
G1 : branding et compilation Windows prouvés.
G2 : installation/migration réversible prouvée.
G3 : test réel sur PC pilote prouvé.
G4 : paquet de mise à jour publié.

État initial : G0–G4 NON VALIDÉS. Ce document n'est pas un installateur.
