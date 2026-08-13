# Assign every priced model to exactly one page, by model-name prefix.
#
# Prefix beats folder here: the distributor filed CA 315 MD E W/E RF under the
# roof-fan sheet, and 24 models have no library subfolder at all. The model name
# is the one field that is always right, so it decides the page.
$sp = $PSScriptRoot
$models = Get-Content (Join-Path $sp 'vortice-final.json')    -Raw -Encoding UTF8 | ConvertFrom-Json
$fams   = Get-Content (Join-Path $sp 'vortice-families.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$multi = @(); $none = @()
foreach ($m in $models) {
  $hits = @($fams | Where-Object { $m.model -match $_.match })
  if     ($hits.Count -eq 0) { $none  += $m.model }
  elseif ($hits.Count -gt 1) { $multi += ($m.model + ' -> ' + (($hits | ForEach-Object { $_.slug }) -join ', ')) }
  $m | Add-Member -NotePropertyName slug -NotePropertyValue $(if ($hits.Count -ge 1) { $hits[0].slug } else { '' }) -Force
}

Write-Host ("models: " + $models.Count)
Write-Host ("unassigned: " + $none.Count); $none | ForEach-Object { Write-Host ("   ! " + $_) }
Write-Host ("ambiguous : " + $multi.Count); $multi | ForEach-Object { Write-Host ("   ! " + $_) }
Write-Host ''
foreach ($f in $fams) {
  $g = @($models | Where-Object { $_.slug -eq $f.slug })
  $wi = @($g | Where-Object { $_.imgCount -gt 0 }).Count
  Write-Host ("  {0,-18} {1,2} models, {2,2} with own photos" -f $f.slug, $g.Count, $wi)
}
$models | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $sp 'vortice-pages.json') -Encoding UTF8
