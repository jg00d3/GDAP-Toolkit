<#
    GDAP-Bootstrap.ps1
    Version: 1.0.3

    - Checks local version
    - Fetches remote version (cache-busted)
    - Updates all toolkit scripts from GitHub (cache-busted)
    - Logs all activity
    - Launches GDAP-Export.ps1
#>

# ------------------------------
# Config
# ------------------------------

$GitHubUser   = "jg00d3"
$GitHubRepo   = "gdap-toolkit"
$GitHubFolder = "Scripts"

$FilesToDownload = @(
    "version.txt",
    "GDAP-Utils.ps1",
    "GDAP-Modules.ps1",
    "GDAP-Graph.ps1",
    "GDAP-Data.ps1",
    "GDAP-Output.ps1",
    "GDAP-Export.ps1"
)

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogsDir   = Join-Path $ScriptDir "Logs"
if (!(Test-Path $LogsDir)) { New-Item -Path $LogsDir -ItemType Directory | Out-Null }

$RawBase = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/main/$GitHubFolder"

# ------------------------------
# Logging helper
# ------------------------------
function Write-Log {
    param([string]$Message)

    $logFile = Join-Path $LogsDir "bootstrap-$(Get-Date -Format yyyyMMdd).log"
    $timestamp = "[{0}]" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    "$timestamp $Message" | Tee-Object -FilePath $logFile -Append
}

# ------------------------------
# Read Local Version
# ------------------------------
$LocalVersionFile = Join-Path $ScriptDir "version.txt"

if (Test-Path $LocalVersionFile) {
    $LocalVersion = (Get-Content $LocalVersionFile).Trim()
} else {
    $LocalVersion = "0.0.0"
}

Write-Host "Local Version : $LocalVersion"
Write-Log  "Local Version : $LocalVersion"

# ------------------------------
# Read Remote Version (WITH FIXED CACHEBUST)
# ------------------------------
$RemoteVersionUrl = "$RawBase/version.txt" + "?cacheBust=$(Get-Random)"

Write-Host "Checking remote version: $RemoteVersionUrl"
Write-Log  "Checking remote version: $RemoteVersionUrl"

try {
    $RemoteVersion = (
        Invoke-WebRequest -Uri $RemoteVersionUrl -UseBasicParsing
    ).Content.Trim()

    Write-Host "Remote Version: $RemoteVersion"
    Write-Log  "Remote Version: $RemoteVersion"
}
catch {
    Write-Host "ERROR: Could not fetch remote version." -ForegroundColor Red
    Write-Log  "ERROR: Failed to fetch remote version. $_"
    exit
}

# ------------------------------
# Version Compare
# ------------------------------
function Convert-Version([string]$v) { return [version]$v }

$LocalV  = Convert-Version $LocalVersion
$RemoteV = Convert-Version $RemoteVersion

$UpdateNeeded = $RemoteV -gt $LocalV

# ------------------------------
# Perform Update
# ------------------------------
if ($UpdateNeeded) {

    Write-Host ""
    Write-Host "UPDATE AVAILABLE — Updating GDAP Toolkit…" -ForegroundColor Yellow
    Write-Log  "UPDATE AVAILABLE — Updating GDAP Toolkit…"

    foreach ($file in $FilesToDownload) {

        $remoteFileUrl = "$RawBase/$file" + "?cacheBust=$(Get-Random)"
        $localPath = Join-Path $ScriptDir $file

        Write-Host "Downloading $file…" -ForegroundColor Cyan
        Write-Log  "Downloading $file from $remoteFileUrl"

        try {
            Invoke-WebRequest -Uri $remoteFileUrl -OutFile $localPath -UseBasicParsing
            Unblock-File -Path $localPath

            Write-Host "Updated: $file" -ForegroundColor Green
            Write-Log  "Updated: $file"
        }
        catch {
            Write-Host "FAILED to download $file" -ForegroundColor Red
            Write-Log  "ERROR: Failed to download $file — $_"
        }
    }

    Write-Host ""
    Write-Host "Update complete."
    Write-Log  "Update complete."
}
else {
    Write-Host ""
    Write-Host "GDAP Toolkit is up to date." -ForegroundColor Green
    Write-Log  "GDAP Toolkit is up to date."
}

# ------------------------------
# Menu
# ------------------------------

Write-Host ""
Write-Host "==============================="
Write-Host "        GDAP TOOLKIT MENU"
Write-Host "==============================="
Write-Host "1. Run GDAP Export"
Write-Host "2. Exit"
Write-Host ""

$choice = Read-Host "Select (1-2)"

if ($choice -eq "1") {

    Write-Host ""
    Write-Host "Launching GDAP Export…" -ForegroundColor Cyan
    Write-Log  "Launching GDAP Export"

    $exportScript = Join-Path $ScriptDir "GDAP-Export.ps1"

    if (Test-Path $exportScript) {
        & $exportScript
    }
    else {
        Write-Host "ERROR: GDAP-Export.ps1 not found!" -ForegroundColor Red
        Write-Log  "ERROR: GDAP-Export.ps1 not found!"
    }

}

exit
