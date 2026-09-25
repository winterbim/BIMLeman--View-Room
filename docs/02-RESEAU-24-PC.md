# Réseau — 24 postes / 3 salles

Nommage :
- `SALLE-A-PC01` … `SALLE-A-PC08`
- `SALLE-B-PC01` … `SALLE-B-PC08`
- `SALLE-C-PC01` … `SALLE-C-PC08`

Recommandations :
- Ethernet Gigabit pour les postes fixes ;
- DNS/hostname fonctionnel ;
- DHCP avec réservations facultatives ;
- TCP 11100 pour Veyon Server ;
- TCP 11400 pour le mode démonstration ;
- WebAPI (11080 par défaut) uniquement sur le poste proxy/gateway si activé, idéalement lié à localhost ou filtré strictement.

Le CSV `inventory/pc-inventory.csv` est l'autorité de configuration du projet.
