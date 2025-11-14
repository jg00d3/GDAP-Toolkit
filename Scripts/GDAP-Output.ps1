<#
    GDAP-Output.ps1
    Handles all export formatting:
       ✔ CSV
       ✔ JSON
       ✔ HTML
       ✔ Excel (.xlsx)
       ✔ Screen output
    Uses only summary-level GDAP data (safe & stable)
    Author: ChatGPT
    Version: 1.0.0
#>

# ---------------------------------------------------------
# Load utilities
# ---------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\GDAP-Utils.ps1"

# ---------------------------------------------------------
# Export: CSV
# ---------------------------------------------------------
function Write-GdapCsv {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][array]$Data
    )

    try {
        $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        Write-Log "CSV exported → $Path" Green
    }
    catch {
        Write-Log "ERROR exporting CSV: $($_.Exception.Message)" Red
    }
}

# ---------------------------------------------------------
# Export: JSON
# ---------------------------------------------------------
function Write-GdapJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][array]$Data
    )

    try {
        $Data | ConvertTo-Json -Depth 6 | Out-File -FilePath $Path -Encoding UTF8
        Write-Log "JSON exported → $Path" Green
    }
    catch {
        Write-Log "ERROR exporting JSON: $($_.Exception.Message)" Red
    }
}

# ---------------------------------------------------------
# Export: HTML
# ---------------------------------------------------------
function Write-GdapHtml {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][array]$Data
    )

    try {
        $html = $Data | ConvertTo-Html -Title "GDAP Report" -PreContent "<h2>GDAP Export Report</h2>"
        $html | Out-File $Path -Encoding UTF8
        Write-Log "HTML exported → $Path" Green
    }
    catch {
        Write-Log "ERROR exporting HTML: $($_.Exception.Message)" Red
    }
}

# ---------------------------------------------------------
# Export: Excel (.xlsx)
# ---------------------------------------------------------
function Write-GdapExcel {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][array]$Data
    )

    try {
        $sheet = "GDAP"
        $Data | Export-Excel -Path $Path `
                              -WorksheetName $sheet `
                              -AutoSize `
                              -BoldTopRow `
                              -FreezeTopRow `
                              -AutoFilter
        Write-Log "Excel exported → $Path" Green
    }
    catch {
        Write-Log "ERROR exporting Excel: $($_.Exception.Message)" Red
    }
}

# ---------------------------------------------------------
# Pretty table output
# ---------------------------------------------------------
function Show-GdapTable {
    param(
        [Parameter(Mandatory)][array]$Data
    )

    Write-Log "Displaying table…" Cyan
    $Data | Format-Table -AutoSize
}

# ---------------------------------------------------------
# MASTER OUTPUT DISPATCHER
# ---------------------------------------------------------
function Write-GdapOutput {
    <#
        Master function used by GDAP-Export.ps1

        Parameters:
           Data       → summary table
           Folder     → export path
           Formats    → array: CSV,JSON,HTML,XLSX,Screen
           Timestamp  → filename stamp (yyyyMMdd_HHmmss)
    #>

    param(
        [Parameter(Mandatory)][array]$Data,
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string[]]$Formats,
        [Parameter(Mandatory)][string]$Timestamp
    )

    if (-not (Test-Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder | Out-Null
    }

    # Build file paths
    $csvPath  = Join-Path $Folder "GDAP_$Timestamp.csv"
    $jsonPath = Join-Path $Folder "GDAP_$Timestamp.json"
    $htmlPath = Join-Path $Folder "GDAP_$Timestamp.html"
    $xlsxPath = Join-Path $Folder "GDAP_$Timestamp.xlsx"

    foreach ($fmt in $Formats) {
        switch ($fmt.ToUpper()) {

            'CSV'    { Write-GdapCsv  -Path $csvPath  -Data $Data }
            'JSON'   { Write-GdapJson -Path $jsonPath -Data $Data }
            'HTML'   { Write-GdapHtml -Path $htmlPath -Data $Data }
            'XLSX'   { Write-GdapExcel -Path $xlsxPath -Data $Data }
            'SCREEN' { Show-GdapTable -Data $Data }

            default  { Write-Log "Unknown output format: $fmt" Yellow }
        }
    }

    Write-Log "Output completed." Green
}

# END OF FILE
