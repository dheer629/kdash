<#
.SYNOPSIS
Render the saved tmux ANSI captures of a kdash validation run into PNG screenshots.

.DESCRIPTION
Every CLI capture in artifacts/<run>/<namespace>/cli/<n>-<view>.ansi is the exact
screen tmux saved while kdash was running live. This script replays that screen
with scripts/capture-terminal.py (pyte + Pillow) and writes one PNG per view into
samples/cli/<namespace>/. Values are not generated or edited: the renderer paints
the captured cells, and each image states the namespace, the view and the source
file, so a screenshot can always be traced back to its capture.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/render-cli-samples.ps1 `
  -RunDirectory artifacts/wsl-validation-20261018-175000
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RunDirectory,
  [string]$SamplesDirectory,
  [string]$Python,
  [int]$Columns = 170,
  [int]$Rows = 50,
  [int]$FontSize = 13
)

$ErrorActionPreference = 'Stop'

# The renderer needs an interpreter with pyte and Pillow. Find one unless the
# caller passed -Python, so the script carries no machine-specific path.
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

$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptDir
$renderer = Join-Path $scriptDir 'capture-terminal.py'
if (-not $SamplesDirectory) { $SamplesDirectory = Join-Path $repoRoot 'samples' }
if (-not (Test-Path -LiteralPath $RunDirectory)) { throw "run directory not found: $RunDirectory" }
if (-not (Test-Path -LiteralPath $renderer)) { throw "renderer not found: $renderer" }
$Python = Resolve-Python -Given $Python

$run = Get-Item -LiteralPath $RunDirectory
$outputRoot = Join-Path $SamplesDirectory 'cli'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$rendered = 0

foreach ($nsDir in Get-ChildItem -LiteralPath $run.FullName -Directory | Sort-Object Name) {
  $cli = Join-Path $nsDir.FullName 'cli'
  if (-not (Test-Path -LiteralPath $cli)) { continue }
  $captures = @(Get-ChildItem -LiteralPath $cli -Filter '*.ansi' | Sort-Object Name)
  if ($captures.Count -eq 0) { continue }
  $target = Join-Path $outputRoot $nsDir.Name
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  foreach ($ansi in $captures) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($ansi.Name)
    $png = Join-Path $target ($stem + '.png')
    $title = "kdash $stem live - namespace $($nsDir.Name) - run $($run.Name)"
    & $Python $renderer $ansi.FullName $png --columns $Columns --rows $Rows --font-size $FontSize --title $title
    if ($LASTEXITCODE -ne 0) { throw "render failed: $($ansi.FullName)" }
    $rendered++
    Write-Host ("rendered {0,-10} {1}" -f $stem, $png)
  }
}
Write-Host "rendered $rendered CLI screenshots into $outputRoot"
