# Build the AVIF gallery for each Vortice page.
#
# Photos are chosen per page, not per model: within a range the units are the
# same product in different sizes, and the library confirms it -- several model
# folders hold byte-identical files. So everything is pooled, de-duplicated by
# hash, and the best five kept.
#
# Order matters, because the first image becomes the card thumbnail:
#   1. the numbered PNG studio shots on white   (_01.png, _02.png ...)
#   2. the gallery JPGs (detail shots)
#   3. the ambiente JPGs (in-room photography)
$root = 'C:\Users\Designer\Desktop\2026\პროდუქტები\ვენტილაცია\Vortice'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'vortice-families.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$NAMES = @('main','front','angle','detail','room')

function Rank($f) {
  if ($f.Extension -eq '.png')      { return 0 }
  if ($f.Name -match 'gallery')     { return 1 }
  return 2
}

$report = New-Object System.Collections.ArrayList
foreach ($fam in $fams) {
  # pool every photo under every source folder for this page
  # imgfilter guards against mis-stocked folders: the MF folder holds only
  # code 11110's photos, which are the MG (Punto Ghost), and the real MF
  # (Punto Filo) shots sit in the MFO folder. The filename carries the product
  # line, so it is what decides -- not the folder it happens to sit in.
  $pool = @()
  foreach ($d in $fam.imgdirs) {
    foreach ($dir in Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name.StartsWith($d) }) {
      $pool += Get-ChildItem -LiteralPath $dir.FullName -File -Recurse -EA SilentlyContinue |
               Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' } |
               Where-Object { -not $fam.imgfilter -or $_.Name -match $fam.imgfilter }
    }
  }
  # de-duplicate: keep the first occurrence of each distinct image
  $seen = @{}; $uniq = @()
  foreach ($f in ($pool | Sort-Object @{e={Rank $_}}, Name)) {
    $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash
    if (-not $seen.ContainsKey($h)) { $seen[$h] = $true; $uniq += $f }
  }
  $pick = $uniq | Select-Object -First $NAMES.Count

  $out = Join-Path $repo ("assets\img\products\" + $fam.slug)
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $i = 0; $written = @()
  foreach ($f in $pick) {
    $dst = Join-Path $out ($NAMES[$i] + '.avif')
    & magick $f.FullName -resize 1100x825 -background white -alpha remove -alpha off `
             -gravity center -extent 1100x825 -quality 50 $dst
    if (Test-Path $dst) { $written += $NAMES[$i] }
    $i++
  }
  [void]$report.Add([pscustomobject]@{ slug=$fam.slug; pooled=$pool.Count; unique=$uniq.Count; written=($written -join ',') })
}
$report | ForEach-Object { Write-Host ("  {0,-18} pooled {1,3}  unique {2,3}  -> {3}" -f $_.slug, $_.pooled, $_.unique, $_.written) }
