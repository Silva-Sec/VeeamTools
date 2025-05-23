# PostgreSQL Performance Collector

A PowerShell utility to enable and collect query performance statistics from PostgreSQL using the `pg_stat_statements` extension. This script supports Windows-based PostgreSQL installations.

## Features

- Automatically checks and installs `pg_stat_statements` extension (if missing)
- Configures `shared_preload_libraries` in `postgresql.conf`
- Restarts PostgreSQL when needed
- Exports key performance metrics to CSV using customizable query limits
- Supports two-phase workflow: **Initialize** and **Collect**

---

## Prerequisites

- Windows with PowerShell 5+
- PostgreSQL installed locally
- Superuser access to the PostgreSQL instance
- Script paths and service name adjusted in configuration section

---

## Usage

### Step 1: Run the Script

```powershell
.\SQL-Perf-Collector.ps1

Step 2: Choose an Option When Prompted

=== PostgreSQL Performance Collector ===

Choose an action:
  1) Initialize (install extension, update config, restart)
  2) Collect   (export CSVs without restarting)
Enter 1 or 2:


Phase 1: Initialize
Installs pg_stat_statements (if not present)

Updates or uncomments the shared_preload_libraries line in postgresql.conf

Restarts the PostgreSQL service

Note: This clears pg_stat_statements history – wait until your workload generates queries before collecting


Phase 2: Collect
Exports the following CSV reports:

query_total_time.csv: Top queries by total execution time

query_most_called.csv: Most frequently executed queries

query_max_time.csv: Queries with highest execution time

long_transactions.csv: Active or idle-in-transaction queries

connection_states.csv: State and wait event breakdown

You will be asked how many rows to export (LIMIT). Press Enter for the default (20), or enter any custom number.


Configuration
Edit these lines in the script to match your system if necessary:

$pgBin               = "C:\Program Files\PostgreSQL\15\bin"
$pgData              = "C:\Program Files\PostgreSQL\15\data"
$dbUser              = "postgres"
$dbName              = "VeeamBackup365"
$outputDir           = $pgBin
$postgresServiceName = "postgresql-x64-15"
