<#
    GDAP-Export.ps1
    Master script for the GDAP Toolkit

    Performs:
       ✔ Loads helpers, graph, data, output modules
       ✔ Connects to Microsoft Graph
       ✔ Retrieves GDAP relationships
       ✔ Calculates summary fields (DaysRemaining, ExpiringSoon, etc.)
       ✔ Prompts for filters
       ✔ Exports CSV / JSON / HTML / XLSX / Screen

    Author: ChatGPT
    Version: 1.0.8
#>

# ---------------------------------------------------------
# Load all GDAP modules
# ---------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$scriptRoot\GDAP-Utils.ps1"
. "$scriptRoot\GDAP-Graph.ps1"
. "$scriptRoot\GDAP-Data.ps1"
. "$scriptRoot\GDAP-Output.ps1"

Write-Log "GDAP modules loaded." Cyan

# ---------------------------------------------------------
# Connect to Microsoft Graph (GUI login if needed)
# ---------------------------------------------------------
Ensure-GdapGraphConnection -Scopes @(
    "Directory.Read.All",
    "DelegatedAdminRelationship.Read.All"
)

# ---------------------------------------------------------
# Retrieve raw relationships
# ---------------------------------------------------------
Write-Log "Retrieving GDAP relationships..." Green

$allRelationships = Get-GdapRelationships

if (-not $allRelationships -or $allRelationships.Count -eq 0) {
    Write-Log "No GDAP relationships found." Yellow
    exit
}

# ---------------------------------------------------------
# Build summary table (stable + safe)
# ---------------------------------------------------------
Write-Log "Building summary dataset..." Green

$summary = Get-GdapSummaryTable -Relationships $allRelationships

$activeCount = ($summary | Where-Object Status -eq 'active').Count
$expiredCount = ($summary | Where-Object Status -eq 'expired').Count
$soonCount = ($summary | Where-Object ExpiringSoon -eq $true).Count

Write-Log "Summary:" Yellow
Write-Log "Active    : $activeCount" Cyan
Write-Log "Expired   : $expiredCount" Cyan
Write-Log "Expiring ≤30 days: $soonCount" Cyan

# ---------------------------------------------------------
# User prompts
# ---------------------------------------------------------

# Status filter
Write-Log "`nChoose GDAP status to export:" Cyan
Write-Host "1 = Active Only"
Write-Host "2 = Expired Only"
Write-Host "3 = Both"
$statusChoice = Read-Host "Enter 1–3 (default = 1)"
if ($statusChoice -notmatch '^[1-3]$') { $statusChoice = 1 }

switch ($statusChoice) {
    1 { $filtered = $summary | Where-Object Status -eq 'active' }
    2 { $filtered = $summary | Where-Object Status -eq 'expired' }
    3 { $filtered = $summary }
}

if (-not $filtered -or $filtered.Count -eq 0) {
    Write-Log "No GDAP entries match your filter." Yellow
    exit
}

# Output folder
$defaultFolder = "C:\Scripts\Export"
Write-Log "`nEnter output folder or press Enter to use default [$defaultFolder]" Cyan
$folderInput = Read-Host
$folder = if ([string]::IsNullOrWhiteSpace($folderInput)) { $defaultFolder } else { $folderInput }

if (-not (Test-Path $folder)) {
    New-Item -Path $folder -ItemType Directory | Out-Null
}

# Output format
Write-Log "`nChoose output format:" Cyan
Write-Host "1 = Screen only"
Write-Host "2 = CSV"
Write-Host "3 = JSON"
Write-Host "4 = HTML"
Write-Host "5 = Excel (.xlsx)"
Write-Host "6 = ALL formats"
$outChoice = Read-Host "Enter 1–6 (default = 6)"
if ($outChoice -notmatch '^[1-6]$') { $outChoice = 6 }

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

switch ($outChoice) {
    1 { $formats = @("SCREEN") }
    2 { $formats = @("CSV") }
    3 { $formats = @("JSON") }
    4 { $formats = @("HTML") }
    5 { $formats = @("XLSX") }
    6 { $formats = @("CSV","JSON","HTML","XLSX","SCREEN") }
}

# ---------------------------------------------------------
# Perform export
# ---------------------------------------------------------
Write-GdapOutput `
    -Data $filtered `
    -Folder $folder `
    -Formats $formats `
    -Timestamp $timestamp

Write-Log "`nGDAP Export Complete." Green
