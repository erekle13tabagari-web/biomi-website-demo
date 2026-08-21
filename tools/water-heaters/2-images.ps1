# Assign each water heater to a page, then build that page's gallery.
#
# The library was organised to match this pipeline: usable product shots sit at
# the family folder root, while documents, lifestyle imagery and working files
# live in საბუთები / საიმიჯო / "სხვა სურათები DONT TOUCH CLAUDE" subfolders.
# Those are excluded by comparing whole path segments rather than by matching a
# regex against the full path -- the folder names are Georgian and the
# separators are backslashes, which together make a path regex hard to read and
# easy to get wrong.
#
# Omega has a subfolder per litre size holding that size's own render, so those
# become per-model images the chips switch to. The 1000/1500/2000 litre sizes
# have no photography and fall back to the family shot, which is honest: they
# are the same tank in another size.
#
# ECSB, AKM and OBF have no photography at all and get the shared placeholder
# rather than a broken image or one borrowed from a different product.
. (Join-Path $PSScriptRoot 'config.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'families.json')      -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'water-heaters.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$NAMES = @('main','front','angle','detail','room')
$SEP = [IO.Path]::DirectorySeparatorChar
$EXT = @('.png','.jpg','.jpeg','.avif')
$SKIP = @('საბუთები','საბუთბი','საიმიჯო')
$PLACEHOLDER = [IO.Path]::Combine($repo,'assets','img','products','_placeholder.avif')

$unassigned = @()
foreach ($m in $mods) {
  $hit = $null
  foreach ($f in $fams) { if ($m.name -match $f.match) { $hit = $f.slug; break } }
  if (-not $hit) { $unassigned += $m.name }
  $m | Add-Member -NotePropertyName slug -NotePropertyValue $hit -Force
}
Write-Host ("water heaters: " + $mods.Count + "   unassigned: " + $unassigned.Count)
$unassigned | ForEach-Object { Write-Host ("   ! " + $_) }

function Allowed($full) {
  foreach ($seg in $full.Split($SEP)) {
    if ($SKIP -contains $seg) { return $false }
    if ($seg -like 'სხვა*') { return $false }
    if ($seg -like '*DONT TOUCH*' -or $seg -like '*DO NOT TOUCH*') { return $false }
  }
  return $true
}
function Rank($p) {
  $n = Split-Path $p -Leaf
  if ($n -match 'შიდა კომპონენტები') { return 3 }
  if ($n -match 'წინხედი')           { return 0 }
  if ($n -match 'გვერდხედი')         { return 2 }
  return 1
}
function Pool($dirs) {
  $out = @()
  foreach ($d in $dirs) {
    $full   = [IO.Path]::Combine($LIBRARY, $d)
    $parent = Split-Path $full -Parent
    $leaf   = Split-Path $full -Leaf
    foreach ($cand in (Get-ChildItem -LiteralPath $parent -Directory -EA SilentlyContinue |
                       Where-Object { $_.Name.StartsWith($leaf) })) {
      $out += Get-ChildItem -LiteralPath $cand.FullName -File -Recurse -EA SilentlyContinue |
              Where-Object { $EXT -contains $_.Extension.ToLower() -and (Allowed $_.FullName) }
    }
  }
  return $out
}
function Emit($src, $dst) {
  & magick $src -resize 1100x825 -background white -alpha remove -alpha off `
           -gravity center -extent 1100x825 -quality 50 $dst
}

$ALLGAL = @{}
$report = New-Object System.Collections.ArrayList
foreach ($f in $fams) {
  $out = [IO.Path]::Combine($repo,'assets','img','products',$f.slug)
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $g    = @($mods | Where-Object { $_.slug -eq $f.slug })
  $pool = @(Pool $f.imgdirs)

  # per-model images, where a subfolder is named after the model's own code:
  # "ESB100" is filed as "ESB 100", so both sides drop spaces before comparing
  $galleries = @{}
  $k = 0
  foreach ($m in $g) {
    if (-not $m.mfr) { continue }
    $key = ($m.mfr -replace '[\s_-]','').ToUpper()
    $own = @($pool | Where-Object {
             ((Split-Path (Split-Path $_.FullName -Parent) -Leaf) -replace '[\s_-]','').ToUpper() -eq $key })
    if (-not $own.Count) { continue }
    $k++
    $mnames = @()   # NOT $names: PowerShell is case-insensitive and that would clobber $NAMES
    for ($i = 0; $i -lt $own.Count -and $i -lt 3; $i++) {
      $nm = 'm' + $k + '-' + ($i+1) + '.avif'
      Emit $own[$i].FullName (Join-Path $out $nm)
      $mnames += $nm
    }
    $galleries[$m.name] = $mnames
  }

  $seen = @{}; $pick = @()
  foreach ($p in ($pool | Sort-Object @{e={Rank $_.FullName}}, Name)) {
    $h = (Get-FileHash -LiteralPath $p.FullName -Algorithm MD5).Hash
    if ($seen.ContainsKey($h)) { continue }
    $seen[$h] = $true; $pick += $p.FullName
    if ($pick.Count -ge $NAMES.Count) { break }
  }
  $written = @()
  if ($pick.Count) {
    for ($i = 0; $i -lt $pick.Count; $i++) { Emit $pick[$i] (Join-Path $out ($NAMES[$i] + '.avif')); $written += $NAMES[$i] }
  } else {
    Copy-Item -LiteralPath $PLACEHOLDER -Destination (Join-Path $out 'main.avif') -Force
    $written += 'placeholder'
  }
  if ($galleries.Keys.Count) { $ALLGAL[$f.slug] = $galleries }
  [void]$report.Add([pscustomobject]@{ slug=$f.slug; models=$g.Count; pooled=$pool.Count
                                       perModel=$galleries.Keys.Count; imgs=($written -join ',') })
}
$mods   | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'wh-pages.json')     -Encoding UTF8
$ALLGAL | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $sp 'wh-galleries.json') -Encoding UTF8
$report | ForEach-Object { Write-Host ("  {0,-18} {1,2} models  pooled {2,2}  per-model {3,2}  -> {4}" -f $_.slug,$_.models,$_.pooled,$_.perModel,$_.imgs) }
