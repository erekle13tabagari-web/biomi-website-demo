# divcheck.ps1 -- count <div> openers against </div> closers in every page of the site
# and list the pages where the two differ. Skips tools/, .git/.claude, the backup
# folders, saved *_files folders and anything named DONT TOUCH. Exit code 1 when
# a page is off.
#   powershell -ExecutionPolicy Bypass -File tools\divcheck.ps1 [-All]
param([string]$Root = (Split-Path $PSScriptRoot -Parent), [switch]$All)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path.TrimEnd('\')
$utf8 = New-Object Text.UTF8Encoding($false)
$opt  = [Text.RegularExpressions.RegexOptions]::IgnoreCase

function Test-Skipped([string]$rel) {
  foreach ($seg in ($rel -split '\\' | Select-Object -SkipLast 1)) {
    if ($seg -eq 'tools' -or $seg -eq '.git' -or $seg -eq '.claude') { return $true }
    if ($seg -like 'backup*' -or $seg -like '*_files') { return $true }
    if ($seg -match 'DON''?T TOUCH|DO NOT TOUCH') { return $true }
  }
  return $false
}

$rows = @(); $unreadable = @()
# Not -Include: PS 5.1 ignores it next to -LiteralPath and hands back every file,
# including a 3.8 GB brandbook PDF that ReadAllText cannot hold.
$pages = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
         Where-Object { $_.Extension -eq '.html' -or $_.Extension -eq '.htm' }
foreach ($f in $pages) {
  $rel = $f.FullName.Substring($Root.Length + 1)
  if (Test-Skipped $rel) { continue }
  try { $text = [IO.File]::ReadAllText($f.FullName, $utf8) }
  catch { $unreadable += $rel; continue }
  $opens  = [regex]::Matches($text, '<div[\s>]', $opt).Count
  $closes = [regex]::Matches($text, '</div\s*>', $opt).Count
  $rows += [pscustomobject]@{ Page = $rel; Open = $opens; Close = $closes; Extra = $closes - $opens }
}

$bad = @($rows | Where-Object { $_.Extra -ne 0 } | Sort-Object Page)
$show = if ($All) { $rows | Sort-Object Page } else { $bad }
if ($show) { $show | Format-Table -AutoSize | Out-String -Width 200 | Write-Output }
foreach ($u in $unreadable) { Write-Output ("unreadable, not checked: " + $u) }
Write-Output ("{0} of {1} pages imbalanced ({2} more closers than openers in total)" -f `
  $bad.Count, $rows.Count, (($bad | Measure-Object Extra -Sum).Sum + 0))
if ($bad.Count) { exit 1 }
