# Emtaş boilers: emtas.json is the one source, read by two steps.
#
#   2-images.ps1  takes the model records -- Emtaş is not in Biomi's price list
#                 workbook, so, like VIWA 125, its boilers are added here
#   3-pages.ps1   takes the spec rows, keyed by chip label like specs.json
#
# Sakra's sheets print output in kcal/h in the model number (EK3G-60 is a
# 60 000 kcal/h, 70 kW boiler), so every record carries its kW as .kw: the
# number in the name must never be read as an output here.
$EMTAS_NAME = 'Emtaş'
$EMTAS_TAIL = ' გათბობის ქვაბი EMTAŞ'

function Get-EmtasData {
  $j = Get-Content (Join-Path $PSScriptRoot 'emtas.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $models = New-Object System.Collections.ArrayList
  $specs  = @{}
  function Pair($ka, $en) { [pscustomobject]@{ ka = $ka; en = $en } }
  # 45000 -> "45,000"; the Georgian side takes a no-break space instead
  function Num($n) { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:N0}', [int]$n) }
  foreach ($r in $j.ranges) {
    # A figure the sheet leaves out for one size is shown as "-", so picking
    # that size does not leave the previous size's value in the table. A
    # figure no size in the range has is not a row at all.
    $has = @{}
    foreach ($k in 'kcal','w','d','h','w1','flue','conn','kg','l') {
      $has[$k] = [bool]@($r.models | Where-Object { $null -ne $_.$k }).Count
    }
    foreach ($m in $r.models) {
      [void]$models.Add([pscustomobject]@{
        brand = $EMTAS_NAME; code = ''; name = $m.mfr + $EMTAS_TAIL; mfr = $m.mfr
        country = 'თურქეთი'; dummy = $false; kit = $false; kw = [string]$m.kw })
      $s = [ordered]@{}
      if ($m.kcal) { $s.kcal = Pair (((Num $m.kcal) -replace ',', [string][char]0xA0) + ' კკალ/სთ') ((Num $m.kcal) + ' kcal/h') }
      $s.fuel = $j.fuel.($r.fuel)
      if ($r.feed) { $s.feed = $j.feed.($r.feed) }
      $s.passes = [string]$r.passes
      $s.press  = Pair ("$($r.bar) ბარი") ("$($r.bar) bar")
      if ($has.l)    { $s.water  = if ($null -ne $m.l)  { Pair "$($m.l) ლ"  "$($m.l) L" }   else { '-' } }
      if ($has.conn) { $s.conn   = if ($m.conn) { [string]$m.conn } else { '-' } }
      if ($has.flue) { $s.flue   = if ($m.flue) { Pair "Ø$($m.flue) მმ" "Ø$($m.flue) mm" } else { '-' } }
      if ($has.w -or $has.d -or $has.h) {
        $s.dims = if ($m.w -and $m.d -and $m.h) { $x = "$($m.w) × $($m.d) × $($m.h)"; Pair "$x მმ" "$x mm" } else { '-' }
      }
      if ($has.w1)   { $s.hopper = if ($m.w1) { Pair "$($m.w1) მმ" "$($m.w1) mm" } else { '-' } }
      if ($has.kg)   { $s.weight = if ($null -ne $m.kg) { Pair "$($m.kg) კგ" "$($m.kg) kg" } else { '-' } }
      $specs[[string]$m.mfr] = [pscustomobject]$s
    }
  }
  # family slug -> { ka = [...]; en = [...] }, listed beside the datasheet
  $features = @{}
  foreach ($p in $j.features.PSObject.Properties) { if ($p.Name -ne '_note') { $features[$p.Name] = $p.Value } }
  return @{ models = $models; specs = $specs; features = $features }
}
