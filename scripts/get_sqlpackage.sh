#!/usr/bin/env bash
set -euo pipefail

# Download and unpack sqlpackage locally (macOS). Uses official aka.ms redirect.
# After running this script you can run: make import SERVER=localhost,1433

DEST_DIR=./sqlpackage
URL=${SQLPACKAGE_URL:-"https://aka.ms/sqlpackage-macos"}

echo "[INFO] Downloading sqlpackage from $URL"
TMP_ZIP=$(mktemp -t sqlpackageXXXXXX.zip)
curl -L "$URL" -o "$TMP_ZIP"

echo "[INFO] Unzipping to $DEST_DIR"
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
unzip -q "$TMP_ZIP" -d "$DEST_DIR"
rm "$TMP_ZIP"

if [[ -f "$DEST_DIR/sqlpackage" ]]; then
  chmod +x "$DEST_DIR/sqlpackage"
  echo "[INFO] sqlpackage binary ready at $DEST_DIR/sqlpackage"
  file "$DEST_DIR/sqlpackage" || true
else
  echo "[ERROR] sqlpackage binary not found after unzip." >&2
  exit 2
fi

echo "[NOTE] On Apple Silicon (arm64) this is an x64 binary; macOS should auto-use Rosetta. If not installed, run:"
echo "       softwareupdate --install-rosetta --agree-to-license"

echo "[NEXT] Run: make import SERVER=localhost,1433"
