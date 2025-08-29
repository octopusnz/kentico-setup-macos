#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Checking for unixODBC (libodbc.2.dylib)..."
if [[ -f /opt/homebrew/opt/unixodbc/lib/libodbc.2.dylib ]]; then
  echo "[INFO] unixODBC already installed."
else
  echo "[INFO] Installing unixODBC via Homebrew..."
  brew install unixodbc
fi

echo "[INFO] Installing Microsoft SQL Server ODBC driver + tools (msodbcsql18, mssql-tools18)..."
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release || true
ACCEPT_EULA=Y brew install msodbcsql18 mssql-tools18 || ACCEPT_EULA=Y brew upgrade msodbcsql18 mssql-tools18 || true

echo "[INFO] Verifying driver registration (odbcinst.ini)..."
grep -q '\[ODBC Driver 18 for SQL Server\]' /usr/local/etc/odbcinst.ini 2>/dev/null || \
  grep -q '\[ODBC Driver 18 for SQL Server\]' /opt/homebrew/etc/odbcinst.ini 2>/dev/null || \
  echo "[WARN] 'ODBC Driver 18 for SQL Server' not found in odbcinst.ini; installation may have failed." >&2

echo "[INFO] Done."
echo "[INFO] You can test the installation by running 'odbcinst -j' to see the installed drivers."
