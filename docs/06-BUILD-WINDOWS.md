# Build Windows depuis un développement Linux

## Référence production : GitHub Actions Windows

Le workflow `.github/workflows/windows-release.yml` construit l'application sur `windows-latest` et Tauri génère un installateur NSIS `.exe`.

Créer un tag :

```bash
git tag v0.1.0
git push origin v0.1.0
```

Le draft GitHub Release contiendra l'installateur.

## Cross-build Linux

`scripts/release/build-windows-cross.sh` est fourni uniquement comme voie secondaire. Le build Windows natif CI reste la référence parce que la documentation Tauri décrit le cross-build Linux comme possible mais avec davantage de contraintes.

## Signature

Avant diffusion large, ajouter une signature Authenticode Windows. Ne pas stocker le certificat ou son mot de passe dans le dépôt ; utiliser les secrets du système CI.
