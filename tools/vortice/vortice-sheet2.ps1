# Read the Vortice technical price list with explicit per-sheet columns.
#
# Content-detection was clever and wrong: it silently produced empty model
# names for 21 of 94 rows. The layouts are known and stable, so they are just
# declared here. Sheets 1 and 2 are price lists with no specs and are skipped.
. (Join-Path $PSScriptRoot 'config.ps1')
$xlsx = $PRICELIST
$sp   = $PSScriptRoot

# sheet index -> column letters. Only the CA sheet is shifted.
$COLS = @{
  3 = @{ code='B'; model='C'; link='E'; spec='F'; cat='A' }   # გამწოვი
  4 = @{ code='B'; model='C'; link='E'; spec='F'; cat='A' }   # რეკუპ.
  5 = @{ code='B'; model='C'; link='E'; spec='F'; cat='A' }   # სახურავის
  6 = @{ code='C'; model='D'; link='F'; spec='G'; cat='A' }   # CA
  7 = @{ code='B'; model='C'; link='E'; spec='F'; cat='A' }   # LINEO
  8 = @{ code='B'; model='C'; link='E'; spec='F'; cat='A' }   # QBK
  9 = @{ code='B'; model='C'; link='E'; spec='F'; cat='A' }   # C-CMS
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($xlsx)
function RE($n){ $e=$zip.Entries|Where-Object{$_.FullName -eq $n}; if(-not $e){return $null}; $sr=New-Object IO.StreamReader($e.Open()); $s=$sr.ReadToEnd(); $sr.Close(); $s }
$ss = [regex]::Matches((RE 'xl/sharedStrings.xml'),'(?s)<si>(.*?)</si>') | ForEach-Object {
        (([regex]::Matches($_.Groups[1].Value,'<t[^>]*>(.*?)</t>') | ForEach-Object { $_.Groups[1].Value }) -join '') }
$names = [regex]::Matches((RE 'xl/workbook.xml'),'<sheet name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

$rows = New-Object System.Collections.ArrayList
foreach ($i in $COLS.Keys) {
  $sx = RE ("xl/worksheets/sheet$i.xml"); if (-not $sx) { continue }
  $c = $COLS[$i]; $sheet = $names[$i-1]
  foreach ($r in [regex]::Matches($sx,'(?s)<row[^>]*r="(\d+)"[^>]*>(.*?)</row>')) {
    $cell = @{}
    foreach ($cc in [regex]::Matches($r.Groups[2].Value,'(?s)<c r="([A-Z]+)\d+"(?:[^>]*t="(\w+)")?[^>]*>(?:<v>(.*?)</v>)?')) {
      $v = $cc.Groups[3].Value
      if ($cc.Groups[2].Value -eq 's' -and $v -ne '') { $v = $ss[[int]$v] }
      if ($v) { $cell[$cc.Groups[1].Value] = $v }
    }
    $code = $cell[$c.code]
    if (-not $code -or $code -notmatch '^\d{4,6}$') { continue }
    $spec = $cell[$c.spec]
    if (-not $spec -or $spec -notmatch 'Max airflow') { continue }
    $air=''; $watt=''; $dia=''; $db=''
    $m=[regex]::Match($spec,'airflow[^\d-]*-\s*([\d.,]+)');  if($m.Success){$air =$m.Groups[1].Value -replace ',','.'}
    $m=[regex]::Match($spec,'power[^\d-]*-\s*([\d.,]+)');    if($m.Success){$watt=$m.Groups[1].Value -replace ',','.'}
    $m=[regex]::Match($spec,'diameter[^\d-]*-\s*([\d.,]+)'); if($m.Success){$dia =$m.Groups[1].Value -replace ',','.'}
    $m=[regex]::Match($spec,'(?i)sound[^\d-]*-\s*([\d.,]+)');if($m.Success){$db  =$m.Groups[1].Value -replace ',','.'}
    [void]$rows.Add([pscustomobject]@{
      sheet=$sheet; category=$cell[$c.cat]; code=$code; model=$cell[$c.model]
      link=$cell[$c.link]; airflow=$air; watts=$watt; diameter=$dia; db=$db
    })
  }
}
$zip.Dispose()
$rows | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'vortice-models.json') -Encoding UTF8
$n=$rows.Count
Write-Host ("models: $n")
Write-Host ("  named   : " + ($rows | Where-Object { $_.model }).Count)
Write-Host ("  airflow : " + ($rows | Where-Object { $_.airflow }).Count)
Write-Host ("  power   : " + ($rows | Where-Object { $_.watts }).Count)
Write-Host ("  dia     : " + ($rows | Where-Object { $_.diameter }).Count)
Write-Host ("  dB      : " + ($rows | Where-Object { $_.db }).Count)
Write-Host ''
$rows | Group-Object sheet | ForEach-Object { Write-Host ("  {0,-26} {1,3}" -f $_.Name, $_.Count) }
