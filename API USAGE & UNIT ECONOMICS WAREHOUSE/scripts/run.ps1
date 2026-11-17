# Full local rebuild from source to certified marts (Windows PowerShell).
# Requires: Python 3.11+, and `pip install -r requirements.txt`.
$ErrorActionPreference = "Stop"

Write-Host "1/4  Regenerating deterministic source data (seed 42)" -ForegroundColor Cyan
python ingestion/generate_data.py

Write-Host "2/4  Loading the raw layer" -ForegroundColor Cyan
dbt seed --profiles-dir profiles --full-refresh

Write-Host "3/4  Building and testing all 37 models + 143 tests" -ForegroundColor Cyan
dbt build --profiles-dir profiles

Write-Host "4/4  Certified totals" -ForegroundColor Cyan
python scripts/report.py
Write-Host "Done. Warehouse: nexora_warehouse.duckdb" -ForegroundColor Green
