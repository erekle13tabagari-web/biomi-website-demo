# Resolve every internal href and src on every page against the filesystem.
# The nav rewiring touched all 98 pages, so this checks the whole site, not
# just the new Vortice ones.
$repo = Split-Path $PSScriptRoot -Parent
$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and $_.FullName -notmatch '\\(backup|_files|\.git)' }

$bad = New-Object System.Collections.ArrayList
foreach ($f in $files) {
  $txt = [IO.File]::ReadAllText($f.FullName)
  foreach ($m in [regex]::Matches($txt, '(?:href|src)="([^"]+)"')) {
    $u = $m.Groups[1].Value
    if ($u -match '^(https?:|mailto:|tel:|data:|#)') { continue }
    $path = ($u -split '[#?]')[0]
    if (-not $path) { continue }
    $full = [IO.Path]::GetFullPath((Join-Path $f.DirectoryName $path))
    if (-not (Test-Path -LiteralPath $full)) {
      [void]$bad.Add([pscustomobject]@{ page = $f.FullName.Substring($repo.Length+1); link = $u })
    }
  }
}
Write-Host ("pages checked : " + $files.Count)
Write-Host ("broken links  : " + $bad.Count)
$bad | Group-Object link | Sort-Object Count -Descending | ForEach-Object {
  Write-Host ("  {0,4}x  {1}" -f $_.Count, $_.Name)
  Write-Host ("         e.g. " + $_.Group[0].page)
}
