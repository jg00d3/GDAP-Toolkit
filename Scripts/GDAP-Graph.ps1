<#
    GDAP-Graph.ps1
    Handles Microsoft Graph authentication
    Author: ChatGPT
    Version: 1.0.8
#>

# --------------------------------------------------------------------
# Load utilities (Write-Color / Write-Log)
# --------------------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\GDAP-Utils.ps1"

# --------------------------------------------------------------------
# Validate Graph session
# --------------------------------------------------------------------
function Test-GdapGraphConnection {
    Write-Log "Checking existing Microsoft Graph connection…" Cyan

    try {
        $ctx = Get-MgContext
    }
    catch {
        Write-Log "Graph context not available." Yellow
        return $false
    }

    if (-not $ctx) {
        Write-Log "No Graph context found." Yellow
        return $false
    }

    if ($ctx -and $ctx.Account -and $ctx.Scopes.Count -gt 0) {
        Write-Log "Connected as '$($ctx.Account)' with scopes: $($ctx.Scopes -join ', ')" Green
        return $true
    }

    Write-Log "Graph context exists but is missing account or scopes." Yellow
    return $false
}

# --------------------------------------------------------------------
# Connect to Microsoft Graph with scopes
# --------------------------------------------------------------------
function Connect-GdapGraph {
    param(
        [string[]]$Scopes
    )

    Write-Log "Connecting to Microsoft Graph…" Cyan
    Write-Log "Scopes requested: $($Scopes -join ', ')" Cyan

    try {
        Connect-MgGraph -Scopes $Scopes -ErrorAction Stop
        Write-Log "Successfully authenticated to Microsoft Graph." Green
        return $true
    }
    catch {
        Write-Color "Failed to connect to Microsoft Graph: $($_.Exception.Message)" Red
        return $false
    }
}

# --------------------------------------------------------------------
# Ensure connection (reuse or reconnect)
# --------------------------------------------------------------------
function Ensure-GdapGraphConnection {
    param(
        [string[]]$Scopes
    )

    # 1 — Reuse existing Graph session
    if (Test-GdapGraphConnection) {
        Write-Log "Using existing Microsoft Graph connection." Green
        return
    }

    # 2 — Existing session invalid → reconnect
    Write-Log "No valid Graph session found. Connecting to Microsoft Graph…" Yellow

    if (-not (Connect-GdapGraph -Scopes $Scopes)) {
        Write-Color "FATAL: Cannot authenticate to Microsoft Graph." Red
        exit
    }
}

# --------------------------------------------------------------------
# Disconnect cleanly (optional use)
# --------------------------------------------------------------------
function Disconnect-GdapGraph {
    Write-Log "Disconnecting from Microsoft Graph…" Cyan
    try {
        Disconnect-MgGraph
        Write-Log "Graph session closed." Green
    }
    catch {
        Write-Color "Warning: Failed to disconnect Graph: $($_.Exception.Message)" Yellow
    }
}

# End of file
