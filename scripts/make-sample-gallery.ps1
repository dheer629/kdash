<#
.SYNOPSIS
Build the flat samples gallery (the cli_*.png and html_*.png images in samples/).

.DESCRIPTION
The gallery is made of three kinds of image, all of them from this project's own
generic WSL vcluster runs:

  1. live CLI screens rendered from the ANSI captures of
     artifacts/feature-screens-<run>/raw/*.ansi (help screen, narrow terminal,
     alerts over time, audit table, first-run disclaimer), using
     scripts/capture-terminal.py;
  2. copies of the view screenshots of the five-minute validation run in
     samples/cli/<namespace>/;
  3. browser screenshots (Microsoft Edge, headless) of the HTML reports in
     samples/html/<namespace>/.

No value is invented: every image is a render or a screenshot of something the
run actually produced, and each CLI image states its namespace, view and the
sha256 of the capture it came from. A checksum list is written to
samples/SHA256SUMS.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/make-sample-gallery.ps1 `
  -RunDirectory artifacts/wsl-validation-20261018-115201 `
  -FeatureDirectory artifacts/feature-screens-20261018-122242
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RunDirectory,
  [Parameter(Mandatory = $true)][string]$FeatureDirectory,
  [string]$SamplesDirectory,
  [string]$Python = 'C:\Users\demo\AppData\Local\Programs\Python\Python312\python.exe',
  [string]$Edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  [int]$Width = 1500,
  [int]$Height = 1100,
  [int]$TallHeight = 3600
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$renderer = Join-Path $PSScriptRoot 'capture-terminal.py'
if (-not $SamplesDirectory) { $SamplesDirectory = Join-Path $repoRoot 'samples' }
foreach ($path in @($renderer, $Python, $Edge)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "missing: $path" }
}
$feature = Get-Item -LiteralPath $FeatureDirectory
$run = Get-Item -LiteralPath $RunDirectory
$htmlNs = Join-Path (Join-Path $SamplesDirectory 'html') 'orders-service-e2e'
$made = New-Object System.Collections.Generic.List[string]

function Shot([string]$page, [string]$png, [int]$w, [int]$h) {
  $uri = ([System.Uri]$page).AbsoluteUri
  & $Edge '--headless=new' '--disable-gpu' '--hide-scrollbars' '--no-first-run' `
    "--window-size=$w,$h" "--screenshot=$png" $uri | Out-Null
  if (-not (Test-Path -LiteralPath $png)) {
    & $Edge '--headless' '--disable-gpu' '--hide-scrollbars' '--no-first-run' `
      "--window-size=$w,$h" "--screenshot=$png" $uri | Out-Null
  }
  if (-not (Test-Path -LiteralPath $png)) { throw "screenshot failed: $page" }
  $made.Add($png)
  Write-Host ("shot    {0}" -f (Split-Path -Leaf $png))
}

# 1. feature captures -> rendered PNG
$manifest = Join-Path $feature.FullName 'captures.tsv'
if (-not (Test-Path -LiteralPath $manifest)) { throw "no captures.tsv in $($feature.FullName)" }
$rows = Get-Content -LiteralPath $manifest | Select-Object -Skip 1 | Where-Object { $_.Trim() }
foreach ($row in $rows) {
  $f = $row -split "`t"
  if ($f.Count -lt 5) { continue }
  $ansi = Join-Path $feature.FullName $f[0]
  $png = Join-Path $SamplesDirectory $f[4]
  & $Python $renderer $ansi $png --columns ([int]$f[1]) --rows ([int]$f[2]) --font-size 13 --title $f[3] | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "render failed: $ansi" }
  $made.Add($png)
  Write-Host ("render  {0}  <- {1}" -f $f[4], $f[0])
}

# 2. view screenshots of the validation run
$copies = @{
  'cli/orders-service-e2e/01-pods.png'     = 'cli_pods_audited_header.png'
  'cli/ml-service-prod/01-pods.png'         = 'cli_pods_timeline_sparklines.png'
  'cli/gitops-core/03-workloads.png'       = 'cli_workloads_sparklines.png'
}
foreach ($src in $copies.Keys) {
  $from = Join-Path $SamplesDirectory $src
  if (-not (Test-Path -LiteralPath $from)) { throw "missing view screenshot: $from" }
  $to = Join-Path $SamplesDirectory $copies[$src]
  Copy-Item -LiteralPath $from -Destination $to -Force
  $made.Add($to)
  Write-Host ("copy    {0}  <- {1}" -f $copies[$src], $src)
}

# 3. browser screenshots of the HTML reports
$report = Get-ChildItem -LiteralPath $htmlNs -Filter 'kdash_namespace_report_*.html' |
  Sort-Object Name -Descending | Select-Object -First 1
Shot $report.FullName (Join-Path $SamplesDirectory 'html_overview.png') $Width $Height
Shot $report.FullName (Join-Path $SamplesDirectory 'html_report_disclaimer_footer.png') $Width $TallHeight
foreach ($pair in @(
  @('kdash_pod_container_resources_*.html',    'html_pods_charts.png'),
  @('kdash_memory_dashboard_*.html',           'html_memory_charts.png'),
  @('kdash_workloads_per_worker_node_*.html',  'html_workloads_charts.png'),
  @('kdash_audit_*.html',                      'html_audit_report.png'))) {
  $page = Get-ChildItem -LiteralPath $htmlNs -Filter $pair[0] | Sort-Object Name -Descending | Select-Object -First 1
  if (-not $page) { throw "missing report for $($pair[1])" }
  Shot $page.FullName (Join-Path $SamplesDirectory $pair[1]) $Width $Height
}

# checksum list for the gallery
$lines = foreach ($file in $made) {
  $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower()
  $rel = $file.Substring($SamplesDirectory.Length).TrimStart('\', '/').Replace('\', '/')
  "$hash  $rel"
}
Set-Content -LiteralPath (Join-Path $SamplesDirectory 'SHA256SUMS') -Value $lines -Encoding ascii
Write-Host "gallery complete: $($made.Count) images (checksums in samples/SHA256SUMS)"
