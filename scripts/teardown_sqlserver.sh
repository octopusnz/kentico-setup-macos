#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME=${CONTAINER_NAME:-mssql-kentico}

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "[INFO] Stopping container ${CONTAINER_NAME}..."
  docker stop "${CONTAINER_NAME}" >/dev/null || true
  echo "[INFO] Removing container ${CONTAINER_NAME}..."
  docker rm "${CONTAINER_NAME}" >/dev/null || true
else
  echo "[INFO] Container ${CONTAINER_NAME} does not exist. Nothing to do."
fi

echo "[INFO] Teardown complete."
