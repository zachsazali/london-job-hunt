<#
  Rebuilds app/data/leads.json and app/data/logos.json.
  Usage: .\build-data.ps1 -Csm <csm.html> -Pm <pm.html> -Pub <pub.html> [-Xn <expert-network.html>] [-SkipLogos]
  Each input is the saved HTML of one job-agent page; the script reads its `const D=[...]` rows.
#>
param(
  [Parameter(Mandatory)][string]$Csm,
  [Parameter(Mandatory)][string]$Pm,
  [Parameter(Mandatory)][string]$Pub,
  [string]$Xn,
  [switch]$SkipLogos
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root 'data'

function Get-Rows([string]$path) {
  $lp = if ($path.Length -ge 240 -and -not $path.StartsWith('\\?\')) { '\\?\' + $path } else { $path }
  $html = [IO.File]::ReadAllText($lp, [Text.Encoding]::UTF8)
  $m = [regex]::Match($html, 'const D=(\[[\s\S]*?\n\]);')
  if (-not $m.Success) { throw "No role data found in $path" }
  # PS 5.1 ConvertFrom-Json unrolls arrays; wrap in an object to keep shape
  $arr = [regex]::Replace($m.Groups[1].Value, ',\s*\]\s*$', ']')   # tolerate a trailing comma
  return ('{"r":' + $arr + '}' | ConvertFrom-Json).r
}
function Get-LinkedIn($id) { if ($id) { "https://www.linkedin.com/jobs/view/$id/" } else { '' } }

$leads = New-Object System.Collections.ArrayList
foreach ($r in (Get-Rows $Csm)) {
  [void]$leads.Add([ordered]@{ src='csm'; family=$r[0]; title=$r[1]; company=$r[2]; fit=$r[3]; industry=$r[4]; location=$r[5]; mode=$r[6];
    posted=$r[7]; firstPosted=$r[8]; salary=$r[9]; level=$r[12]; url=(Get-LinkedIn $r[13]); flags=@($r[14]); added=$r[15] })
}
foreach ($r in (Get-Rows $Pm)) {
  [void]$leads.Add([ordered]@{ src='pm'; family=$r[0]; title=$r[1]; company=$r[2]; fit=$r[3]; industry=$r[4]; location=$r[5]; mode=$r[6];
    posted=$r[7]; firstPosted=$r[8]; salary=$r[9]; level=$r[11]; url=(Get-LinkedIn $r[12]); flags=@($r[13]); added=$r[14] })
}
foreach ($r in (Get-Rows $Pub)) {
  [void]$leads.Add([ordered]@{ src='pub'; family=$r[0]; title=$r[1]; company=$r[2]; industry=$r[3]; fit=$r[4]; location=$r[5]; mode=$r[6];
    salary=$r[7]; closing=$r[9]; posted=$r[10]; board=$r[11]; url=$r[12]; flags=@($r[13]); why=$r[14]; added=$r[15] })
}
# Expert Network & Deal Advisory agent: same columns as the public-sector page (employer, employerType in place of org, sector)
if ($Xn) {
  foreach ($r in (Get-Rows $Xn)) {
    [void]$leads.Add([ordered]@{ src='xn'; family=$r[0]; title=$r[1]; company=$r[2]; industry=$r[3]; fit=$r[4]; location=$r[5]; mode=$r[6];
      salary=$r[7]; closing=$r[9]; posted=$r[10]; board=$r[11]; url=$r[12]; flags=@($r[13]); why=$r[14]; added=$r[15] })
  }
}

# Roles from boards without an agent page (Escape the City, Welcome to the Jungle, Intelligent People)
$extraPath = Join-Path $data 'extra-leads.json'
$scanned = $null
if (Test-Path $extraPath) {
  $extra = Get-Content $extraPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $scanned = $extra.scanned
  foreach ($e in @($extra.leads)) {
    $h = [ordered]@{}; $e.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
    $h.flags = @($e.flags); [void]$leads.Add($h)
  }
}

$asOf = ($leads | ForEach-Object { $_.added } | Sort-Object -Descending | Select-Object -First 1)
$out = [ordered]@{ asOf = $asOf; builtAt = (Get-Date).ToString('s'); scanned = $scanned; leads = $leads }
$json = $out | ConvertTo-Json -Depth 6 -Compress
[IO.File]::WriteAllText((Join-Path $data 'leads.json'), $json, (New-Object Text.UTF8Encoding $false))
$bySrc = ($leads | Group-Object { $_.src } | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '
Write-Output "leads.json: $($leads.Count) roles ($bySrc), as of $asOf"

if ($SkipLogos) { return }
# Logos: company -> data URI, fetched once per domain and kept between runs.
$domains = Get-Content (Join-Path $data 'domains.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$logoPath = Join-Path $data 'logos.json'
$cache = @{}
if (Test-Path $logoPath) {
  $old = Get-Content $logoPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $old.PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
}
$byDomain = @{}
$logos = [ordered]@{}
$fetched = 0; $failed = 0
foreach ($p in $domains.PSObject.Properties) {
  $d = $p.Value
  if ($cache.ContainsKey($d)) { $logos[$d] = $cache[$d]; continue }
  if ($byDomain.ContainsKey($d)) { continue }
  try {
    $res = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Uri "https://www.google.com/s2/favicons?domain=$d&sz=64"
    $type = $res.Headers['Content-Type']; if (-not $type) { $type = 'image/png' }
    $b64 = [Convert]::ToBase64String($res.Content)
    $logos[$d] = "data:$type;base64,$b64"; $fetched++
  } catch { $failed++ }
  $byDomain[$d] = $true
}
$logoJson = $logos | ConvertTo-Json -Compress
[IO.File]::WriteAllText($logoPath, $logoJson, (New-Object Text.UTF8Encoding $false))
Write-Output "logos.json: $($logos.Count) domains ($fetched fetched now, $failed failed)"
