#!/usr/bin/env bash
set -euo pipefail
cat <<'EOF'
Ce script est secondaire. La production de référence utilise GitHub Actions Windows.
Prérequis cross-build Tauri: lld llvm, cible Rust x86_64-pc-windows-msvc et cargo-xwin.
EOF
bun --cwd apps/desktop tauri build -- --runner cargo-xwin --target x86_64-pc-windows-msvc
