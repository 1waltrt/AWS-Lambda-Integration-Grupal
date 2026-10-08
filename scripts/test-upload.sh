#!/usr/bin/env bash
# Prueba el endpoint con multipart y con JSON+base64.
# Uso:
#   ./scripts/test-upload.sh <upload_url> [imagen.png]
#   ./scripts/test-upload.sh "$(terraform -chdir=envs/dev output -raw upload_url)"
# Opcional: BUCKET=<nombre> para listar processed/ al final (requiere AWS CLI con sesión).
set -euo pipefail

URL="${1:?Falta la URL (output upload_url)}"
IMG="${2:-}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -z "$IMG" ]; then
  # PNG de 1x1 píxel
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" | base64 -d > "$TMP/test.png"
  IMG="$TMP/test.png"
fi

echo "=== 1) multipart/form-data ==="
curl -sS -o /dev/stdout -w "\nHTTP %{http_code}\n" \
  -F "file=@${IMG};type=image/png" "$URL"

echo
echo "=== 2) JSON + base64 ==="
B64="$(base64 -w0 "$IMG")"
printf '{"filename":"test.png","image":"%s"}' "$B64" > "$TMP/body.json"
curl -sS -o /dev/stdout -w "\nHTTP %{http_code}\n" \
  -H "content-type: application/json" --data @"$TMP/body.json" "$URL"

echo
echo "=== 3) tipo no permitido (debe dar 415) ==="
echo "esto no es una imagen" > "$TMP/fake.txt"
curl -sS -o /dev/stdout -w "\nHTTP %{http_code}\n" \
  -F "file=@${TMP}/fake.txt;type=image/png" "$URL"

if [ -n "${BUCKET:-}" ]; then
  echo
  echo "=== processed/ (esperar unos segundos) ==="
  sleep 10
  aws s3 ls "s3://${BUCKET}/processed/"
fi
