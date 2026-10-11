# deploy-all.ps1 - Crea y despliega todo el ambiente de PromptSales en Kubernetes

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  PromptSales - Deployment Script  " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl no instalado" -ForegroundColor Red
    exit 1
}

Write-Host "[1/6] Verificando Kubernetes..." -ForegroundColor Yellow
kubectl cluster-info --request-timeout=5s 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Kubernetes no esta corriendo" -ForegroundColor Red
    exit 1
}
Write-Host "OK Kubernetes activo" -ForegroundColor Green
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$kubernetesPath = Split-Path -Parent $scriptPath
Set-Location $kubernetesPath

# Cargar las contrasenas desde el archivo .env de la raiz del repositorio
$envFile = Join-Path (Split-Path -Parent $kubernetesPath) ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: No se encontro el archivo .env. Copia .env.example como .env y completa las contrasenas" -ForegroundColor Red
    exit 1
}
$envVars = @{}
foreach ($line in Get-Content $envFile) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $envVars[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
    }
}

Write-Host "[2/6] Desplegando namespaces..." -ForegroundColor Yellow
kubectl apply -f namespaces/all-namespaces.yaml
Write-Host "OK Namespaces creados" -ForegroundColor Green
Write-Host ""

Write-Host "[3/6] Desplegando secrets..." -ForegroundColor Yellow
# Reemplazar las variables ${VARIABLE} del YAML con los valores del .env antes de aplicarlo
$secrets = Get-Content secrets/all-secrets.yaml -Raw -Encoding UTF8
foreach ($key in $envVars.Keys) {
    $secrets = $secrets.Replace('${' + $key + '}', $envVars[$key])
}
$missing = ($secrets -split "`n" | ForEach-Object { if ($_ -notmatch '^\s*#' -and $_ -match '\$\{(\w+)\}') { $Matches[1] } }) -join ", "
if ($missing) {
    Write-Host "ERROR: Faltan estas variables en el archivo .env: $missing" -ForegroundColor Red
    exit 1
}
$tempSecrets = Join-Path ([System.IO.Path]::GetTempPath()) "promptsales-secrets.yaml"
[System.IO.File]::WriteAllText($tempSecrets, $secrets, (New-Object System.Text.UTF8Encoding $false))
kubectl apply -f $tempSecrets
Remove-Item $tempSecrets
Write-Host "OK Secrets creados" -ForegroundColor Green
Write-Host ""

Write-Host "[4/6] Desplegando bases de datos..." -ForegroundColor Yellow
Write-Host "  PostgreSQL..." -ForegroundColor Cyan
kubectl apply -f databases/postgresql/
Write-Host "  MongoDB..." -ForegroundColor Cyan
kubectl apply -f databases/mongodb/
Write-Host "  SQL Server Ads..." -ForegroundColor Cyan
kubectl apply -f databases/sqlserver-ads/
Write-Host "  SQL Server CRM..." -ForegroundColor Cyan
kubectl apply -f databases/sqlserver-crm/
Write-Host "  Redis..." -ForegroundColor Cyan
kubectl apply -f databases/redis/
Write-Host "OK Bases de datos desplegadas" -ForegroundColor Green
Write-Host ""

Write-Host "[5/6] Esperando a que los pods esten listos..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
kubectl wait --for=condition=ready pod -l app=postgresql -n promptsales --timeout=300s 2>$null
kubectl wait --for=condition=ready pod -l app=mongodb -n promptcontent --timeout=300s 2>$null
kubectl wait --for=condition=ready pod -l app=sqlserver-ads -n promptads --timeout=300s 2>$null
kubectl wait --for=condition=ready pod -l app=sqlserver-crm -n promptcrm --timeout=300s 2>$null
kubectl wait --for=condition=ready pod -l app=redis -n redis --timeout=300s 2>$null
Write-Host "OK Pods listos" -ForegroundColor Green
Write-Host ""

Write-Host "[6/6] Estado final..." -ForegroundColor Yellow
kubectl get pods --all-namespaces | Select-String "prompt|redis"
Write-Host ""

Write-Host "=====================================" -ForegroundColor Green
Write-Host "  Deployment completado!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Conexiones disponibles:" -ForegroundColor Cyan
Write-Host "  PostgreSQL: localhost:30432 (postgres/$($envVars['POSTGRES_PASSWORD']))" -ForegroundColor White
Write-Host "  MongoDB:    localhost:30017 (mongouser/$($envVars['MONGO_PASSWORD']))" -ForegroundColor White
Write-Host "  SQL Ads:    localhost:31433 (sa/$($envVars['MSSQL_SA_PASSWORD']))" -ForegroundColor White
Write-Host "  SQL CRM:    localhost:32433 (sa/$($envVars['MSSQL_SA_PASSWORD']))" -ForegroundColor White
Write-Host "  Redis:      localhost:30379 ($($envVars['REDIS_PASSWORD']))" -ForegroundColor White
Write-Host ""