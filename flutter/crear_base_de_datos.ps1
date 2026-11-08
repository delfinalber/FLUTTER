# Crea la base de datos PostgreSQL "pizza_julian" con todas las tablas y datos iniciales.
# Uso (PowerShell, desde D:\FLUTTER\flutter):   .\crear_base_de_datos.ps1
# Pide la contraseña del usuario postgres que se definió al instalar PostgreSQL.

$psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
if (-not (Test-Path $psql)) {
    $psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
}
if (-not $psql) {
    Write-Host "No se encontró psql.exe. Instale PostgreSQL o ajuste la ruta en este script." -ForegroundColor Red
    exit 1
}

$script = Join-Path $PSScriptRoot "base_de_datos\pizza_julian_postgres.sql"

$existe = & $psql -U postgres -h localhost -tAc "SELECT 1 FROM pg_database WHERE datname = 'pizza_julian'"
if ($existe -ne "1") {
    & $psql -U postgres -h localhost -c "CREATE DATABASE pizza_julian ENCODING 'UTF8' TEMPLATE template0;"
}
& $psql -U postgres -h localhost -d pizza_julian -v ON_ERROR_STOP=1 -f $script
if ($LASTEXITCODE -eq 0) {
    Write-Host "Base de datos pizza_julian lista." -ForegroundColor Green
}
