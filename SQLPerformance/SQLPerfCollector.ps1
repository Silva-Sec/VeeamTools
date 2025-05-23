# SQL-Perf-Collector.ps1
Write-Host "`n=== PostgreSQL Performance Collector ===`n" -ForegroundColor Cyan

# CONFIGURATION
$pgBin               = "C:\Program Files\PostgreSQL\15\bin"
$pgData              = "C:\Program Files\PostgreSQL\15\data"
$psql                = Join-Path $pgBin "psql.exe"
$dbUser              = "postgres"
$dbName              = "VeeamBackup365"
$outputDir           = $pgBin
$postgresServiceName = "postgresql-x64-15"
$configFile          = Join-Path $pgData "postgresql.conf"

# Prompt user for phase
Write-Host "Choose an action:"
Write-Host "  1) Initialize (install extension, update config, restart)"
Write-Host "  2) Collect   (export CSVs without restarting)"
$mode = Read-Host "Enter 1 or 2"

function Check-Extension {
    Write-Host "→ Checking pg_stat_statements extension..."
    $query  = "SELECT extname FROM pg_extension WHERE extname = 'pg_stat_statements';"
    $result = & $psql -U $dbUser -d $dbName -t -c $query

    if ($result -match "pg_stat_statements") {
        Write-Host "  ✔ already installed." -ForegroundColor Green
        return $false
    }

    Write-Host "  ✖ Not installed. Creating extension…" -ForegroundColor Yellow
    & $psql -U $dbUser -d $dbName -c "CREATE EXTENSION pg_stat_statements;"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  Failed to create extension. Need superuser privileges?"
        exit 1
    }
    Write-Host "  ✔ Extension created." -ForegroundColor Green
    return $true
}

function Ensure-SharedPreload {
    Write-Host "→ Checking shared_preload_libraries…"
    $current = & $psql -U $dbUser -d $dbName -t -c "SHOW shared_preload_libraries;"

    if ($current -match "pg_stat_statements") {
        Write-Host "  ✔ already set." -ForegroundColor Green
        return $false
    }

    Write-Warning "  Applying shared_preload_libraries change…"

    # Stop service
    Write-Host "  • Stopping PostgreSQL service '$postgresServiceName'…"
    Stop-Service -Name $postgresServiceName -Force -ErrorAction Stop
    while ((Get-Service -Name $postgresServiceName).Status -ne 'Stopped') {
        Start-Sleep -Seconds 1
    }
    Write-Host "    ✔ Service stopped."

    # Backup and update config
    $timestamp  = Get-Date -Format yyyyMMddHHmmss
    $backupPath = "$configFile.bak_$timestamp"
    Copy-Item $configFile $backupPath -ErrorAction Stop
    Write-Host "    • Backed up config to: $backupPath"

    $lines = Get-Content $configFile

    # Uncomment any commented pg_stat_statements lines
    $lines = $lines -replace '^\s*#\s*(shared_preload_libraries\s*=.*pg_stat_statements.*)$', '$1'

    # Update existing or append new
    if (-not ($lines -match '^\s*shared_preload_libraries\s*=.*pg_stat_statements.*')) {
        $updated = $false
        $lines = $lines | ForEach-Object {
            if (-not $updated -and ($_ -match '^\s*shared_preload_libraries\s*=')) {
                $updated = $true
                "shared_preload_libraries = 'pg_stat_statements'"
            } else {
                $_
            }
        }
        if (-not $updated) {
            $lines += "`nshared_preload_libraries = 'pg_stat_statements'"
        }
    }

    $lines | Set-Content $configFile -ErrorAction Stop
    Write-Host "    ✔ postgresql.conf updated."

    # Start service
    Write-Host "  • Starting PostgreSQL service…"
    Start-Service -Name $postgresServiceName -ErrorAction Stop
    while ((Get-Service -Name $postgresServiceName).Status -ne 'Running') {
        Start-Sleep -Seconds 1
    }
    Write-Host "    ✔ Service running."

    # Verify
    $verify = & $psql -U $dbUser -d $dbName -t -c "SHOW shared_preload_libraries;"
    if ($verify -notmatch "pg_stat_statements") {
        Write-Error "  Failed to apply shared_preload_libraries. Please check config."
        exit 1
    }

    Write-Host "  ✔ shared_preload_libraries applied." -ForegroundColor Green
    return $true
}

