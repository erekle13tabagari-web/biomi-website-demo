# Which Vortice models actually have their own photography?
#
# Each model is reduced to a signature: the sorted hashes of the images in its
# own library folder. Models sharing a signature are the same photographs, so
# they must keep sharing one gallery -- the library reuses files heavily (the
# whole MF folder is one model's shots, and "Pink Gold" is byte-identical to
# the ivory unit). Where a page turns out to hold more than one signature, the
# gallery genuinely should change as you pick models.
$sp   = $PSScriptRoot
$mods = Get-Content (Join-Path $sp 'vortice-pages.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$fams = Get-Content (Join-Path $sp 'vortice-families.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$out = New-Object System.Collections.ArrayList
foreach ($m in $mods) {
  $fam = $fams | Where-Object { $_.slug -eq $m.slug }
  $imgs = @($m.images) | Where-Object { $_ -and (-not $fam.imgfilter -or (Split-Path $_ -Leaf) -match $fam.imgfilter) }
  $hashes = @($imgs | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm MD5).Hash } | Sort-Object -Unique)
  [void]$out.Add([pscustomobject]@{
    slug=$m.slug; code=$m.code; model=$m.model
    sig = if ($hashes.Count) { ($hashes -join '|') } else { '' }
    files = ($imgs -join '|'); n = $hashes.Count
  })
}
$out | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'vortice-imgsets.json') -Encoding UTF8

foreach ($f in $fams) {
  $g = @($out | Where-Object { $_.slug -eq $f.slug })
  $withImgs = @($g | Where-Object { $_.sig })
  $distinct = @($withImgs | Group-Object sig)
  $tag = if ($distinct.Count -gt 1) { '  <-- SWITCHES' } else { '' }
  Write-Host ("{0,-18} {1,2} models, {2,2} with photos, {3} distinct set(s){4}" -f $f.slug, $g.Count, $withImgs.Count, $distinct.Count, $tag)
  if ($distinct.Count -gt 1) {
    $i = 0
    foreach ($d in $distinct) {
      $i++
      Write-Host ("      set $i ({0} imgs): {1}" -f $d.Group[0].n, (($d.Group | ForEach-Object { $_.model }) -join ' / '))
    }
    $noImg = @($g | Where-Object { -not $_.sig })
    if ($noImg.Count) { Write-Host ("      no photos    : " + (($noImg | ForEach-Object { $_.model }) -join ' / ')) }
  }
}
