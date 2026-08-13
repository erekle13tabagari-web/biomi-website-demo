# Per-model galleries for the Vortice pages that need them.
#
# A page only switches images where the library actually holds different
# photographs. Models are grouped by the hashes of their own folder's images,
# so the reuse the library is full of -- the whole MF folder being one model's
# shots, "Pink Gold" being byte-identical to the ivory unit -- collapses into a
# single shared gallery instead of pretending to be a change.
#
# Group 1 keeps the existing main/front/angle/detail/room names, because the
# hub cards, related-product cards and comparison tables all point at main.avif.
# Later groups get s2-1.avif, s3-1.avif and so on.
#
# A model with no photos of its own borrows from the model it shares the most
# leading name tokens with: CA-RM 125 ES takes CA-RM 200 ES rather than the
# CA IL shots, and TORRETTA TRM 70 takes the other TORRETTA, not TIRACAMINO.
$root = 'C:\Users\Designer\Desktop\2026\პროდუქტები\ვენტილაცია\Vortice'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'vortice-families.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'vortice-pages.json')    -Raw -Encoding UTF8 | ConvertFrom-Json
$BASE = @('main','front','angle','detail','room')
$MAX  = 5

function Rank($p) {
  $n = Split-Path $p -Leaf
  if ($n -match '\.png$')  { return 0 }
  if ($n -match 'gallery') { return 1 }
  return 2
}
# how many leading space-separated tokens two model names share
function SharedTokens($a, $b) {
  $x = $a -split ' '; $y = $b -split ' '; $i = 0
  while ($i -lt $x.Count -and $i -lt $y.Count -and $x[$i] -eq $y[$i]) { $i++ }
  return $i
}

$map = @{}
foreach ($f in $fams) {
  $g = @($mods | Where-Object { $_.slug -eq $f.slug } | Sort-Object { [double]$_.airflow })

  # signature per model, from its own folder only
  $sig = @{}
  foreach ($m in $g) {
    $imgs = @($m.images) | Where-Object { $_ -and (-not $f.imgfilter -or (Split-Path $_ -Leaf) -match $f.imgfilter) }
    $h = @($imgs | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm MD5).Hash } | Sort-Object -Unique)
    $sig[$m.code] = @{ key = ($h -join '|'); files = $imgs }
  }
  $groups = @()   # ordered by first appearance, i.e. by the chip order
  foreach ($m in $g) {
    $k = $sig[$m.code].key
    if (-not $k) { continue }
    if (-not ($groups | Where-Object { $_.key -eq $k })) {
      $groups += ,[pscustomobject]@{ key = $k; files = $sig[$m.code].files }
    }
  }
  if ($groups.Count -lt 2) { continue }   # nothing to switch between

  # write each group's images
  $out = Join-Path $repo ('assets\img\products\' + $f.slug)
  $names = @{}
  for ($k = 0; $k -lt $groups.Count; $k++) {
    $seen = @{}; $pick = @()
    foreach ($p in ($groups[$k].files | Sort-Object @{e={Rank $_}}, { Split-Path $_ -Leaf })) {
      $h = (Get-FileHash -LiteralPath $p -Algorithm MD5).Hash
      if (-not $seen.ContainsKey($h)) { $seen[$h] = $true; $pick += $p }
      if ($pick.Count -ge $MAX) { break }
    }
    $written = @()
    for ($i = 0; $i -lt $pick.Count; $i++) {
      $name = if ($k -eq 0) { $BASE[$i] + '.avif' } else { 's' + ($k+1) + '-' + ($i+1) + '.avif' }
      & magick $pick[$i] -resize 1100x825 -background white -alpha remove -alpha off `
               -gravity center -extent 1100x825 -quality 50 (Join-Path $out $name)
      $written += $name
    }
    $names[$groups[$k].key] = $written
  }

  # model code -> its file list, with a sensible borrow for the photo-less
  $perModel = @{}
  foreach ($m in $g) {
    $k = $sig[$m.code].key
    if ($k) { $perModel[$m.code] = $names[$k]; continue }
    $best = $null; $bestN = -1
    foreach ($o in $g) {
      if (-not $sig[$o.code].key) { continue }
      $n = SharedTokens $m.model $o.model
      if ($n -gt $bestN) { $bestN = $n; $best = $o }
    }
    $perModel[$m.code] = if ($best) { $names[$sig[$best.code].key] } else { $names[$groups[0].key] }
  }
  $map[$f.slug] = $perModel
  Write-Host ("  {0,-18} {1} galleries for {2} models" -f $f.slug, $groups.Count, $g.Count)
}
$map | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $sp 'vortice-galleries.json') -Encoding UTF8
Write-Host ("pages with switching galleries: " + $map.Keys.Count)
