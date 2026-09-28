[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Mt5Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-NormalizedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

$repoRoot = Get-NormalizedPath (Join-Path $PSScriptRoot "..")

if (-not (Test-Path -LiteralPath $Mt5Root -PathType Container)) {
    throw "MT5 root does not exist: $Mt5Root"
}

$mt5RootPath = Get-NormalizedPath (Resolve-Path -LiteralPath $Mt5Root).Path

$repoPrefix = $repoRoot + [System.IO.Path]::DirectorySeparatorChar
$mt5Prefix = $mt5RootPath + [System.IO.Path]::DirectorySeparatorChar

if (
    $mt5RootPath.Equals(
        $repoRoot,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -or
    $mt5Prefix.StartsWith(
        $repoPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "The MT5 installation must be outside the Git repository."
}

$terminalPath = Join-Path $mt5RootPath "terminal64.exe"
$metaEditorPath = Join-Path $mt5RootPath "MetaEditor64.exe"
$mql5Root = Join-Path $mt5RootPath "MQL5"

foreach ($requiredPath in @($terminalPath, $metaEditorPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required MT5 executable not found: $requiredPath"
    }
}

if (-not (Test-Path -LiteralPath $mql5Root -PathType Container)) {
    throw "MQL5 directory not found: $mql5Root"
}

$links = @(
    @{
        Source = Join-Path $repoRoot "mql5\Experts\XAUForge"
        Destination = Join-Path $mql5Root "Experts\XAUForge"
    },
    @{
        Source = Join-Path $repoRoot "mql5\Include\XAUForge"
        Destination = Join-Path $mql5Root "Include\XAUForge"
    }
)

foreach ($link in $links) {
    $source = Get-NormalizedPath $link.Source
    $destination = Get-NormalizedPath $link.Destination

    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Repository source directory not found: $source"
    }

    $destinationParent = Split-Path -Parent $destination

    if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
        throw "MT5 destination parent directory not found: $destinationParent"
    }

    if (Test-Path -LiteralPath $destination) {
        $existingItem = Get-Item -LiteralPath $destination -Force

        if ($existingItem.LinkType -ne "Junction") {
            throw "Destination already exists and is not a junction: $destination"
        }

        $existingTarget = Get-NormalizedPath ([string]$existingItem.Target)

        if (-not $existingTarget.Equals(
            $source,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Junction target mismatch: $destination -> $existingTarget"
        }

        Write-Host "Verified junction: $destination -> $source"
        continue
    }

    New-Item `
        -ItemType Junction `
        -Path $destination `
        -Target $source | Out-Null

    Write-Host "Created junction: $destination -> $source"
}

Write-Host "MT5 repository linkage verified successfully."
