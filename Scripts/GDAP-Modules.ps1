<#
    GDAP-Modules.ps1
    Ensures required PowerShell modules are installed & imported.
    Author: ChatGPT
    Version: 1.0.0
#>

# --------------------------------------------------------------------
# Imports needed for Write-Color / Write-Log
# --------------------------------------------------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\GDAP-Utils.ps1"

# --------------------------------------------------------------------
# Required modules
# --------------------------------------------------------------------
$RequiredGraphModules = @(
    "Microsoft.Graph",
    "Microsoft.Graph.Beta"
)

$RequiredUtilityModules = @(
    "ImportExcel"
)

# --------------------------------------------------------------------
# Helper: Install module with logging
# --------------------------------------------------------------------
function Install-GdapModule {
    param(
        [string]$ModuleName
    )

    Write-Log "Installing module: $ModuleName" Yellow

    try {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop
        Write-Log "Installed module: $ModuleName" Green
        return $true
    }
    catch {
        Write-Color "FAILED to install ${ModuleName}: $($_.Exception.Message)" Red
        return $false
    }
}

# --------------------------------------------------------------------
# Helper: Ensure module exists (install if missing)
# --------------------------------------------------------------------
function Ensure-GdapModule {
    param(
        [string]$ModuleName
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Log "Module missing: $ModuleName" Yellow

        $response = Read-Host "Install missing module '$ModuleName'? (Y/N)"
        if ($response -match '^[Yy]$') {
            if (-not (Install-GdapModule -ModuleName $ModuleName)) {
                Write-Color "CANNOT CONTINUE — Missing required module '$ModuleName'." Red
                exit
            }
        }
        else {
            Write-Color "CANNOT CONTINUE — You declined installation of '$ModuleName'." Red
            exit
        }
    }
    else {
        Write-Log "Module present: $ModuleName" Green
    }

    try {
        Import-Module $ModuleName -ErrorAction Stop
        Write-Log "Imported module: $ModuleName" Green
    }
    catch {
        Write-Color "ERROR importing ${ModuleName}: $($_.Exception.Message)" Red
        exit
    }
}

# --------------------------------------------------------------------
# Ensure ALL Required Modules
# --------------------------------------------------------------------
function Ensure-GdapModules {

    Write-Log "Checking GDAP module dependencies…" Cyan

    foreach ($gm in $RequiredGraphModules) {
        Ensure-GdapModule -ModuleName $gm
    }

    foreach ($um in $RequiredUtilityModules) {
        Ensure-GdapModule -ModuleName $um
    }

    Write-Log "All required modules installed & imported." Green
}

# End of file
