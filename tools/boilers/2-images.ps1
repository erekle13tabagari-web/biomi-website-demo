# Assign each boiler to a page, then build that page's gallery.
#
# Series first, longest/most specific pattern first, because the Warmhaus names
# overlap: "LAWA PLUS 24" and "LAWA SYSTEM 24" both contain "LAWA", and
# "VIWA S 100" contains "VIWA". Order in families.json decides.
#
# The photo folders are grouped by output, not by product -- one
# "Lawa 24_HO 24 SYSTEM_SYSTEM 24" folder serves three separate boilers -- so a
# gallery belongs to the page, and several products legitimately share it.
. (Join-Path $PSScriptRoot 'config.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'families.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'boilers.json')  -Raw -Encoding UTF8 | ConvertFrom-Json
$NAMES = @('main','front','angle','detail','room')

# VIWA 125 and VIWA 150 are in the photo library and referenced by accessories,
# but missing from the price list. Added here so the range is not full of holes.
foreach ($m in @('VIWA 125','VIWA 150')) {
  if (-not ($mods | Where-Object { $_.name -match [regex]::Escape($m) -and $_.name -notmatch 'VIWA S' })) {
    $mods += [pscustomobject]@{ brand='Warmhaus'; code=''; name="$m გათბობის ქვაბი WARMHAUS"
                                mfr=$m; country='თურქეთი'; dummy=$false; kit=$false }
  }
}

# ---- collapse the Warmhaus kit/plain pairs
# Most Warmhaus boilers appear twice: a "(კომპლექტში)" kit SKU and a plain one,
# different internal codes but the same boiler. One product, both codes. The
# workbook only fills manufacturer code and country on the kit row, so the
# merged record keeps whichever row actually has them.
$merged = @{}; $ordered = New-Object System.Collections.ArrayList
foreach ($m in $mods) {
  $key = ($m.name -replace '\(კომპლექტში\)','' -replace '\s+',' ').Trim()
  if ($merged.ContainsKey($key)) {
    $e = $merged[$key]
    if ($m.code -and $e.code -notmatch $m.code) { $e.code = ($e.code + ' / ' + $m.code) }
    if (-not $e.mfr     -and $m.mfr)     { $e.mfr = $m.mfr }
    if (-not $e.country -and $m.country) { $e.country = $m.country }
    continue
  }
  $c = $m.PSObject.Copy(); $c.name = $key
  $merged[$key] = $c; [void]$ordered.Add($c)
}
$mods = $ordered

# ---- assign each boiler to exactly one page
$unassigned = @()
foreach ($m in $mods) {
  $hit = $null
  foreach ($f in $fams) { if ($m.name -match $f.match) { $hit = $f.slug; break } }
  if (-not $hit) { $unassigned += $m.name }
  $m | Add-Member -NotePropertyName slug -NotePropertyValue $hit -Force
}
Write-Host ("boilers: " + $mods.Count + "   unassigned: " + $unassigned.Count)
$unassigned | ForEach-Object { Write-Host ("   ! " + $_) }

# ---- gallery per page
# $script:First is the family's optional "imgfirst": naming conventions cannot
# settle every case, so a page may nominate its own lead shot by filename.
function Rank($p) {
  $n = Split-Path $p -Leaf
  if ($script:First -and $n -match $script:First) { return -1 }
  # Cutaways are tested FIRST: "შიდა კომპონენტები წინხედი(რენდერი)" also contains
  # წინხედი, so testing the front view first made the cutaway the card thumbnail.
  if ($n -match 'შიდა კომპონენტები') { return 3 }
  if ($n -match 'წინხედი')           { return 0 }
  if ($n -match 'გვერდხედი')         { return 2 }
  return 1   # the file named after the model - the clean product shot
}
$report = New-Object System.Collections.ArrayList
foreach ($f in $fams) {
  $pool = @()
  foreach ($d in $f.imgdirs) {
    $dir = Join-Path $LIBRARY $d
    $parent = Split-Path $dir -Parent
    $leaf = Split-Path $dir -Leaf
    foreach ($cand in (Get-ChildItem -LiteralPath $parent -Directory -EA SilentlyContinue |
                       Where-Object { $_.Name.StartsWith($leaf) })) {
      $pool += Get-ChildItem -LiteralPath $cand.FullName -File -Recurse -EA SilentlyContinue |
               Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' -and
                              $_.FullName -notmatch 'DONT TOUCH|DO NOT TOUCH' -and
                              $_.FullName -notmatch '_BLACK' -and
                              $_.FullName -notmatch '\\(საბუთები|საბუთბი|საიმიჯო|სხვა[^\\]*)\\' }
    }
  }
  $script:First = $f.imgfirst
  $seen = @{}; $pick = @()
  foreach ($p in ($pool | Sort-Object @{e={Rank $_.FullName}}, Name)) {
    $h = (Get-FileHash -LiteralPath $p.FullName -Algorithm MD5).Hash
    if ($seen.ContainsKey($h)) { continue }
    $seen[$h] = $true; $pick += $p.FullName
    if ($pick.Count -ge $NAMES.Count) { break }
  }
  $out = Join-Path $repo ('assets\img\products\' + $f.slug)
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $written = @()
  for ($i = 0; $i -lt $pick.Count; $i++) {
    & magick $pick[$i] -resize 1100x825 -background white -alpha remove -alpha off `
             -gravity center -extent 1100x825 -quality 50 (Join-Path $out ($NAMES[$i] + '.avif'))
    $written += ($NAMES[$i] + '.avif')
  }
  $n = @($mods | Where-Object { $_.slug -eq $f.slug }).Count
  [void]$report.Add([pscustomobject]@{ slug=$f.slug; models=$n; pooled=$pool.Count; imgs=($written -join ',') })
}
# ---- LAWA black finish
# "LAWA 18 BLACK" is the same boiler in a black body, not another model, and the
# library has genuine black photography for it. Its images go out under a
# black- prefix so the page can offer a finish switch instead of a second chip.
$blackSrc = Join-Path $LIBRARY 'Warmhous\Lawa 18\Lawa 18_BLACK'
if (Test-Path -LiteralPath $blackSrc) {
  $out = Join-Path $repo 'assets\img\products\warmhaus-lawa'
  $bi = 0
  foreach ($img in (Get-ChildItem -LiteralPath $blackSrc -File |
                    Where-Object { $_.Extension -match '^\.(png|jpg)$' } |
                    Sort-Object @{e={ if ($_.Name -match 'წინხედი|Lawa') {0} else {1} }}, Name)) {
    $bi++
    & magick $img.FullName -resize 1100x825 -background white -alpha remove -alpha off `
             -gravity center -extent 1100x825 -quality 50 (Join-Path $out ("black-$bi.avif"))
  }
  Write-Host ("  warmhaus-lawa        black finish -> $bi image(s)")
}
$mods | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'boilers-pages.json') -Encoding UTF8
$report | ForEach-Object { Write-Host ("  {0,-22} {1,2} models  pooled {2,3}  -> {3}" -f $_.slug,$_.models,$_.pooled,$_.imgs) }
