# Pull the water-heater list out of the "ბოილერები" sheet of "Products with Codes".
#
# Same shape as the boiler sheet: brands laid side by side rather than stacked,
# each block being (#, internal code, name, manufacturer code, country). Three
# blocks here -- Beretta in A-E, Riello in G-K, Omega in M-Q.
#
# Riello is a special case: its name column already carries the manufacturer
# code as a prefix ("20052377 ბოილერი 7200.200NV RIELLO"), and its code column
# holds an unrelated number, so the prefix is stripped for display.
#
# The sheet mixes real products with filler rows -- a row whose "name" is just
# the row number is an empty template line, not a product.
$sp   = $PSScriptRoot
$xlsx = Join-Path $sp 'products-codes.xlsx'
$SHEET = 'ბოილერები'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($xlsx)
function RE($n){ $e=$zip.Entries|Where-Object{$_.FullName -eq $n}; if(-not $e){return $null}
  $sr=New-Object IO.StreamReader($e.Open()); $s=$sr.ReadToEnd(); $sr.Close(); $s }

$rels = @{}
foreach ($m in [regex]::Matches((RE 'xl/_rels/workbook.xml.rels'),'Id="(rId\d+)"[^>]*Target="([^"]+)"')) {
  $rels[$m.Groups[1].Value] = $m.Groups[2].Value
}
$target = $null
foreach ($m in [regex]::Matches((RE 'xl/workbook.xml'),'<sheet name="([^"]+)"[^>]*r:id="(rId\d+)"')) {
  if ($m.Groups[1].Value -eq $SHEET) { $target = $rels[$m.Groups[2].Value] }
}
if (-not $target) { throw "sheet '$SHEET' not found in $xlsx" }
$xml = RE ('xl/' + ($target -replace '^/xl/',''))
$ss = [regex]::Matches((RE 'xl/sharedStrings.xml'),'(?s)<si>(.*?)</si>') | ForEach-Object {
  (([regex]::Matches($_.Groups[1].Value,'<t[^>]*>(.*?)</t>')|ForEach-Object{$_.Groups[1].Value}) -join '') }

# read the sheet into cell[row][col]
$cell = @{}
foreach ($rm in [regex]::Matches($xml,'(?s)<row r="(\d+)"[^>]*>(.*?)</row>')) {
  $r = [int]$rm.Groups[1].Value
  $cell[$r] = @{}
  foreach ($cm in [regex]::Matches($rm.Groups[2].Value,'(?s)<c r="([A-Z]+)\d+"([^>]*)>(.*?)</c>')) {
    $v = [regex]::Match($cm.Groups[3].Value,'<v>(.*?)</v>').Groups[1].Value
    if (-not $v) { continue }
    if ($cm.Groups[2].Value -match 't="s"') { $v = $ss[[int]$v] }
    $cell[$r][$cm.Groups[1].Value] = $v
  }
}

$BLOCKS = @(
  @{ brand='Beretta'; code='B'; name='C'; mfr='D'; country='E' },
  @{ brand='Riello';  code='H'; name='I'; mfr='J'; country='K' },
  @{ brand='Omega';   code='N'; name='O'; mfr='P'; country='Q' }
)

$rows = New-Object System.Collections.ArrayList
foreach ($b in $BLOCKS) {
  foreach ($r in ($cell.Keys | Sort-Object)) {
    if ($r -lt 3) { continue }
    $name = $cell[$r][$b.name]
    if (-not $name) { continue }
    # a filler line: the name cell just repeats the row counter
    if ($name -match '^\s*\d+\s*$') { continue }
    $mfr = $cell[$r][$b.mfr]
    # Riello prefixes the manufacturer code onto the name
    if ($mfr -and $name.StartsWith($mfr)) { $name = $name.Substring($mfr.Length).Trim() }
    [void]$rows.Add([pscustomobject]@{
      brand   = $b.brand
      code    = $cell[$r][$b.code]
      name    = ($name -replace '\s+',' ').Trim()
      mfr     = $mfr
      country = $cell[$r][$b.country]
    })
  }
}
$zip.Dispose()
$rows | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'water-heaters.json') -Encoding UTF8
Write-Host ("water heaters: " + $rows.Count)
$rows | Group-Object brand | ForEach-Object { Write-Host ("  {0,-10} {1,2}" -f $_.Name, $_.Count) }
