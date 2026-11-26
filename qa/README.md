# EventFlow-QA

Projet de tests automatises de l'application EventFlow (formation Testeur QA).

**Premier reflexe sous Windows** (PowerShell 7, depuis la racine du depot) : `.\scripts\check-poste.ps1`
verifie Python, Docker, gh, gitleaks, le venv, les ports et le remote de votre fork.

## Structure

```
qa/
├── conftest.py              fixtures communes (clients API, evenement de test)
├── pytest.ini               configuration pytest, marqueurs
├── requirements.txt         dependances de test
├── requirements-perf.txt    dependances du test de charge
├── .env                     configuration (URL, comptes)
├── data/                    jeux de donnees (CSV, JSON) pour les tests pilotes par les donnees
├── schemas/                 contrats JSON Schema de l'API
├── utils/                   client API, acces BDD, fabriques de donnees
└── tests/
    ├── api/                 PyTest : auth, catalogue, regles metier, securite, BDD
    ├── ui/playwright/       Playwright : parcours client, mocks reseau
    ├── ui/selenium_backoffice/  Selenium + Page Object Model : back-office
    └── performance/         Locust : flash sale
```

## Lancer l'application

Depuis la racine du depot :

```bash
docker compose up -d --build
```

La base PostgreSQL est exposee sur **localhost:5433** (pas 5432) pour ne pas entrer en conflit
avec un PostgreSQL installe sur le poste.

Sous Windows (PowerShell), depuis la racine du depot :

```powershell
.\scripts\bugs-on.ps1     # redemarre le backend AVEC les bugs du fil rouge
.\scripts\bugs-off.ps1    # ... SANS les bugs
.\scripts\reset-db.ps1    # remise a zero des donnees (docker compose down -v puis up)
```

Equivalent bash : `SEED_BUGS=true docker compose up -d backend` ; remise a zero : `docker compose down -v`.

## Installer les tests

```bash
cd qa
python -m venv .venv
source .venv/bin/activate        # Windows (PowerShell) : .\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt -r requirements-dev.txt
python -m playwright install chromium   # navigateur pour les tests UI
```

`requirements-dev.txt` contient les outils qualite et securite du cours (Ruff, pre-commit, Bandit,
pip-audit, zizmor, commitizen), en versions epinglees. Python 3.12 recommande.

## Lancer les tests

```bash
pytest tests/api                 # tests d'API
pytest tests/api -n auto         # en parallele
pytest -m security               # uniquement les tests de securite
pytest -m db                     # coherence base de donnees (PostgreSQL du docker compose)
pytest tests/ui/playwright       # tests UI Playwright (headless)
pytest tests/ui/playwright --headed --slowmo 500   # pour voir le navigateur
pytest tests/ui/selenium_backoffice                 # back-office Selenium (HEADLESS=false pour voir Chrome)
```

En cas d'echec, la trace Playwright est dans `reports/playwright/` :
`playwright show-trace reports/playwright/<test>/trace.zip`

### Rapport Allure

```bash
pytest --alluredir=reports/allure-results
npx allure generate reports/allure-results -o reports/allure-report
npx allure open reports/allure-report
```

### Test de charge

```bash
pip install -r requirements-perf.txt
locust -f tests/performance/locustfile.py --host http://localhost:8000 --headless -u 50 -r 10 -t 1m --html reports/locust.html
```

## Avec les bugs du fil rouge

Avec `SEED_BUGS=true`, plusieurs tests passent au rouge : c'est attendu, ils detectent les bugs B1 a B12.

## Integration continue

Le workflow `.github/workflows/ci.yml` demarre l'application avec docker compose et lance toutes les suites
a chaque push. Le rapport Allure et les traces sont dans l'artefact `rapports-qa`.
Pour lancer le pipeline avec les bugs : onglet Actions > CI > Run workflow > seed_bugs = true,
ou `gh workflow run ci.yml --ref main -f seed_bugs=true`.

Sur un fork, les workflows sont **desactives** tant que vous ne les activez pas (onglet Actions).

Le workflow `.github/workflows/sonar.yml` analyse le code avec SonarQube Cloud. Il ne fait rien tant que
le secret `SONAR_TOKEN` n'existe pas dans votre depot et que `sonar-project.properties` (racine)
n'a pas recu votre organisation et votre cle de projet.
