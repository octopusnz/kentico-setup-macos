#!/usr/bin/env bash
set -euo pipefail

# Lightweight local import using a locally downloaded sqlpackage (no helper docker container).
# Usage: scripts/import_bacpac_local.sh <bacpac-file> <target-database> [--force]
# Will auto-download sqlpackage via scripts/get_sqlpackage.sh if missing.

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <bacpac-file> <target-database> [--force]" >&2
  exit 1
fi

BACPAC=$1
TARGET_DB=$2
FORCE=${3:-}

if [[ ! -f "$BACPAC" ]]; then
  echo "[ERROR] Bacpac '$BACPAC' not found." >&2
  exit 2
fi

SA_PASSWORD=${SA_PASSWORD:-YourStrong!Passw0rd}
SERVER=${SERVER:-localhost,1433}

if [[ ! -x ./sqlpackage/sqlpackage ]]; then
  echo "[INFO] Local sqlpackage not found; downloading..."
  bash scripts/get_sqlpackage.sh
fi

SQLPACKAGE=./sqlpackage/sqlpackage
if [[ ! -x "$SQLPACKAGE" ]]; then
  echo "[ERROR] sqlpackage binary still missing after download attempt." >&2
  exit 3
fi

echo "[INFO] Checking SQL Server availability at $SERVER ..."
ATTEMPTS=30
READY=0
for i in $(seq 1 $ATTEMPTS); do
  if docker exec mssql-kentico /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" >/dev/null 2>&1; then
    READY=1; break
  fi
  sleep 2
done
if [[ $READY -ne 1 ]]; then
  echo "[ERROR] SQL Server not reachable after $((ATTEMPTS*2))s." >&2
  exit 4
fi

echo "[INFO] Verifying if database '$TARGET_DB' exists..."
DB_EXISTS=0
if docker exec mssql-kentico /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1 FROM sys.databases WHERE name='${TARGET_DB}'" | grep -q '^1'; then
  DB_EXISTS=1
fi

if [[ $DB_EXISTS -eq 1 && "$FORCE" != "--force" ]]; then
  echo "[ERROR] Database '$TARGET_DB' already exists. Use --force to drop it." >&2
  exit 5
fi

if [[ $DB_EXISTS -eq 1 && "$FORCE" == "--force" ]]; then
  echo "[INFO] Dropping existing database $TARGET_DB ..."
  docker exec mssql-kentico /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "IF DB_ID('$TARGET_DB') IS NOT NULL BEGIN ALTER DATABASE [$TARGET_DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$TARGET_DB]; END"
fi

echo "[INFO] Importing bacpac -> $TARGET_DB (server=$SERVER)"
CONNSTR="Server=${SERVER};Database=${TARGET_DB};User ID=sa;Password=${SA_PASSWORD};TrustServerCertificate=True;Encrypt=False"
"$SQLPACKAGE" /Action:Import /SourceFile:"$BACPAC" /TargetConnectionString:"$CONNSTR" /p:CommandTimeout=0 || {
  echo "[ERROR] Import failed." >&2
  exit 6
}

echo "[INFO] Verifying imported database..."
docker exec mssql-kentico /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT name FROM sys.databases WHERE name='${TARGET_DB}';" || true
echo "[INFO] Done."
