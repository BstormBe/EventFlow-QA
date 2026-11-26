<#
.SYNOPSIS
  Verifie que le poste est pret pour la formation (a lancer depuis la racine du depot).
.EXAMPLE
  .\scripts\check-poste.ps1
#>
$ok = 0; $ko = 0; $warn = 0
function Test-Etape($nom, [scriptblock]$test, $conseil) {
    try { $r = & $test } catch { $r = $false }
    if ($r -eq $true) { Write-Host "[OK]    $nom" -ForegroundColor Green; $script:ok++ }
    elseif ($r -eq 'warn') { Write-Host "[ATTN]  $nom -> $conseil" -ForegroundColor Yellow; $script:warn++ }
    else { Write-Host "[KO]    $nom -> $conseil" -ForegroundColor Red; $script:ko++ }
}
function Get-Out($cmd) { try { (& $cmd 2>&1 | Out-String).Trim() } catch { "" } }

Write-Host "`n== Shell et outils ==" -ForegroundColor Cyan
Test-Etape "PowerShell $($PSVersionTable.PSVersion)" { $PSVersionTable.PSVersion.Major -ge 7 -or 'warn' } "PowerShell 7 recommande (winget install Microsoft.PowerShell). Ne pas utiliser cmd.exe."
Test-Etape "Racine du depot" { (Test-Path .\docker-compose.yml) -and (Test-Path .\qa) } "Placez-vous a la racine du depot (dossier qui contient docker-compose.yml et qa/)."
Test-Etape "git" { [bool](Get-Command git -ErrorAction SilentlyContinue) } "Installer Git for Windows."
$py = Get-Out { python --version }
Test-Etape "Python ($py)" {
    if ($py -match 'Python 3\.(1[1-3])\.') { $true } elseif ($py -match 'Python 3\.') { 'warn' } else { $false }
} "Python 3.12 recommande (3.11 a 3.13 testes). 3.14 : non teste pour ce cours."
Test-Etape "Docker en marche" { docker info *> $null; $LASTEXITCODE -eq 0 } "Demarrer Docker Desktop."
Test-Etape "GitHub CLI (gh)" { [bool](Get-Command gh -ErrorAction SilentlyContinue) } "winget install GitHub.cli puis gh auth login"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Test-Etape "gh authentifie" { gh auth status *> $null; $LASTEXITCODE -eq 0 } "gh auth login"
}
Test-Etape "gitleaks" { [bool](Get-Command gitleaks -ErrorAction SilentlyContinue) } "winget install Gitleaks.Gitleaks (8.30.1 utilise pour les supports)"

Write-Host "`n== Environnement Python (qa/.venv) ==" -ForegroundColor Cyan
$venvPy = ".\qa\.venv\Scripts\python.exe"
Test-Etape "venv qa/.venv" { Test-Path $venvPy } "cd qa; python -m venv .venv; .\.venv\Scripts\Activate.ps1; python -m pip install -r requirements.txt -r requirements-dev.txt"
if (Test-Path $venvPy) {
    $manquants = & $venvPy -c "import importlib.util as u; m=['pytest','requests','jsonschema','sqlalchemy','psycopg2','dotenv','jwt','playwright','selenium','ruff','bandit','pip_audit','commitizen','pre_commit']; print(' '.join(x for x in m if not u.find_spec(x)))"
    Test-Etape "Paquets du venv" { [string]::IsNullOrWhiteSpace($manquants) } "Manquants : $manquants -> python -m pip install -r requirements.txt -r requirements-dev.txt (dans qa/, venv actif)"
}

Write-Host "`n== Ports et application ==" -ForegroundColor Cyan
$pg = Get-Service postgresql* -ErrorAction SilentlyContinue | Where-Object Status -eq 'Running'
Test-Etape "PostgreSQL local" { if ($pg) { 'warn' } else { $true } } "Un PostgreSQL local tourne ($($pg.Name -join ', ')). Sans danger : EventFlow utilise le port 5433. Verifiez que qa/.env contient localhost:5433."
$p5433 = Get-NetTCPConnection -LocalPort 5433 -State Listen -ErrorAction SilentlyContinue
$dockerDb = (docker ps --format "{{.Names}} {{.Ports}}" 2>$null) -match '5433->5432'
Test-Etape "Port 5433 (base EventFlow)" { (-not $p5433) -or $dockerDb } "Le port 5433 est pris par un autre programme que la base EventFlow."
Test-Etape "qa/.env pointe sur localhost:5433" { (Get-Content .\qa\.env -Raw) -match 'localhost:5433' } "Corriger DB_URL dans qa/.env"
try { $cfg = Invoke-RestMethod http://localhost:8000/api/config -TimeoutSec 3 } catch { $cfg = $null }
Test-Etape "API EventFlow (http://localhost:8000)" { if ($cfg) { $true } else { 'warn' } } "Application non demarree : docker compose up -d --build"
if ($cfg) { Write-Host "        Mode bug (SEED_BUGS) : $($cfg.seed_bugs)" }

Write-Host "`n== Git ==" -ForegroundColor Cyan
$branche = Get-Out { git branch --show-current }
Test-Etape "Branche courante : $branche" { if ($branche -eq 'main') { $true } else { 'warn' } } "Normal si vous travaillez sur une branche de travail ; partez toujours de main."
$remote = Get-Out { git remote get-url origin }
Test-Etape "Remote origin = votre fork ($remote)" { if ($remote -notmatch 'github\.com') { $false } elseif ($remote -match 'BstormBe/') { $false } else { $true } } "origin doit pointer sur VOTRE fork (pas sur BstormBe) : git remote -v"

Write-Host "`nBilan : $ok OK, $warn a verifier, $ko a corriger." -ForegroundColor Cyan
if ($ko -gt 0) { exit 1 }
