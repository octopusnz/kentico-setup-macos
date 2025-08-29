#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME=${CONTAINER_NAME:-mssql-kentico}
SA_PASSWORD=${SA_PASSWORD:-YourStrong!Passw0rd}
# Default full SQL Server image (amd64 only). On arm64 you can optionally set USE_EDGE=1 to use azure-sql-edge multi-arch.
if [[ "${USE_EDGE:-0}" == "1" ]]; then
  IMAGE=${SQL_IMAGE:-mcr.microsoft.com/azure-sql-edge}
  EDGE_NOTE=" (azure-sql-edge mode)"
else
  IMAGE=${SQL_IMAGE:-mcr.microsoft.com/mssql/server:2022-latest}
  EDGE_NOTE=""
fi

# Detect architecture (Apple Silicon needs amd64 emulation for official SQL Server image as of now)
ARCH=$(uname -m)
PLATFORM_ARG=""
if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
  if [[ "${USE_EDGE:-0}" == "1" ]]; then
    PLATFORM_ARG=""  # azure-sql-edge is multi-arch
  else
    PLATFORM_ARG="--platform=linux/amd64"  # emulate
  fi
fi

# Quick docker daemon availability check
if ! docker info >/dev/null 2>&1; then
  cat <<'EOF' >&2
[ERROR] Cannot talk to Docker daemon.
  Fix suggestions (macOS):
    1. Ensure Docker Desktop is installed: https://www.docker.com/products/docker-desktop/
    2. Start it (Spotlight: "Docker" or run: open -a Docker)
    3. Wait for the whale icon to stop animating (engine started)
    4. Re-run this script.
EOF
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "[INFO] Container ${CONTAINER_NAME} already exists. Starting (or ensuring it's running)..."
  docker start "${CONTAINER_NAME}" >/dev/null
else
  echo "[INFO] Creating and starting SQL Server container ${CONTAINER_NAME} (arch=${ARCH})${EDGE_NOTE}"
  docker run -d ${PLATFORM_ARG} \
    --name "${CONTAINER_NAME}" \
    -e 'ACCEPT_EULA=Y' \
    -e "MSSQL_SA_PASSWORD=${SA_PASSWORD}" \
    -p 1433:1433 \
    "${IMAGE}" >/dev/null
fi

echo "[INFO] Waiting for SQL Server to accept connections..."
WAIT_SECONDS=${WAIT_SECONDS:-120}
SLEEP=2
ATTEMPTS=$(( WAIT_SECONDS / SLEEP ))

readiness_log_match() {
  docker logs "${CONTAINER_NAME}" 2>&1 | grep -Eq \
    'SQL Server is now ready for client connections|Azure SQL|Now listening on|Server name is'
}

probe_sql_login() {
  # Try a lightweight login using external tools image (works even if container lacks sqlcmd)
  local platform_arg=""
  if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    platform_arg="--platform=linux/amd64"
  fi
  docker run --rm $platform_arg --network host mcr.microsoft.com/mssql-tools \
    /opt/mssql-tools/bin/sqlcmd -C -S localhost -U sa -P "${SA_PASSWORD}" -Q "SELECT 1" >/dev/null 2>&1 || return 1
  return 0
}

for i in $(seq 1 $ATTEMPTS); do
  if readiness_log_match; then
    echo "[INFO] Detected readiness via logs."
    exit 0
  fi
  if probe_sql_login; then
    echo "[INFO] SQL login succeeded; server is ready."
    exit 0
  fi
  sleep $SLEEP
done

echo "[ERROR] Timeout (${WAIT_SECONDS}s) waiting for SQL Server readiness." >&2
echo "[DIAG] Container status:" >&2
docker ps -a --filter name="${CONTAINER_NAME}" >&2 || true
echo "[DIAG] Last 60 log lines:" >&2
docker logs --tail 60 "${CONTAINER_NAME}" >&2 || true
echo "[HINT] Possible causes:" >&2
echo "  - Insufficient memory (allocate >= 2.5GB to Docker)." >&2
echo "  - SA password failed complexity; container keeps restarting (check logs for 'password')." >&2
echo "  - Using USE_EDGE=1? Edge may log different readiness text; login probe should have caught readiness." >&2
echo "  - Architecture emulation slow; increase WAIT_SECONDS=240." >&2
exit 1
