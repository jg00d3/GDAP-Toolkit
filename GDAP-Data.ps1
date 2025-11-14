<#
    GDAP-Data.ps1
    Stable data retriever for GDAP Toolkit
    Pulls only the objects that are KNOWN TO WORK:
       ✔ DelegatedAdminRelationship
       ✔ All customer metadata
       ✔ ActivatedDateTime / EndDateTime
       ✔ Duration / AutoExtendDuration
       ✔ Status
    This version does NOT attempt to retrieve:
       ✘ accessAssignments
       ✘ accessDetails
       ✘ unifiedRoles
    Those API endpoints are unstable in Graph Beta.
    Author: ChatGPT
    Version: 1.0.0
#>

# ------------------------------------------------------------
# Load utilities + graph helper
# ------------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\GDAP-Utils.ps1"
. "$scriptRoot\GDAP-Graph.ps1"

# ------------------------------------------------------------
# Convert Graph epoch-millisecond date → DateTime
# ------------------------------------------------------------
function Convert-GraphDate {
    param($Value)

    if (-not $Value) { return $null }

    $s = $Value.ToString()

    if ($s -match '\d{10,}') {
        try {
            $ms = [int64]($s -replace '[^\d-]')
            $epoch = [DateTime]'1970-01-01T00:00:00Z'
            return $epoch.AddMilliseconds($ms).ToLocalTime()
        } catch { return $null }
    }

    try { return [datetime]$Value }
    catch { return $null }
}

# ------------------------------------------------------------
# Retrieve ALL GDAP relationships
# ------------------------------------------------------------
function Get-GdapRelationships {
    Write-Log "Retrieving GDAP relationships…" Cyan

    try {
        # Use -All → avoids pagination issues
        $list = Get-MgBetaTenantRelationshipDelegatedAdminRelationship -All -ErrorAction Stop
    }
    catch {
        Write-Log "ERROR retrieving GDAP relationships: $($_.Exception.Message)" Red
        return @()
    }

    if (-not $list -or $list.Count -eq 0) {
        Write-Log "No GDAP relationships returned." Yellow
        return @()
    }

    Write-Log "Retrieved $($list.Count) GDAP relationships." Green
    return $list
}

# ------------------------------------------------------------
# Transform raw relationship objects → clean table rows
# ------------------------------------------------------------
function Build-GdapSummaryTable {
    param([array]$Relationships)

    Write-Log "Building summary table…" Cyan
    $now = Get-Date

    $rows = foreach ($r in $Relationships) {

        $activated = Convert-GraphDate $r.ActivatedDateTime
        $expires   = Convert-GraphDate $r.EndDateTime

        $daysRemaining = $null
        $expiringSoon  = $false

        if ($expires) {
            $daysRemaining = [math]::Floor(($expires - $now).TotalDays)
            if ($daysRemaining -ge 0 -and $daysRemaining -le 30 -and $r.Status -eq 'active') {
                $expiringSoon = $true
            }
        }

        [pscustomobject]@{
            CustomerDisplayName = $r.Customer.DisplayName
            CustomerTenantId    = $r.Customer.TenantId
            DisplayName         = $r.DisplayName
            Status              = $r.Status
            Activated           = $activated
            Expires             = $expires
            DurationDays        = $r.Duration.TotalDays
            AutoRenewDays       = $r.AutoExtendDuration.TotalDays
            DaysRemaining       = $daysRemaining
            ExpiringSoon        = $expiringSoon
        }
    }

    Write-Log "Summary table complete: $($rows.Count) rows." Green
    return $rows
}

# ------------------------------------------------------------
# Identify tenants with multiple active GDAP relationships
# ------------------------------------------------------------
function Get-GdapDuplicateActiveTenants {
    param([array]$SummaryTable)

    Write-Log "Detecting tenants with multiple active GDAP relationships…" Cyan

    $dups = $SummaryTable |
        Where-Object Status -eq 'active' |
        Group-Object CustomerTenantId |
        Where-Object Count -gt 1 |
        Select-Object -ExpandProperty Name

    Write-Log "Found $($dups.Count) tenants with multiple actives." Green
    return $dups
}

# END OF FILE
