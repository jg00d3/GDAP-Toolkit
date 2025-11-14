<#
    GDAP-Data.ps1
    Version: 1.0.9
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

# -------------------------------------------------------
# Retrieve base GDAP relationships
# -------------------------------------------------------
function Get-GdapRelationships {
    Write-GdapLog "Retrieving GDAP relationships…"

    $url = "https://graph.microsoft.com/beta/tenantRelationships/delegatedAdminRelationships"

    $results = Invoke-MgGraphRequest -Method GET -Uri $url
    $items = $results.value

    while ($results.'@odata.nextLink') {
        $results = Invoke-MgGraphRequest -Method GET -Uri $results.'@odata.nextLink'
        $items += $results.value
    }

    # Retrieve accessDetails for each relationship
    foreach ($rel in $items) {
        $relId = $rel.id
        $detailsUrl = "https://graph.microsoft.com/beta/tenantRelationships/delegatedAdminRelationships/$relId/accessDetails"

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

# -------------------------------------------------------
# Role Definitions Map
# -------------------------------------------------------
function Get-GdapRoleDefinitionsMap {
    Write-GdapLog "Retrieving role definitions…"

    $url = "https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions?`$select=id,displayName"

    $results = Invoke-MgGraphRequest -Method GET -Uri $url

    $map = @{}
    foreach ($role in $results.value) {
        $map[$role.id] = $role.displayName
    }

    return $map
}

# -------------------------------------------------------
# Unified Assignments Table
# -------------------------------------------------------
function Get-GdapAccessAssignments {
    param(
        [array]$Relationships,
        [hashtable]$RoleMap
    )

    $output = @()

    foreach ($rel in $Relationships) {

        $customerId     = $rel.customerId
        $relationshipId = $rel.id
        $displayName    = $rel.displayName

        $details = $rel.accessDetails
        if (-not $details) { continue }

        $start = $details.startDateTime
        $end   = $details.endDateTime

        foreach ($roleId in $details.unifiedRoles) {
            $output += [pscustomobject]@{
                CustomerId     = $customerId
                RelationshipId = $relationshipId
                DisplayName    = $displayName
                StartDateTime  = $start
                EndDateTime    = $end
                RoleId         = $roleId
                RoleName       = $RoleMap[$roleId]
            }
        }
    }

    return $output
}
