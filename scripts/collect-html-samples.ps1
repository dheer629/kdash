<#
.SYNOPSIS
Collect the HTML samples a kdash validation run produced into samples/html/.

.DESCRIPTION
kdash writes its reports under <run>/<namespace>/reports (namespace report with
all tabs and the live history, one-shot snapshots per view, the combined evidence
bundle and its index) and the audit report under <run>/<namespace>/audit. This
script copies those files unchanged into samples/html/<namespace>/, writes a
SHA256SUMS list for them, and can additionally take real browser screenshots of
the main pages with Microsoft Edge in headless mode (-Screenshot).

No value inside a report is generated, renamed or edited: the files are copied
byte for byte, and the checksum list lets a reviewer verify that.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/collect-html-samples.ps1 `
  -RunDirectory artifacts/wsl-validation-20261018-115201 -Screenshot

.EXAMPLE
# collect one run into its own gallery instead of samples/html:
powershell -ExecutionPolicy Bypass -File scripts/collect-html-samples.ps1 `
  -RunDirectory artifacts/operation-screens-20261031-062059 `
  -OutputDirectory samples/html419 -Screenshot
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RunDirectory,
  [string]$SamplesDirectory,
  [string]$OutputDirectory,
  [switch]$Screenshot,
  [string]$Edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  [int]$Width = 1500,
  [int]$Height = 1100
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $SamplesDirectory) { $SamplesDirectory = Join-Path $repoRoot 'samples' }
$run = Get-Item -LiteralPath $RunDirectory
# Default target: <samples>/html. Pass -OutputDirectory to collect a run into its
# own gallery (for example samples/html419) without touching an existing one.
$outputRoot = if ($OutputDirectory) { Join-Path $repoRoot $OutputDirectory }
              else { Join-Path $SamplesDirectory 'html' }
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$copied = New-Object System.Collections.Generic.List[string]

foreach ($nsDir in Get-ChildItem -LiteralPath $run.FullName -Directory | Sort-Object Name) {
  $reports = Join-Path $nsDir.FullName 'reports'
  $audit = Join-Path $nsDir.FullName 'audit'
  $files = @()
  if (Test-Path -LiteralPath $reports) { $files += Get-ChildItem -LiteralPath $reports -Filter '*.html' -File }
  if (Test-Path -LiteralPath $audit) { $files += Get-ChildItem -LiteralPath $audit -File | Where-Object { $_.Extension -in '.html', '.csv' } }
  if ($files.Count -eq 0) { continue }
  $target = Join-Path $outputRoot $nsDir.Name
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  foreach ($file in ($files | Sort-Object Name)) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $target $file.Name) -Force
    $copied.Add((Join-Path $target $file.Name))
    Write-Host ("copied   {0,-12} {1}" -f $nsDir.Name, $file.Name)
  }

  if ($Screenshot) {
    if (-not (Test-Path -LiteralPath $Edge)) { throw "browser not found: $Edge" }
    $shots = Join-Path $target 'screenshots'
    New-Item -ItemType Directory -Force -Path $shots | Out-Null
    $pages = $files | Where-Object { $_.Name -match '^(kdash_namespace_report|index)' } | Sort-Object Name
    foreach ($page in $pages) {
      $png = Join-Path $shots (([System.IO.Path]::GetFileNameWithoutExtension($page.Name)) + '.png')
      $uri = ([System.Uri]$page.FullName).AbsoluteUri
      & $Edge '--headless=new' '--disable-gpu' '--hide-scrollbars' '--no-first-run' `
        "--window-size=$Width,$Height" "--screenshot=$png" $uri | Out-Null
      if (-not (Test-Path -LiteralPath $png)) {
        & $Edge '--headless' '--disable-gpu' '--hide-scrollbars' '--no-first-run' `
          "--window-size=$Width,$Height" "--screenshot=$png" $uri | Out-Null
      }
      if (Test-Path -LiteralPath $png) {
        Write-Host ("shot     {0,-12} {1}" -f $nsDir.Name, (Split-Path -Leaf $png))
      } else {
        Write-Warning "screenshot failed for $($page.Name)"
      }
    }
  }
}

if ($copied.Count -eq 0) { Write-Warning 'no HTML reports found in this run'; exit 0 }
$sumFile = Join-Path $outputRoot 'SHA256SUMS'
$lines = foreach ($path in $copied) {
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
  # Windows PowerShell 5.1 has no [System.IO.Path]::GetRelativePath
  $rel = $path.Substring($outputRoot.Length).TrimStart('\', '/').Replace('\', '/')
  "$hash  $rel"
}
Set-Content -LiteralPath $sumFile -Value $lines -Encoding ascii
Write-Host "copied $($copied.Count) HTML/CSV report files into $outputRoot (checksums in SHA256SUMS)"
