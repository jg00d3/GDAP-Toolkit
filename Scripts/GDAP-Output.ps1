<#
    GDAP-Output.ps1
    Provides all export-building and summary functions
    Version: 1.0.4
#>

# -------------------------------------------------------
# Logging (shared with other modules)
# -------------------------------------------------------
function Write-GdapLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    if (-not $ScriptDir) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $LogsDir = Join-Path $ScriptDir "Logs"
    if (!(Test-Path $LogsDir)) { New-Item -Path $LogsDir -ItemType Directory | Out-Null }

    $logFile = Join-Path $LogsDir "gdaplog-$(Get-Date -Format yyyyMMdd).txt"
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    "$timestamp [$Level] $Message" | Out-File -Append -FilePath $logFile
}

# -------------------------------------------------------
# SAFELY BUILD SUMMARY TABLE
# -------------------------------------------------------
function Get-GdapSummaryTable {
    param(
        [Parameter(Mandatory)]
        [array]$Relationships
    )

    if (-not $Relationships -or $Relationships.Count -eq 0) {
        return [pscustomobject]@{
            Active       = 0
            Expired      = 0
            ExpiringSoon = 0
        }
    }

    $now = Get-Date

    foreach ($rel in $Relationships) {

        #
        # Handle NULL expiration date (Graph returns this for pending/unaccepted GDAP)
        #
        if ([string]::IsNullOrWhiteSpace($rel.endDateTime)) {

            # Treat unknown expiration as expired (safe default)
            $rel | Add-Member -NotePropertyName DaysRemaining -NotePropertyValue -99999 -Force
            $rel | Add-Member -NotePropertyName ExpiringSoon -NotePropertyValue $false -Force
            $rel | Add-Member -NotePropertyName IsExpired -NotePropertyValue $true -Force
            $rel | Add-Member -NotePropertyName IsActive -NotePropertyValue $false -Force
            continue
        }

        #
        # Normalize date and calculate days remaining
        #
        try {
            $end = [datetime]$rel.endDateTime
        }
        catch {
            # if Microsoft ever returns invalid date junk, fail gracefully
            $rel | Add-Member -NotePropertyName DaysRemaining -NotePropertyValue -99999 -Force
            $rel | Add-Member -NotePropertyName ExpiringSoon -NotePropertyValue $false -Force
            $rel | Add-Member -NotePropertyName IsExpired -NotePropertyValue $true -Force
            $rel | Add-Member -NotePropertyName IsActive -NotePropertyValue $false -Force
            continue
        }

        $days = [int]($end - $now).TotalDays

        $rel | Add-Member -NotePropertyName DaysRemaining -NotePropertyValue $days -Force
        $rel | Add-Member -NotePropertyName ExpiringSoon -NotePropertyValue ($days -le 30 -and $days -gt 0) -Force
        $rel | Add-Member -NotePropertyName IsExpired -NotePropertyValue ($days -le 0) -Force
        $rel | Add-Member -NotePropertyName IsActive -NotePropertyValue ($days -gt 0) -Force
    }

    # Build summary object
    return [pscustomobject]@{
        Active       = ($Relationships | Where-Object { $_.IsActive }).Count
        Expired      = ($Relationships | Where-Object { $_.IsExpired }).Count
        ExpiringSoon = ($Relationships | Where-Object { $_.ExpiringSoon }).Count
    }
}

# -------------------------------------------------------
# Export helpers (CSV/JSON/HTML/Excel)
# -------------------------------------------------------
function Export-GdapCsv {
    param(
        [array]$Data,
        [string]$Path
    )
    Write-GdapLog "Exporting CSV → $Path"
    $Data | Export-Csv -NoTypeInformation -Path $Path
}

function Export-GdapJson {
    param(
        [array]$Data,
        [string]$Path
    )
    Write-GdapLog "Exporting JSON → $Path"
    $Data | ConvertTo-Json -Depth 5 | Out-File $Path
}

function Export-GdapHtml {
    param(
        [array]$Data,
        [string]$Path
    )
    Write-GdapLog "Exporting HTML → $Path"
    $Data | ConvertTo-Html -PreContent "<h1>GDAP Export Report</h1>" | Out-File $Path
}

function Export-GdapExcel {
    param(
        [array]$Data,
        [string]$Path
    )
    Write-GdapLog "Exporting Excel → $Path"
    $Data | Export-Excel -Path $Path -AutoSize -BoldTopRow
}

# -------------------------------------------------------
# Build full export file set
# -------------------------------------------------------
function Write-GdapExports {
    param(
        [array]$Data,
        [string]$OutputFolder,
        [string[]]$Formats
    )

    if (!(Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    if ("csv" -in $Formats) {
        Export-GdapCsv -Data $Data -Path (Join-Path $OutputFolder "gdap-export.csv")
    }

    if ("json" -in $Formats) {
        Export-GdapJson -Data $Data -Path (Join-Path $OutputFolder "gdap-export.json")
    }

    if ("html" -in $Formats) {
        Export-GdapHtml -Data $Data -Path (Join-Path $OutputFolder "gdap-export.html")
    }

    if ("xlsx" -in $Formats) {
        Export-GdapExcel -Data $Data -Path (Join-Path $OutputFolder "gdap-export.xlsx")
    }
}
