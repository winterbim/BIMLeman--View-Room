# Configuration Veyon de production

Ce dossier ne contient volontairement **aucune clé privée** et aucune configuration Veyon inventée.

Après validation du poste pilote :

```powershell
& "C:\Program Files\Veyon\veyon-wcli.exe" config export "$PWD\veyon-config.json"
```

Place ensuite `veyon-config.json` ici. La clé publique produite par le poste formateur doit rester dans le dossier de déploiement local et ne doit pas être commitée si l'organisation préfère la gérer comme secret opérationnel.
