# Sets up the Sonder database on a locally installed PostgreSQL (Windows).
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File backend\scripts\setup_db.ps1
param(
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$Superuser = "postgres",
    [string]$DbName = "sonder",
    [string]$DbUser = "sonder",
    [string]$DbPassword = "sonder",
    [switch]$NoSeed
)
$ErrorActionPreference = "Stop"

$psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $psql) {
    $found = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
        Sort-Object { [int]$_.Directory.Parent.Name } -Descending | Select-Object -First 1
    if (-not $found) { throw "psql.exe not found. Install PostgreSQL from https://www.postgresql.org/download/windows/ first." }
    $psql = $found.FullName
}

$backendDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$dbDir = Join-Path $backendDir "db"

if ($env:PG_SUPERUSER_PASSWORD) {
    $superPassword = $env:PG_SUPERUSER_PASSWORD
} else {
    $secure = Read-Host "Password for PostgreSQL superuser '$Superuser' (set when PostgreSQL was installed)" -AsSecureString
    $superPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

try {
    Write-Host "1/3 Creating role '$DbUser' and database '$DbName'..."
    $env:PGPASSWORD = $superPassword
    & $psql -h $PgHost -p $Port -U $Superuser -d postgres -v ON_ERROR_STOP=1 -q `
        -v "dbname=$DbName" -v "dbuser=$DbUser" -v "dbpass=$DbPassword" `
        -f (Join-Path $PSScriptRoot "create_role_and_database.sql")
    if ($LASTEXITCODE -ne 0) { throw "Could not create role/database (wrong superuser password?)" }

    $env:PGPASSWORD = $DbPassword
    $exists = & $psql -h $PgHost -p $Port -U $DbUser -d $DbName -tAc "SELECT to_regclass('public.users') IS NOT NULL"
    if ($LASTEXITCODE -ne 0) { throw "Could not connect as '$DbUser'" }

    if ($exists.Trim() -eq "t") {
        Write-Host "2/3 Tables already exist - skipping schema and demo data."
    } else {
        Write-Host "2/3 Creating tables..."
        & $psql -h $PgHost -p $Port -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -q -f (Join-Path $dbDir "01_schema.sql")
        if ($LASTEXITCODE -ne 0) { throw "Schema creation failed" }
        if (-not $NoSeed) {
            Write-Host "    Loading demo data..."
            & $psql -h $PgHost -p $Port -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -q -f (Join-Path $dbDir "02_seed.sql")
            if ($LASTEXITCODE -ne 0) { throw "Loading demo data failed" }
        }
    }

    $envFile = Join-Path $backendDir ".env"
    if (Test-Path $envFile) {
        Write-Host "3/3 backend\.env already exists - leaving it unchanged."
    } else {
        Write-Host "3/3 Writing backend\.env..."
        $jwtSecret = ([guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N"))
        @(
            "DATABASE_URL=postgresql://${DbUser}:${DbPassword}@${PgHost}:${Port}/${DbName}",
            "JWT_SECRET=$jwtSecret",
            "JWT_EXPIRES_MINUTES=10080",
            "CORS_ORIGINS=*",
            "PORT=8000"
        ) | Set-Content -Path $envFile -Encoding ascii
    }

    Write-Host ""
    Write-Host "Database ready: postgresql://${DbUser}@${PgHost}:${Port}/${DbName}" -ForegroundColor Green
} finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
