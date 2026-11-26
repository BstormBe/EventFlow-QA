<#
.SYNOPSIS
  Remet la base EventFlow a zero (supprime le volume) puis relance l'application.
  Le mode bug courant est conserve si $env:SEED_BUGS est defini dans ce terminal.
#>
docker compose down -v
docker compose up -d --build
"Base reinitialisee. Donnees de demonstration recreees au demarrage du backend."
