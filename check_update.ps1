param(
    [string]$Repository = "kaziklubey/ggplot-shiny-gui",
    [string]$AppConfigPath = (Join-Path $PSScriptRoot "app_config.R")
)

$ErrorActionPreference = "Stop"

function Write-UpdateLine([string]$Text = "") {
    Write-Host $Text
}

function Get-AppVersion([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $match = [regex]::Match($content, 'APP_VERSION\s*<-\s*["'']([^"'']+)["'']')
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

function Get-VersionParts([string]$VersionText) {
    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return $null
    }

    $match = [regex]::Match($VersionText.Trim(), '^[^0-9]*(\d+(?:\.\d+)+)')
    if (-not $match.Success) {
        return $null
    }

    $parts = @()
    foreach ($piece in $match.Groups[1].Value.Split('.')) {
        $value = 0
        if (-not [int]::TryParse($piece, [ref]$value)) {
            return $null
        }
        $parts += $value
    }
    return [int[]]$parts
}

function Compare-VersionParts($Left, $Right) {
    if ($null -eq $Left -or $null -eq $Right) {
        return $null
    }

    $count = [Math]::Max($Left.Count, $Right.Count)
    for ($i = 0; $i -lt $count; $i++) {
        $l = if ($i -lt $Left.Count) { [int]$Left[$i] } else { 0 }
        $r = if ($i -lt $Right.Count) { [int]$Right[$i] } else { 0 }
        if ($l -lt $r) { return -1 }
        if ($l -gt $r) { return 1 }
    }
    return 0
}

function Finish-UpdateCheck {
    # This helper must never block application startup through its exit code.
    exit 0
}

if ($env:GGPLOT_GUI_SKIP_UPDATE_CHECK -match '^(1|true|yes|on)$') {
    Write-UpdateLine "Update check skipped (GGPLOT_GUI_SKIP_UPDATE_CHECK)."
    Finish-UpdateCheck
}

$currentVersion = Get-AppVersion $AppConfigPath
if ([string]::IsNullOrWhiteSpace($currentVersion)) {
    Write-UpdateLine "Update check skipped: APP_VERSION was not found."
    Finish-UpdateCheck
}

try {
    # Windows PowerShell 5.1 can otherwise negotiate an older TLS version on some PCs.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $apiUrl = "https://api.github.com/repos/$Repository/releases/latest"
    $headers = @{
        "Accept" = "application/vnd.github+json"
    }

    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UserAgent "ggplot-shiny-gui-update-check" -Method Get -TimeoutSec 5
} catch {
    $statusCode = $null
    try {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
    } catch {
        $statusCode = $null
    }

    if ($statusCode -eq 404) {
        Write-UpdateLine "Update check: no GitHub Release is published yet. Continuing."
    } else {
        Write-UpdateLine "Update check skipped: GitHub could not be reached. Continuing."
    }
    Finish-UpdateCheck
}

$latestVersion = [string]$release.tag_name
if ([string]::IsNullOrWhiteSpace($latestVersion)) {
    $latestVersion = [string]$release.name
}
$releaseUrl = [string]$release.html_url

$currentParts = Get-VersionParts $currentVersion
$latestParts = Get-VersionParts $latestVersion
$comparison = Compare-VersionParts $currentParts $latestParts

if ($null -eq $comparison) {
    Write-UpdateLine "Update check: latest release found, but its version could not be compared."
    Write-UpdateLine "Current: $currentVersion"
    Write-UpdateLine "Latest : $latestVersion"
    if (-not [string]::IsNullOrWhiteSpace($releaseUrl)) {
        Write-UpdateLine "Release: $releaseUrl"
    }
    Finish-UpdateCheck
}

if ($comparison -ge 0) {
    Write-UpdateLine "Update check: current version is up to date."
    Write-UpdateLine "Current: $currentVersion"
    Write-UpdateLine "Latest : $latestVersion"
    Finish-UpdateCheck
}

Write-UpdateLine ""
Write-UpdateLine "============================================================"
Write-UpdateLine " A newer ggplot-shiny-gui release is available"
Write-UpdateLine " Current: $currentVersion"
Write-UpdateLine " Latest : $latestVersion"
if (-not [string]::IsNullOrWhiteSpace($releaseUrl)) {
    Write-UpdateLine " Release: $releaseUrl"
}
Write-UpdateLine "============================================================"
Write-UpdateLine ""

try {
    $answer = Read-Host "Press U to open the release page, or Enter to continue"
    if ($answer -match '^[Uu]$' -and -not [string]::IsNullOrWhiteSpace($releaseUrl)) {
        Start-Process $releaseUrl | Out-Null
    }
} catch {
    # Non-interactive launch: just continue.
}

Finish-UpdateCheck