function Export-Query {
    param (
        [string]$sql,
        [string]$filename
    )
    $filepath = Join-Path $outputDir $filename
    $cmd      = "\copy ($sql) TO '$filepath' WITH CSV HEADER"
    Write-Host "→ Exporting $filename…"
    & $psql -U $dbUser -d $dbName -c $cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  ✖ Failed to export $filename"
        return
    }
    Write-Host "  ✔ Done: $filename" -ForegroundColor Green
}

switch ($mode) {
    '1' {
        Write-Host "`n--- Phase 1: Initialize ---`n" -ForegroundColor Cyan
        $didExt    = Check-Extension
        $didConfig = Ensure-SharedPreload

        if ($didExt -or $didConfig) {
            Write-Host "`nInitialization complete. PostgreSQL was restarted and stats reset."
            Write-Host "Let your workload run so pg_stat_statements can gather data."
        }
        else {
            Write-Host "Nothing to do; everything is already initialized." -ForegroundColor Cyan
        }
        break
    }
    '2' {
        Write-Host "`n--- Phase 2: Collect ---`n" -ForegroundColor Cyan

        # ask how many rows to return
        $limitInput = Read-Host "Enter number of rows to export (default 20)"
        if ([string]::IsNullOrWhiteSpace($limitInput)) {
            $limit = 20
        }
        elseif ($limitInput -match '^\d+$') {
            $limit = [int]$limitInput
        }
        else {
            Write-Warning "Invalid input; using default 20"
            $limit = 20
        }
        Write-Host "Using LIMIT $limit`n" -ForegroundColor Cyan

        # Exports with dynamic LIMIT
        Export-Query @"
SELECT substr(query,1,120) AS queries,
       SUM(shared_blks_hit + shared_blks_dirtied) AS total_lio,
       SUM(round((total_exec_time::numeric/1000),0)) AS totaltime_in_seconds,
       SUM(round((mean_exec_time::numeric/1000),2)) AS meantime_in_seconds,
       SUM(calls) AS total_calls
FROM pg_stat_statements
WHERE query NOT LIKE '%DISCARD ALL%'
GROUP BY queries
ORDER BY totaltime_in_seconds DESC
LIMIT $limit
"@ "query_total_time$limit.csv"

        Export-Query @"
SELECT substr(query,1,120) AS queries,
       SUM(shared_blks_hit + shared_blks_dirtied) AS total_lio,
       SUM(round((total_exec_time::numeric/1000),0)) AS totaltime_in_seconds,
       SUM(round((mean_exec_time::numeric/1000),2)) AS meantime_in_seconds,
       SUM(calls) AS total_calls
FROM pg_stat_statements
WHERE query NOT LIKE '%DISCARD ALL%'
GROUP BY queries
ORDER BY total_calls DESC
LIMIT $limit
"@ "query_most_called$limit.csv"

        Export-Query @"
SELECT substr(query,1,120),
       round(total_exec_time::numeric/1000,2) AS totaltime_in_sec,
       round(mean_exec_time::numeric/1000,4) AS meantime_in_sec,
       round(max_exec_time::numeric/1000,4) AS maxtime_in_sec,
       calls,
       round((shared_blks_hit + shared_blks_dirtied)::numeric / calls, 2) AS total_lio_per_execution
FROM pg_stat_statements
WHERE query NOT LIKE '%DISCARD ALL%'
ORDER BY max_exec_time DESC
LIMIT $limit
"@ "query_max_time$limit.csv"

        Export-Query @"
SELECT (now() - xact_start) AS transactiontime,
       query,
       wait_event
FROM pg_stat_activity
WHERE state IN ('active', 'idle in transaction')
ORDER BY transactiontime DESC NULLS LAST
LIMIT $limit
"@ "long_transactions$limit.csv"

        Export-Query @"
SELECT count(*) AS count,
       state,
       wait_event
FROM pg_stat_activity
GROUP BY state, wait_event
ORDER BY count DESC
LIMIT $limit
"@ "connection_states$limit.csv"

        Write-Host "`n✅ All exports completed. CSVs saved to: $outputDir" -ForegroundColor Cyan
        break
    }
    default {
        Write-Error "Invalid choice. Please run the script again and enter 1 or 2."
        exit 1
    }
}