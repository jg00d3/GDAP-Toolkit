function Get-GdapSummaryTable {
    param(
        [Parameter(Mandatory)]
        [array]$Relationships
    )

    if (-not $Relationships -or $Relationships.Count -eq 0) {
        return [pscustomobject]@{
            Active         = 0
            Expired        = 0
            ExpiringSoon   = 0
        }
    }

    # Calculate date-based properties
    $now = Get-Date

    foreach ($rel in $Relationships) {
        # Ensure expiration is treated as DateTime
        if ($rel.endDateTime -is [string]) {
            $rel.endDateTime = [datetime]$rel.endDateTime
        }

        $rel | Add-Member -NotePropertyName DaysRemaining `
            -NotePropertyValue ([int]([datetime]$rel.endDateTime - $now).TotalDays) `
            -Force

        $rel | Add-Member -NotePropertyName ExpiringSoon `
            -NotePropertyValue ($rel.DaysRemaining -le 30 -and $rel.DaysRemaining -gt 0) `
            -Force

        $rel | Add-Member -NotePropertyName IsExpired `
            -NotePropertyValue ($rel.DaysRemaining -le 0) `
            -Force

        $rel | Add-Member -NotePropertyName IsActive `
            -NotePropertyValue ($rel.DaysRemaining -gt 0) `
            -Force
    }

    # Build summary
    $activeCount   = ($Relationships | Where-Object { $_.IsActive }).Count
    $expiredCount  = ($Relationships | Where-Object { $_.IsExpired }).Count
    $soonCount     = ($Relationships | Where-Object { $_.ExpiringSoon }).Count

    return [pscustomobject]@{
        Active         = $activeCount
        Expired        = $expiredCount
        ExpiringSoon   = $soonCount
    }
}
