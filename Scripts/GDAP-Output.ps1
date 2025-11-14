<#
    GDAP-Output.ps1
    Version: 1.0.7
#>

function Write-GdapLog {
    param([string]$Message, [string]$Level = "INFO")

    if (-not $ScriptDir) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $LogsDir = Join-Path $ScriptDir "Logs"
    if (!(Test-Path $LogsDir)) { New-Item -Path $LogsDir -ItemType Directory | Out-Null }

    $logFile = Join-Path $LogsDir "gdaplog-$(Get-Date -Format yyyyMMdd).txt"
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    "$timestamp [$Level] $Message" | Out-File -Append -FilePath $logFile
}

function Get-GdapSummaryTable {
    param([Parameter(Mandatory)][array]$Relationships)

    if (-not $Relationships -or $Relationships.Count -eq 0) {
        return [pscustomobject]@{ Active = 0; Expired = 0; ExpiringSoon = 0 }
    }

    $now = Get-Date

    foreach ($rel in $Relationships) {

        # Determine expiration location
        $end = $null

        if ($rel.PSObject.Properties["endDateTime"]) {
            $end = $rel.endDateTime
        }
        elseif ($rel.relationship -and $rel.relationship.PSObject.Properties["endDateTime"]) {
            $end = $rel.relationship.endDateTime
        }
        elseif ($rel.accessDetails -and $rel.accessDetails.PSObject.Properties["endDateTime"]) {
            $end = $rel.accessDetails.endDateTime
        }

        # No valid expiration
        if ([string]::IsNullOrWhiteSpace($end)) {
            $rel | Add-Member -NotePropertyName "DaysRemaining" -NotePropertyValue -99999 -Force
            $rel | Add-Member -NotePropertyName "ExpiringSoon"  -NotePropertyValue $false -Force
            $rel | Add-Member -NotePropertyName "IsExpired"     -NotePropertyValue $true -Force
            $rel | Add-Member -NotePropertyName "IsActive"      -NotePropertyValue $false -Force
            continue
        }

        # Convert to datetime
        try { $endDt = [datetime]$end }
        catch {
            $rel | Add-Member -NotePropertyName "DaysRemaining" -NotePropertyValue -99999 -Force
            $rel | Add-Member -NotePropertyName "ExpiringSoon"  -NotePropertyValue $false -Force
            $rel | Add-Member -NotePropertyName "IsExpired"     -NotePropertyValue $true -Force
            $rel | Add-Member -NotePropertyName "IsActive"      -NotePropertyValue $false -Force
            continue
        }

        $days = [int]($endDt - $now).TotalDays

        $rel | Add-Member -NotePropertyName "DaysRemaining" -NotePropertyValue $days -Force
        $rel | Add-Member -NotePropertyName "ExpiringSoon"  -NotePropertyValue ($days -le 30 -and $days -gt 0) -Force
        $rel | Add-Member -NotePropertyName "IsExpired"     -NotePropertyValue ($days -le 0) -Force
        $rel | Add-Member -NotePropertyName "IsActive"      -NotePropertyValue ($days -gt 0) -Force
    }

    return [pscustomobject]@{
        Active       = ($Relationships | Where-Object IsActive).Count
        Expired      = ($Relationships | Where-Object IsExpired).Count
        ExpiringSoon = ($Relationships | Where-Object ExpiringSoon).Count
    }
}

function Export-GdapCsv {
    param([array]$Data, [string]$Path)
    Write-GdapLog "Exporting CSV → $Path"
    $Data | Export-Csv -NoTypeInformation -Path $Path
}

function Export-GdapJson {
    param([array]$Data, [string]$Path)
    Write-GdapLog "Exporting JSON → $Path"
    $Data | ConvertTo-Json -Depth 5 | Out-File $Path
}

function Export-GdapHtml {
    param([array]$Data, [string]$Path)
    Write-GdapLog "Exporting HTML → $Path"
    $Data | ConvertTo-Html -PreContent "<h1>GDAP Export Report</h1>" | Out-File $Path
}

function Export-GdapExcel {
    param([array]$Data, [string]$Path)
    Write-GdapLog "Exporting Excel → $Path"
    $Data | Export-Excel -Path $Path -AutoSize -BoldTopRow
}

function Write-GdapExports {
    param([array]$Data, [string]$OutputFolder, [string[]]$Formats)

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
