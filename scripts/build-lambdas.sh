#!/usr/bin/env bash
# Instala dependencias de las Lambdas (necesario antes de terraform plan/apply).
# sharp se instala para linux/x64 (runtime nodejs20.x en x86_64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for fn in upload-lambda crop-lambda; do
  echo ">> $fn"
  cd "$ROOT/src/$fn"
  rm -rf node_modules
  npm install --omit=dev --no-audit --no-fund --os=linux --cpu=x64
done

echo "OK: dependencias instaladas. Ahora puedes correr terraform plan/apply."
