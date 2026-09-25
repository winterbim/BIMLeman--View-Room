#!/usr/bin/env bash
set -euo pipefail
MODE="${1:---check}"
missing=()
command -v git >/dev/null || missing+=(git)
command -v bun >/dev/null || missing+=(bun)
command -v cargo >/dev/null || missing+=(rust)

echo "BIMLéman View Room — environnement Linux"
echo "Git : $(command -v git || echo absent)"
echo "Bun : $(command -v bun || echo absent)"
echo "Rust: $(command -v cargo || echo absent)"

if ((${#missing[@]})); then
  echo "Manquant: ${missing[*]}"
  if [[ "$MODE" == "--install" ]]; then
    if ! command -v bun >/dev/null; then curl -fsSL https://bun.sh/install | bash; fi
    if ! command -v cargo >/dev/null; then curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; fi
    echo "Rouvre le terminal puis lance bun install."
  else
    echo "Aucune installation automatique en mode --check. Utilise --install si tu veux installer Bun/Rust."
    exit 2
  fi
else
  echo "Environnement de base OK."
fi
