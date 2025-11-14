<#
    GDAP-Data.ps1
    Version: 1.0.10
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

# ---------------------------------------------------------------------
# Retrieve GDAP relationships (SAFE PAGING + separate accessDetails)
# ---------------------------------------------------------------------
function Get-GdapRelationships {
    Write-GdapLog "Retrieving GDAP relationships..."

    $items = @()
    $url   = "https://graph.microsoft.com/beta/tenantRelationships/delegatedAdminRelationships"

    do {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $url
        if ($resp.value) { $items += $resp.value }
        $url = $resp.'@odata.nextLink'
    }
    while ($url)

    # Fetch accessDetails separately
    foreach ($rel in $items) {

        $id = $rel.id
        $detailsUrl = "https://graph.microsoft.com/beta/tenantRelationships/delegatedAdminRelationships/$id/accessDetails"

        try {
            $rel.accessDetails = Invoke-MgGraphRequest -Method GET -Uri $detailsUrl
        }
        catch {
            $rel.accessDetails = $null
        }
    }

    Write-GdapLog "Retrieved $($items.Count) GDAP relationships (with accessDetails)."

    return $items
}

# ---------------------------------------------------------------------
# Role Definitions
# ---------------------------------------------------------------------
function Get-GdapRoleDefinitionsMap {

    Write-GdapLog "Retrieving role definitions..."

    $url = "https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions?`$select=id,displayName"
    $resp = Invoke-MgGraphRequest -Method GET -Uri $url

    $map = @{}
    foreach ($role in $resp.value) { $map[$role.id] = $role.displayName }

    return $map
}

# ---------------------------------------------------------------------
# Unified Assignments Table
# ---------------------------------------------------------------------
function Get-GdapAccessAssignments {
    param(
        [array]$Relationships,
        [hashtable]$RoleMap
    )

    $output = @()

    foreach ($rel in $Relationships) {

        $details = $rel.accessDetails
        if (-not $details) { continue }

        foreach ($roleId in $details.unifiedRoles) {

            $output += [pscustomobject]@{
                CustomerId     = $rel.customerId
                RelationshipId = $rel.id
                DisplayName    = $rel.displayName
                StartDateTime  = $details.startDateTime
                EndDateTime    = $details.endDateTime
                RoleId         = $roleId
                RoleName       = $RoleMap[$roleId]
            }
        }
    }

    return $output
}
