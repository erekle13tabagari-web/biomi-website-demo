# What changed in the Vortice library since the site was generated?
#
# vortice-pages.json records the exact source file for every image the site
# used. Comparing that against the folder as it stands now says whether the
# reorganisation is cosmetic (folders renamed, files moved) or whether the
# photography itself changed and pages need regenerating.
. (Join-Path $PSScriptRoot 'config.ps1')
$root = $LIBRARY
$sp   = $PSScriptRoot
$mods = Get-Content (Join-Path $sp 'vortice-pages.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# every image in the library now, by content hash -> where it lives
$SKIP = 'DO NOT TOUCH', 'კატალოგები'
$now = @{}
foreach ($f in Get-ChildItem -LiteralPath $root -Directory) {
  $skipThis = $false
  foreach ($s in $SKIP) { if ($f.Name -like "*$s*") { $skipThis = $true } }
  if ($skipThis) { continue }
  foreach ($img in Get-ChildItem -LiteralPath $f.FullName -File -Recurse -EA SilentlyContinue |
                   Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' }) {
    $h = (Get-FileHash -LiteralPath $img.FullName -Algorithm MD5).Hash
    if (-not $now.ContainsKey($h)) { $now[$h] = @() }
    $now[$h] += $img.FullName
  }
}
Write-Host ("images in library now (excl. catalogues / DO NOT TOUCH): " + ($now.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum)
Write-Host ("distinct by content: " + $now.Keys.Count)

$missingFile = @(); $movedOnly = @(); $ok = 0
foreach ($m in $mods) {
  foreach ($p in @($m.images)) {
    if (-not $p) { continue }
    if (Test-Path -LiteralPath $p) { $ok++; continue }
    # the recorded path is gone -- is the same picture still somewhere?
    $leaf = Split-Path $p -Leaf
    $hit = $null
    foreach ($k in $now.Keys) { foreach ($q in $now[$k]) { if ((Split-Path $q -Leaf) -eq $leaf) { $hit = $q; break } } ; if ($hit) { break } }
    if ($hit) { $movedOnly += ($m.model + ' :: ' + $leaf) } else { $missingFile += ($m.model + ' :: ' + $leaf) }
  }
}
Write-Host ''
Write-Host ("source images still at their recorded path : $ok")
Write-Host ("moved but still present                    : " + $movedOnly.Count)
$movedOnly | Select-Object -First 20 | ForEach-Object { Write-Host ('    ' + $_) }
Write-Host ("gone from the library entirely             : " + $missingFile.Count)
$missingFile | Select-Object -First 20 | ForEach-Object { Write-Host ('    ' + $_) }

# anything genuinely new?
$used = @{}
foreach ($m in $mods) { foreach ($p in @($m.images)) { if ($p) { $used[(Split-Path $p -Leaf)] = $true } } }
$new = @()
foreach ($k in $now.Keys) {
  foreach ($q in $now[$k]) { if (-not $used.ContainsKey((Split-Path $q -Leaf))) { $new += $q } }
}
Write-Host ''
Write-Host ("images in the library the site has never seen: " + $new.Count)
$new | ForEach-Object { Write-Host ('    ' + $_.Substring($root.Length + 1)) }
