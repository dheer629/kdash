<#
.SYNOPSIS
Render the raw ANSI captures of a feature run into the PNGs named by its manifest.

.DESCRIPTION
Every live screen kept in artifacts/<run>/raw/ has a row in that run's captures.tsv:
the raw file, its terminal geometry, a title and the PNG it belongs to. This script
renders each row with scripts/capture-terminal.py (pyte + Pillow), so the images are
cell-by-cell replays of the captured screen, never a hand-drawn or retyped picture.

It renders only rows whose target PNG lives under a single gallery directory (for
example samples/cli_419) and then writes that gallery's SHA256SUMS, so a published
gallery can be verified without re-running anything.

Nothing here talks to a cluster or changes a cluster object.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/render-captures.ps1 `
  -CaptureDirectory artifacts/view-screens-20261031-051739
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$CaptureDirectory,
  [string]$SamplesDirectory,
  [string]$Python,
  [int]$FontSize = 13
)

$ErrorActionPreference = 'Stop'

function Resolve-Python {
  param([string]$Given)
  if ($Given) {
    if (Test-Path -LiteralPath $Given) { return $Given }
    throw "python not found: $Given"
  }
  foreach ($name in 'python.exe', 'python3.exe', 'py.exe') {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }
    & $cmd.Source -c 'import PIL, pyte' 2>$null
    if ($LASTEXITCODE -eq 0) { return $cmd.Source }
  }
  throw 'no Python with pyte and Pillow found; install them (pip install --user pillow pyte) or pass -Python PATH'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$renderer = Join-Path $PSScriptRoot 'capture-terminal.py'
if (-not (Test-Path -LiteralPath $renderer)) { throw "missing: $renderer" }
if (-not $SamplesDirectory) { $SamplesDirectory = Join-Path $repoRoot 'samples' }
$Python = Resolve-Python -Given $Python

$feature = Get-Item -LiteralPath $CaptureDirectory
$manifest = Join-Path $feature.FullName 'captures.tsv'
if (-not (Test-Path -LiteralPath $manifest)) { throw "no captures.tsv in $($feature.FullName)" }

$made = New-Object System.Collections.Generic.List[string]
$galleryDirs = New-Object System.Collections.Generic.List[string]
foreach ($row in (Get-Content -LiteralPath $manifest | Select-Object -Skip 1 | Where-Object { $_.Trim() })) {
  $f = $row -split "`t"
  if ($f.Count -lt 5) { continue }
  $ansi = Join-Path $feature.FullName $f[0]
  if (-not (Test-Path -LiteralPath $ansi)) { throw "missing capture: $ansi" }
  # captures.tsv stores gallery paths relative to the repository root
  $rel = $f[4] -replace '\\', '/'
  $png = if ($rel -match '^(samples|artifacts|docs)/') { Join-Path $repoRoot $rel }
         else { Join-Path $SamplesDirectory $rel }
  $dir = Split-Path -Parent $png
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $galleryDirs.Add($dir)
  & $Python $renderer $ansi $png --columns ([int]$f[1]) --rows ([int]$f[2]) --font-size $FontSize --title $f[3] | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "render failed: $ansi" }
  $made.Add($png)
  Write-Host ("render  {0}  <- {1}" -f $f[4], $f[0])
}

$galleries = $galleryDirs | Sort-Object -Unique
foreach ($dir in $galleries) {
  $rel = $made | Where-Object { (Split-Path -Parent $_) -eq $dir } | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLower()
    "$hash  $(Split-Path -Leaf $_)"
  }
  Set-Content -LiteralPath (Join-Path $dir 'SHA256SUMS') -Value $rel -Encoding ascii
  Write-Host ("checksums {0}  ({1} images)" -f ((Join-Path $dir 'SHA256SUMS').Substring($repoRoot.Length).TrimStart('\', '/')), $rel.Count)
}
Write-Host "rendered $($made.Count) screens"
