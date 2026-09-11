# Join the two sources into one product structure.
#
#   families  = the library's top-level folders (the distributor's own grouping,
#               and what the site's pages are built around)
#   models    = rows from the technical price list, matched to a family by the
#               Vortice code appearing in one of that family's model subfolders
#   images    = the photos in that model's subfolder
#
# Models whose code has no subfolder are still kept: they appear as a size chip
# with full specs, just without their own photo. Losing them would leave gaps in
# the catalogue for no good reason.
. (Join-Path $PSScriptRoot 'config.ps1')
$root = $LIBRARY
$sp   = $PSScriptRoot
$models = (Get-Content (Join-Path $sp 'vortice-models.json') -Raw | ConvertFrom-Json) | Where-Object { $_.airflow }
# Models carried but not in the price list yet (the HRW heat recovery units),
# in the same fields -- see vortice-extra.json. The note row has no airflow and
# drops out with the same filter.
$extra = Join-Path $sp 'vortice-extra.json'
if (Test-Path $extra) {
  # Parenthesised before the pipe: ConvertFrom-Json hands the whole JSON array
  # down the pipeline as one object, so without them the seven rows arrived as a
  # single "model" whose fields were arrays.
  $models = @($models) + @((Get-Content $extra -Raw -Encoding UTF8 | ConvertFrom-Json) | Where-Object { $_.airflow })
}

# Matched loosely, not by exact name: the off-limits folder has been renamed
# once already ("... DO NOT TOUCH CLAUDE"), and an exact-match skip silently
# stops skipping when that happens.
$fams = Get-ChildItem $root -Directory | Where-Object {
  $n = $_.Name
  -not ($n -like '*DO NOT TOUCH*' -or $n -like 'კატალოგები*' -or $n -like 'აქსესუარები*')
}

# code -> family folder, via the model subfolders
$codeToFam = @{}
$codeToDir = @{}
foreach ($f in $fams) {
  foreach ($sub in Get-ChildItem $f.FullName -Directory -ErrorAction SilentlyContinue) {
    $m = [regex]::Match($sub.Name, '^\s*(\d{4,6})\b')
    if ($m.Success) { $codeToFam[$m.Groups[1].Value] = $f.Name; $codeToDir[$m.Groups[1].Value] = $sub.FullName }
  }
  # some families keep their photos loose in the family folder
  $m = [regex]::Match($f.Name, '^\s*(\d{4,6})\b')
  if ($m.Success) { $codeToFam[$m.Groups[1].Value] = $f.Name; $codeToDir[$m.Groups[1].Value] = $f.FullName }
}

$out = New-Object System.Collections.ArrayList
foreach ($m in $models) {
  $fam = $codeToFam[$m.code]
  $dir = $codeToDir[$m.code]
  $imgs = @()
  if ($dir) {
    # -Recurse: the lifestyle shots now sit in a "საიმიჯო" subfolder inside each
    # model folder, so a flat listing would quietly drop them and change which
    # models look alike.
    $imgs = @()
    foreach ($ext in '*.png','*.jpg') {
      $imgs += Get-ChildItem -LiteralPath $dir -File -Filter $ext -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
    $imgs = $imgs | Sort-Object
  }
  [void]$out.Add([pscustomobject]@{
    code=$m.code; model=$m.model; sheet=$m.sheet; catKa=$m.category; link=$m.link
    airflow=$m.airflow; watts=$m.watts; diameter=$m.diameter; db=$m.db
    family=$fam; imgCount=$imgs.Count; images=$imgs
  })
}
$out | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $sp 'vortice-final.json') -Encoding UTF8

Write-Host ("models: " + $out.Count)
Write-Host ("  matched to a family folder : " + ($out | Where-Object { $_.family }).Count)
Write-Host ("  with at least one image    : " + ($out | Where-Object { $_.imgCount -gt 0 }).Count)
Write-Host ''
$out | Where-Object { $_.family } | Group-Object family | Sort-Object Count -Descending | ForEach-Object {
  $withImg = ($_.Group | Where-Object { $_.imgCount -gt 0 }).Count
  $n = $_.Name; if ($n.Length -gt 46) { $n = $n.Substring(0,46) }
  Write-Host ("  {0,3} models ({1,2} w/ images)  {2}" -f $_.Count, $withImg, $n)
}
$orphans = $out | Where-Object { -not $_.family }
Write-Host ''
Write-Host ("unmatched to any family: " + $orphans.Count)
$orphans | Group-Object sheet | ForEach-Object { Write-Host ("   {0,-26} {1}" -f $_.Name, $_.Count) }
