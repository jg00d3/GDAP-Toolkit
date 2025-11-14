<#
    GDAP-Bootstrap.ps1
    Self-updating loader for the GDAP Toolkit
    Author: ChatGPT
    Version: 1.0.0
#>

# ---------------------------------------------
# Config
# ---------------------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitHubUser = "jg00d3"
$GitHubRepo = "gdap-toolkit"
$GitHubFolder = "Scripts"

$RawBase = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/main/$GitHubFolder"

# Files that bootstrap manages
$ManagedFiles = @(
    "version.txt",
    "GDAP-Utils.ps1",
    "GDAP-Modules.ps1",
    "GDAP-Graph.ps1",
    "GDAP-Data.ps1",
    "GDAP-Output.ps1",
    "GDAP-Export.ps1"
)

$LocalVersionFile = Join-Path $ScriptRoot "version.txt"
$LocalVersion = "0.0.0"

# ---------------------------------------------
# Helper: Write colored output (local fallback)
# ---------------------------------------------
function Write-Color {
    param([string]$Text, [ConsoleColor]$Color = "White")
    $old = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Text
    $Host.UI.RawUI.ForegroundColor = $old
}

# ---------------------------------------------
# Load local version
# ---------------------------------------------
if (Test-Path $LocalVersionFile) {
    $LocalVersion = Get-Content $LocalVersionFile -ErrorAction SilentlyContinue
}

Write-Color "Local Version : $LocalVersion" Cyan

# ---------------------------------------------
# Retrieve remote version
# ---------------------------------------------
$RemoteVersionUrl = "$RawBase/version.txt"
Write-Color "Checking remote version: $RemoteVersionUrl" DarkGray

try {
    $RemoteVersion = Invoke-WebRequest -Uri $RemoteVersionUrl -UseBasicParsing |
        Select-Object -ExpandProperty Content
    Write-Color "Remote Version: $RemoteVersion" Green
}
catch {
    Write-Color "ERROR: Unable to fetch remote version: $($_.Exception.Message)" Red
    exit
}

# ---------------------------------------------
# Version comparison
# ---------------------------------------------
if ($LocalVersion -ne $RemoteVersion) {
    Write-Color "`nUPDATE AVAILABLE — Updating GDAP Toolkit…" Yellow

    foreach ($file in $ManagedFiles) {
        $url = "$RawBase/$file"
        $localPath = Join-Path $ScriptRoot $file

        Write-Color "Downloading $file…" Cyan
        try {
            Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing -ErrorAction Stop
            Unblock-File -Path $localPath -ErrorAction SilentlyContinue
            Write-Color "Updated: $file" Green
        }
        catch {
            Write-Color "FAILED: $file — $($_.Exception.Message)" Red
        }
    }

    Write-Color "`nUpdate complete." Green
}
else {
    Write-Color "`nGDAP Toolkit is already up to date." Green
}

# ---------------------------------------------
# Main Menu
# ---------------------------------------------
Write-Color "`n===============================" Yellow
Write-Color "        GDAP TOOLKIT MENU       " Yellow
Write-Color "===============================" Yellow

Write-Color "1. Run GDAP Export" White
Write-Color "2. Exit" White

$choice = Read-Host "`nSelect (1-2)"

switch ($choice) {

    '1' {
        $exportScript = Join-Path $ScriptRoot "GDAP-Export.ps1"
        if (Test-Path $exportScript) {
            Write-Color "`nLaunching GDAP Export…" Cyan
            & $exportScript
        }
        else {
            Write-Color "ERROR: GDAP-Export.ps1 not found!" Red
        }
    }

    default {
        Write-Color "Exiting…" DarkGray
    }
}

