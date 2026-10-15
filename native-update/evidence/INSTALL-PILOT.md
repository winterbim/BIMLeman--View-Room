# Installer le candidat pilote depuis GitHub

Usage strictement non commercial. Fermer Veyon Master et Configurator.
Utiliser PowerShell Windows **x64**, sous le compte habituel de Veyon, avec
GitHub CLI (`gh`) déjà installé et authentifié. La commande refuse les prérequis
non satisfaits. Elle installe en parallèle après sauvegarde et ne lance pas Master.
L'installateur est non signé ; la recette du réseau client reste à réaliser.

Une seule commande, avec script de récupération figé et vérifié par SHA256 :

```powershell
& {
  $ErrorActionPreference = 'Stop'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $p = Join-Path $env:LOCALAPPDATA 'bn.ps1'
  try {
    Invoke-WebRequest -UseBasicParsing 'https://github.com/winterbim/BIMLeman--View-Room/releases/download/native-v4.11.3-fe9f2d92-pilot/Install-From-GitHub.ps1' -OutFile $p
    if ((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne 'f9b18c5539e2d77a980d225646204d43bf16b7285f67271a69f2f63b70362ebb') { throw 'SHA256 du script incorrect.' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p -Pilot
    if ($LASTEXITCODE -ne 0) { throw 'Installation refusee ou echouee ; voir le message precedent.' }
  } finally { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
}
```

Le script télécharge le candidat depuis la préversion GitHub figée. Il vérifie le
commit, les portes du manifeste et chaque SHA256.
`-Pilot` autorise la recette parallèle documentée ; il ne modifie pas
`clientValidated` et ne certifie pas la salle. Sans ce commutateur, l'installation
de production reste refusée. Windows 10 1809 ou ultérieur et Veyon PE 4.11.3.0
sont exigés. Aucune configuration ni service de l'école n'a été modifié pendant
la préparation de cette livraison.

Les téléchargements sont conservés dans `%LOCALAPPDATA%\bn\r` (chemin court,
MAX_PATH des postes clients) ; les sauvegardes privées restent dans
`%LOCALAPPDATA%\BIMLemanNativeBackups`. Le retour au Master officiel est décrit
dans la [procédure complète](../README.md#installation-et-retour-arrière).
Les artefacts Actions expirent après 90 jours : utiliser la préversion GitHub
et ses fichiers conservés ensemble si leur téléchargement automatique n'est
plus disponible. Dans ce cas, ne pas retirer les vérifications d'Install-Safe.
