<#
.SYNOPSIS
  Redemarre le backend AVEC les bugs du fil rouge (SEED_BUGS=true). A lancer depuis la racine du depot.
#>
$env:SEED_BUGS = "true"
docker compose up -d backend
for ($i = 0; $i -lt 30; $i++) {
    try { $cfg = Invoke-RestMethod http://localhost:8000/api/config -TimeoutSec 2; break } catch { Start-Sleep -Seconds 2 }
}
if ($cfg) { "Mode bug (SEED_BUGS) : " + $cfg.seed_bugs } else { "API toujours indisponible apres 60 s : docker compose logs backend" ; exit 1 }
