# Pull the boiler list out of "Products with Codes".
#
# The sheet is four brands laid out side by side, not stacked: Beretta in A-E,
# Riello in G-K, Warmhaus in M-Q, Teknix from S. Each block is
# (#, internal code, name, manufacturer code, country), so it is read as four
# separate tables sharing row numbers.
#
# Teknix is deliberately absent: the sheet lists five Teknix electric boilers,
# but they are not going on the site.
#
# Boilers and their accessories are mixed together in the same columns --
# thermostats, flues, pumps, flanges, sensors -- so a row only counts as a
# boiler if it says so.
$sp   = $PSScriptRoot
$xlsx = Join-Path $sp 'products-codes.xlsx'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($xlsx)
function RE($n){ $e=$zip.Entries|Where-Object{$_.FullName -eq $n}; if(-not $e){return $null}
  $sr=New-Object IO.StreamReader($e.Open()); $s=$sr.ReadToEnd(); $sr.Close(); $s }
$ss = [regex]::Matches((RE 'xl/sharedStrings.xml'),'(?s)<si>(.*?)</si>') | ForEach-Object {
  (([regex]::Matches($_.Groups[1].Value,'<t[^>]*>(.*?)</t>')|ForEach-Object{$_.Groups[1].Value}) -join '') }

$BLOCKS = @(
  @{ brand='Beretta';  code='B'; name='C'; mfr='D'; country='E' },
  @{ brand='Riello';   code='H'; name='I'; mfr='J'; country='K' },
  @{ brand='Warmhaus'; code='N'; name='O'; mfr='P'; country='Q' }
)

$rows = New-Object System.Collections.ArrayList
$sx = RE 'xl/worksheets/sheet1.xml'
foreach ($r in [regex]::Matches($sx,'(?s)<row[^>]*r="(\d+)"[^>]*>(.*?)</row>')) {
  $cell = @{}
  foreach ($c in [regex]::Matches($r.Groups[2].Value,'(?s)<c r="([A-Z]+)\d+"(?:[^>]*t="(\w+)")?[^>]*>(?:<v>(.*?)</v>)?')) {
    $v = $c.Groups[3].Value
    if ($c.Groups[2].Value -eq 's' -and $v -ne '') { $v = $ss[[int]$v] }
    if ($v) { $cell[$c.Groups[1].Value] = $v.Trim() }
  }
  foreach ($b in $BLOCKS) {
    $nm = $cell[$b.name]
    if (-not $nm) { continue }
    # boilers only: everything else in these columns is an accessory -- except
    # the burners ("სანთურა BURNER ..."), which have pages of their own and are
    # told apart from the boilers by families.json (cat=burners), not here
    $burner = ($nm -match 'სანთურა') -and ($nm -match 'BURNER')
    if (-not $burner) {
      if ($nm -notmatch 'ქვაბი') { continue }
      if ($nm -match 'სამართავი|თერმოსტატი|ტუმბო|მილი|კოლექტორი|ფლიანეც|სენსორი|კომპლექტი|ადაპტერი|კუთხე|საკვამური|კონსტრუქცია|გამათანაბრებელი|სარქველ|სანთურა') { continue }
    }
    [void]$rows.Add([pscustomobject]@{
      brand   = $b.brand
      code    = $cell[$b.code]
      name    = $nm
      mfr     = $cell[$b.mfr]
      country = $cell[$b.country]
      dummy   = [bool]($nm -match 'ბუტაფორია')
      kit     = [bool]($nm -match 'კომპლექტში')
    })
  }
}
$zip.Dispose()

# de-duplicate: a few names are repeated further down the sheet
$seen = @{}; $uniq = New-Object System.Collections.ArrayList
foreach ($x in $rows) {
  $k = $x.brand + '|' + $x.name
  if ($seen.ContainsKey($k)) { continue }
  $seen[$k] = $true; [void]$uniq.Add($x)
}
$uniq | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'boilers.json') -Encoding UTF8

Write-Host ("boiler rows: " + $uniq.Count)
foreach ($g in ($uniq | Group-Object brand)) {
  Write-Host ("`n=== {0} ({1})" -f $g.Name, $g.Count)
  foreach ($x in $g.Group) {
    $flag = ''
    if ($x.dummy) { $flag = '  [display dummy]' }
    elseif ($x.kit) { $flag = '  [supplied as kit]' }
    $n = $x.name -replace '\s+',' '
    if ($n.Length -gt 62) { $n = $n.Substring(0,62) }
    Write-Host ("   {0,-8} {1,-62} {2,-9} {3}{4}" -f $x.code, $n, $x.mfr, $x.country, $flag)
  }
}
