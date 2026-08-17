# Per-model galleries.
#
# Each boiler carries its own name printed on the control panel -- a LAWA 32
# photo says "Lawa 32" -- so the models in a range are NOT interchangeable
# visually and cannot share one gallery. Where a model has its own folder, its
# own photographs go out under m<n>-*.avif and the chip switches to them.
#
# Matching prefers the folder that actually holds images: a series folder like
# "Viwa 50_65" also starts with "Viwa 50", and would otherwise shadow the real
# "Viwa 50" folder while contributing nothing.
. (Join-Path $PSScriptRoot 'config.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'families.json')      -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'boilers-pages.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$dirs = Get-ChildItem -LiteralPath $LIBRARY -Directory -Recurse |
        Where-Object { $_.FullName -notmatch 'DONT TOUCH|DO NOT TOUCH|საბუთ|საიმიჯო|სხვა|_BLACK' }
function Norm($s) { ($s -replace '[\s_-]+',' ').Trim() }
function ShortName($n) {
  ($n -replace '\s*გათბობის ქვაბი.*$','' -replace '^\d{6,}\s+','' -replace 'CALDAIA\s+','' -replace '\s+MTN$','').Trim()
}
function Rank($p) {
  $n = Split-Path $p -Leaf
  # cutaways first: "შიდა კომპონენტები წინხედი(რენდერი)" contains წინხედი too,
  # so testing the front view first made the cutaway the card thumbnail
  if ($n -match 'შიდა კომპონენტები') { return 3 }
  if ($n -match 'წინხედი')           { return 0 }
  if ($n -match 'გვერდხედი')         { return 1 }
  return 2
}

$map = @{}
foreach ($f in $fams) {
  $g = @($mods | Where-Object { $_.slug -eq $f.slug })
  $perModel = @{}
  $groups = @()   # distinct image sets, in chip order
  foreach ($m in $g) {
    $key = Norm (ShortName $m.name)
    # candidates whose folder name starts with the model name; the one with the
    # most images wins, so a series folder cannot shadow the model's own
    # A prefix match is not enough: "Lawa 24_Plus" also starts with "Lawa 24",
    # and LAWA PLUS 24 is a different boiler, not a photo of LAWA 24. Reject a
    # folder that carries a variant word the model itself does not.
    $VARIANT = 'PLUS','BLACK'
    $cand = @($dirs | Where-Object {
                $fn = Norm $_.Name
                if ($fn -notmatch ('^' + [regex]::Escape($key) + '(\b|$)')) { return $false }
                foreach ($v in $VARIANT) {
                  if ($fn -match "\b$v\b" -and $key -notmatch "\b$v\b") { return $false }
                }
                return $true
              } |
              ForEach-Object {
                $imgs = @(Get-ChildItem -LiteralPath $_.FullName -File |
                          Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' })
                [pscustomobject]@{ dir=$_; n=$imgs.Count; files=@($imgs | ForEach-Object { $_.FullName }) }
              } | Sort-Object -Property @{e='n';d=$true}, @{e={ (Norm $_.dir.Name).Length }} )
    $best = $cand | Where-Object { $_.n -gt 0 } | Select-Object -First 1
    # Fallback on series + output. The SYSTEM variants are named "LAWA SYSTEM 24"
    # and "LAWA HO 24 SYSTEM" while their folder is "Lawa 24_HO 24 SYSTEM_..." --
    # no prefix match, though they are the same 24 kW body. Retry with the first
    # word and the first number, which is how the folders are actually named.
    if (-not $best) {
      $num = [regex]::Match($key,'\b(\d{2,3})\b')
      $first = ($key -split ' ')[0]
      if ($num.Success -and $first) {
        $alt = "$first $($num.Groups[1].Value)"
        $best = @($dirs | Where-Object {
                    $fn = Norm $_.Name
                    if ($fn -notmatch ('^' + [regex]::Escape($alt) + '(\b|$)')) { return $false }
                    foreach ($v in $VARIANT) {
                      if ($fn -match "\b$v\b" -and $key -notmatch "\b$v\b") { return $false }
                    }
                    return $true
                  } | ForEach-Object {
                    $imgs = @(Get-ChildItem -LiteralPath $_.FullName -File |
                              Where-Object { $_.Extension -match '^\.(png|jpg|jpeg)$' })
                    [pscustomobject]@{ dir=$_; n=$imgs.Count; files=@($imgs | ForEach-Object { $_.FullName }) }
                  } | Where-Object { $_.n -gt 0 } |
                  Sort-Object -Property @{e='n';d=$true} | Select-Object -First 1)
      }
    }
    if (-not $best) { continue }
    $hashes = @($best.files | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm MD5).Hash } | Sort-Object -Unique)
    $sig = ($hashes -join '|')
    $existing = $groups | Where-Object { $_.sig -eq $sig } | Select-Object -First 1
    if (-not $existing) {
      $groups += ,[pscustomobject]@{ sig=$sig; files=$best.files; names=@() }
      $existing = $groups[-1]
    }
    $perModel[$m.name] = $existing
  }
  if ($groups.Count -lt 2) { continue }   # one set for the whole range: nothing to switch

  $out = Join-Path $repo ('assets\img\products\' + $f.slug)
  for ($k = 0; $k -lt $groups.Count; $k++) {
    $seen = @{}; $pick = @()
    foreach ($p in ($groups[$k].files | Sort-Object @{e={Rank $_}}, { Split-Path $_ -Leaf })) {
      $h = (Get-FileHash -LiteralPath $p -Algorithm MD5).Hash
      if ($seen.ContainsKey($h)) { continue }
      $seen[$h] = $true; $pick += $p
      if ($pick.Count -ge 5) { break }
    }
    $written = @()
    for ($i = 0; $i -lt $pick.Count; $i++) {
      $nm = 'm' + ($k+1) + '-' + ($i+1) + '.avif'
      & magick $pick[$i] -resize 1100x825 -background white -alpha remove -alpha off `
               -gravity center -extent 1100x825 -quality 50 (Join-Path $out $nm)
      $written += $nm
    }
    $groups[$k].names = $written
  }
  $out2 = @{}
  foreach ($k in $perModel.Keys) { $out2[$k] = $perModel[$k].names }
  $map[$f.slug] = $out2
  Write-Host ("  {0,-22} {1} model galleries for {2} models" -f $f.slug, $groups.Count, $g.Count)
}
$map | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $sp 'boilers-galleries.json') -Encoding UTF8
Write-Host ("pages with per-model galleries: " + $map.Keys.Count)
