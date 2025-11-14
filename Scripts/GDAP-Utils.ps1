<#
    GDAP-Utils.ps1
    Shared helper functions for the GDAP Toolkit
    Author: ChatGPT
    Version: 1.0.0
#>

# -------------------------------------------------------
# Write-Color — Safe colored output
# -------------------------------------------------------
function Write-Color {
    param(
        [string]$Text,
        [ConsoleColor]$Color = 'White'
    )
    try {
        $old = $Host.UI.RawUI.ForegroundColor
        $Host.UI.RawUI.ForegroundColor = $Color
        Write-Host $Text
        $Host.UI.RawUI.ForegroundColor = $old
    }
    catch {
        Write-Host $Text
    }
}

# -------------------------------------------------------
# Write-Log — Timestamped logs for exports
# -------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'Gray'
    )
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Color "[$stamp] $Message" $Color
}

# -------------------------------------------------------
# Convert-GraphDate — Robust Microsoft Graph date parser
# Preserves your original working behavior
# -------------------------------------------------------
function Convert-GraphDate {
    param(
        $Raw
    )

    if (-not $Raw) { return $null }

    $s = $Raw.ToString()

    # Handle /Date(1680000000000)/
    if ($s -match '\d{10,}') {
        try {
            $ms = [int64]($s -replace '[^\d-]', '')
            $epoch = Get-Date -Date "1970-01-01T00:00:00Z"
            return $epoch.AddMilliseconds($ms).ToLocalTime()
        }
        catch {
            return $null
        }
    }

    # Fallback: direct cast
    try {
        return [datetime]$Raw
    }
    catch {
        return $null
    }
}

# -------------------------------------------------------
# Ensure-Folder — Creates folder if missing
# -------------------------------------------------------
function Ensure-Folder {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            return $true
        }
        catch {
            Write-Color "ERROR: Unable to create folder: $Path" Red
            return $false
        }
    }

    return $true
}

# End of file
