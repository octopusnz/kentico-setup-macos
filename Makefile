################################################################
# Core variables (override at invocation: make target VAR=value)
################################################################

BACPAC ?= YourBackup.bacpac
DB ?= KenticoLocal
SA_PASSWORD ?= YourStrong!Passw0rd
CONTAINER ?= mssql-kentico

# SERVER name used by sqlpackage docker import:
SERVER ?= host.docker.internal,1433


.PHONY: help start import-local logs ps teardown down status sqlcmd query

help:
	@echo "Available targets:"
	@echo "  start            - Start (or reuse) local SQL Server container"
	@echo "  import-local     - Import using local sqlpackage binary (faster, recommended once downloaded)"
	@echo "  sqlcmd           - Open interactive sqlcmd session inside container"
	@echo "  query Q=SQL      - Run one-off query (quote properly)"
	@echo "  logs             - Tail SQL Server container logs"
	@echo "  ps|status        - Show container status"
	@echo "  teardown|down    - Stop & remove container"
	@echo "Variables: BACPAC DB SA_PASSWORD CONTAINER SERVER"
	@echo "Examples: make start ; make import-local ; make import BACPAC=YourBackup.bacpac DB=KenticoLocal"



# Import bacpac using local sqlpackage binary
import-local: start
	SA_PASSWORD='$(SA_PASSWORD)' ./scripts/import_bacpac_local.sh $(BACPAC) $(DB)

start:
	@chmod +x scripts/*.sh || true
	./scripts/start_sqlserver.sh

logs:
	@docker logs -f $(CONTAINER)

ps status:
	@docker ps -a --filter name=$(CONTAINER)

teardown down:
	./scripts/teardown_sqlserver.sh

# Note: correct sqlcmd path is /opt/mssql-tools18/bin/sqlcmd (not mssql-tools)
# You also need to use -C when connecting to the container due to certificate issues

sqlcmd:
	@docker exec -it $(CONTAINER) /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$(SA_PASSWORD)' -d $(DB)

query:
	@test -n "$(Q)" || (echo "Provide query via Q=... (example: make query Q=\"SELECT TOP 5 * FROM dbo.Name\")" && exit 1)
	@docker exec -it $(CONTAINER) /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$(SA_PASSWORD)' -d $(DB) -Q "$(Q)"


