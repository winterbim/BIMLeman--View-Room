#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
bun test
bun run typecheck
bun run build
(
  cd apps/desktop/src-tauri
  cargo check
  cargo test
)
echo "Gates Linux OK"
