# Sécurité et confidentialité

- uniquement les PC administrés de l'établissement ;
- information claire des utilisateurs ;
- permissions formateur limitées aux salles autorisées ;
- clé privée uniquement sur le poste formateur/gateway ;
- clé publique sur les clients ;
- pas de keylogging ;
- pas d'enregistrement vidéo permanent ;
- pas d'envoi de framebuffer vers un SaaS public ;
- logs = identité/action/machine/résultat, jamais contenu écran ;
- confirmation pour reboot/shutdown ;
- révocation immédiate des accès lorsqu'un formateur n'est plus autorisé ;
- sauvegardes de configuration sans secrets exposés dans git ;
- le script de sauvegarde refuse un export qui contiendrait un bloc `BEGIN PRIVATE KEY` ;
- les commandes Rust refusent tout hôte qui n'est pas `SALLE-[ABC]-PC01` … `PC08`, sauf adresse IPv4 privée listée dans le fichier pointé par `BIMLEMAN_INVENTORY` sur le poste formateur ;
- journal d'audit : acteur, action, machine, résultat. Pas de miniature, pas de clé, pas de texte de consigne.
