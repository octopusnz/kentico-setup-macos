
# Kentico using Docker for macOS.

This project provides a generic workflow to set up a local Kentico database using Docker, Microsoft SQL Server, and a Kentico database backup (bacpac file).

We have only tested this on macOS Sequoia 15.6.* with an Apple M1 (ARM) Processor.
It hopefully works on Intel and other macOS versions but may require some tweaks.
If you do run into issues feel free to submit a pull request with any updates and include the OS version and CPU type you've tested it on.

This uses a local copy of sqlpackage rather than trying to get it working in Docker.
We ran into issues with ARM host vs the Docker image being amd-64 only and couldn't get it reliably working.

The scripts will automatically install the following things as needed:

1. sqlpackage from Microsoft into a sqlpackage/ folder in your project directory.
  https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage

2. unixODBC, Microsoft ODBC Driver 18 for SQL Server, and mssql-tools
  https://formulae.brew.sh/formula/unixodbc
  https://github.com/Microsoft/homebrew-mssql-release

3. Rosetta (if your CPU is ARM) due to the local sqlpackage being an amd-64 binary.
  https://support.apple.com/en-nz/102527

## Prerequisites
1. Docker Desktop running
  https://www.docker.com/products/docker-desktop/

2. Homebrew (for ODBC driver install)
  https://brew.sh/

3. Make if you wish to use the Makefile for convenience.
  Part of the Xcode command line tools:
  https://developer.apple.com/xcode/resources/

## Quick Start
```bash
#1. Make scripts executable
chmod +x scripts/*.sh

#2. Launch Docker Desktop (Spotlight: "Docker" or run: open -a Docker)
# If your CPU is ARM - Double check under [Settings] -> [General] --> Scroll to 
# [Virtual Machine Options]. Ensure [Apple Virtualization Framework] is selected and 
# under that [Use Rosetta for emulation] is enabled.

# 3. Start SQL Server locally
./scripts/start_sqlserver.sh

# 4. (First time) Download sqlpackage locally
./scripts/get_sqlpackage.sh

# 5. Import your bacpac into a new DB
./scripts/import_bacpac_local.sh YourBackup.bacpac KenticoLocal

# 6. Verify everything is working 
  docker exec -it mssql-kentico /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P 'YourStrong!Passw0rd' -C -Q "SELECT name FROM sys.databases;"

```
## Key Files / Scripts
- `YourBackup.bacpac` (your Kentico database backup)
- `scripts/start_sqlserver.sh` (start SQL Server container)
- `scripts/import_bacpac_local.sh` (import bacpac using local sqlpackage binary)
- `scripts/get_sqlpackage.sh` (download sqlpackage for macOS)
- `scripts/teardown_sqlserver.sh` (stop/remove SQL Server container)
- `scripts/setup_odbc_mac.sh` (install unixODBC using brew install)

## Update Makefile Variables
Before running the Makefile targets, you may want to update the following variables in the `Makefile` to match your environment:

- `BACPAC` – the path or filename of your Kentico database backup (default: `YourBackup.bacpac`)
- `DB` – the name of the database to create/import (default: `KenticoLocal`)
- `SA_PASSWORD` – the SQL Server system administrator password (default: `YourStrong!Passw0rd`)
- `CONTAINER` – the name for the SQL Server Docker container (default: `mssql-kentico`)
- `SERVER` – the SQL Server host and port (default: `host.docker.internal,1433`)

You can edit these directly in the `Makefile`, or override them at runtime:

```bash
make import BACPAC=MyBackup.bacpac DB=MyKenticoDB SA_PASSWORD='MyPassword123!'
```

How It Works
------------
1. SQL Server runs locally in Docker: `mcr.microsoft.com/mssql/server:2022-latest`.
2. Bacpac import via local sqlpackage install.

Apple Silicon (arm64) Notes
---------------------------
The official `mcr.microsoft.com/mssql/server` image is amd64-only. 

Run Docker Desktop: It transparently emulates amd64. 
  Just run `make start`.

macOS ODBC
----------
Run the helper script (installs unixODBC + msodbcsql18 + mssql-tools18):
```bash
scripts/setup_odbc_mac.sh
```
If manual:
```bash
brew install unixodbc
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
ACCEPT_EULA=Y 
brew install msodbcsql18 mssql-tools18
```
Verify driver:
```bash
odbcinst -q -d | grep 'ODBC Driver 18'
```

sqlpackage (Import Tool)
-------------------------
To install sqlpackage, use one of the following options:

Automatically:
```bash
scripts/get_sqlpackage.sh
```
This script will download and unpack the latest sqlpackage tool for macOS into `./sqlpackage/`.

Manual install:
1. Download the macOS (Intel) sqlpackage zip from Microsoft Docs: 
https://learn.microsoft.com/en-us/sql/tools/sqlpackage-download
2. Unzip into `./sqlpackage/` so the binary is at `./sqlpackage/sqlpackage`.
3. Use the import script as normal.

Apple Silicon requires Rosetta (for Intel binaries); macOS should prompt to install it if needed.

Example Make Targets & Shortcuts
--------------------------------
```
make start                # start container
make import-local         # local sqlpackage import (preferred)
make sqlcmd               # interactive sqlcmd to $(DB)
make help                 # list all targets
```
