# Replace long dashes with a plain hyphen everywhere a visitor can see one.
#
# The site was written with em dashes (—) in prose and en dashes (–) in ranges
# like "24–28 kW". Both are replaced with "-".
#
# Scope is the pages and the generators behind them. The generators matter as
# much as the pages: leave a long dash in tools/boilers/3-pages.ps1 and the next
# rebuild puts it straight back. Code comments in style.css and the README files
# are left alone -- no visitor reads them, and rewriting them is diff noise.
#
# Re-runnable, and worth re-running after adding a generator.
$repo = Split-Path $PSScriptRoot -Parent
$EM = [char]0x2014   # —
$EN = [char]0x2013   # –

$targets = @()
# every page
$targets += Get-ChildItem $repo -Recurse -File -Filter '*.html' |
            Where-Object { $_.FullName -notlike '*backup*' -and $_.FullName -notlike '*_files*' -and
                           $_.FullName -notlike '*.git*'   -and $_.FullName -notlike '*.claude*' -and
                           $true }
# the generators and their data, so the change survives a rebuild
$targets += Get-ChildItem (Join-Path $repo 'tools') -Recurse -File -Include '*.ps1', '*.json' |
            Where-Object { $_.Name -ne 'dashes.ps1' }
# -Include without -Recurse silently matches nothing, hence the wildcard path
$targets += Get-ChildItem (Join-Path $repo '*.ps1') -File
# the search index (regenerated, but keep it consistent meanwhile) and the one
# script that puts text on the page
$targets += Get-ChildItem (Join-Path $repo 'assets\search-*.json') -File
$targets += Get-Item (Join-Path $repo 'assets\js\main.js')

# Not $em / $en: PowerShell variable names are case-insensitive, so those would
# be the same variables as $EM / $EN above and overwrite the dash characters.
$changed = 0; $nEm = 0; $nEn = 0
foreach ($f in ($targets | Sort-Object FullName -Unique)) {
  $bytes = [IO.File]::ReadAllBytes($f.FullName)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $t = [IO.File]::ReadAllText($f.FullName)

  $a = 0; $b = 0
  foreach ($c in $t.ToCharArray()) {
    if ($c -eq $EM) { $a++ } elseif ($c -eq $EN) { $b++ }
  }
  if ($a + $b -eq 0) { continue }

  $t = $t.Replace($EM, '-').Replace($EN, '-')
  # Only the characters change, so line endings are left exactly as they were.
  [IO.File]::WriteAllText($f.FullName, $t, (New-Object Text.UTF8Encoding($hasBom)))
  $changed++; $nEm += $a; $nEn += $b
}
Write-Host ("files rewritten : {0}" -f $changed)
Write-Host ("em dashes (—)   : {0}" -f $nEm)
Write-Host ("en dashes (–)   : {0}" -f $nEn)
