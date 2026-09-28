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

$metaEditorPath = Join-Path $mt5RootPath "MetaEditor64.exe"
$mql5Root = Join-Path $mt5RootPath "MQL5"
$projectPath = Join-Path $mql5Root "Experts\XAUForge\XAUForge.mqproj"
$logPath = [System.IO.Path]::ChangeExtension($projectPath, ".log")

if (-not (Test-Path -LiteralPath $metaEditorPath -PathType Leaf)) {
    throw "MetaEditor executable not found: $metaEditorPath"
}

if (-not (Test-Path -LiteralPath $mql5Root -PathType Container)) {
    throw "MQL5 directory not found: $mql5Root"
}

if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "XAUForge project file not found through the MT5 runtime linkage: $projectPath"
}

if (Test-Path -LiteralPath $logPath -PathType Leaf) {
    Remove-Item -LiteralPath $logPath -Force
}

$arguments = @(
    "/compile:`"$projectPath`""
    "/include:`"$mql5Root`""
    "/log"
)

$process = Start-Process `
    -FilePath $metaEditorPath `
    -ArgumentList $arguments `
    -Wait `
    -PassThru

if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
    throw "MetaEditor did not produce the expected compilation log: $logPath"
}

$logContent = Get-Content -LiteralPath $logPath -Raw

$resultMatch = [regex]::Match(
    $logContent,
    "Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?"
)

if (-not $resultMatch.Success) {
    throw "Could not determine the compilation result from: $logPath"
}

$errorCount = [int]$resultMatch.Groups[1].Value
$warningCount = [int]$resultMatch.Groups[2].Value

Write-Host "MetaEditor process exit code: $($process.ExitCode)"
Write-Host "Compilation log: $logPath"
Write-Host "Compile result: $errorCount errors, $warningCount warnings"

if ($errorCount -ne 0 -or $warningCount -ne 0) {
    throw "MQL5 compile gate failed: $errorCount errors, $warningCount warnings."
}

Write-Host "MQL5 compile gate passed."
