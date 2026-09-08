# Fail the publish if any page is missing its social/canonical meta block.
#
# The page generators in tools/ clone a donor page and deliberately strip the
# donor's meta block, because its canonical and og:url point at the wrong page.
# Every one of them assumes tools/build-meta.ps1 runs afterwards to write a
# correct block back. Skip that step and the page ships with no canonical, no
# hreflang and no share card - a link pasted into Messenger or WhatsApp shows a
# bare URL, and search engines lose the tie between the ka and en versions.
#
# Nothing about the rendered page looks wrong, so this is invisible in a
# browser and linkcheck.ps1 does not catch it either. Hence this guard.
#
# Called by "Update Website.bat" before it commits. Exit code 1 blocks the publish.
#
# Written without regex escapes on purpose: the path filter uses -like wildcards
# so no backslash survives a round trip through a shell here-doc.

$repo = $PSScriptRoot

$pages = Get-ChildItem $repo -Filter '*.html' -Recurse -File | Where-Object {
  $rel = $_.FullName.Substring($repo.Length + 1)
  $_.Name -ne 'Launch Biomi Website.html' -and
  $rel -notlike 'backup*'  -and
  $rel -notlike 'tools*'   -and
  $rel -notlike '.git*'    -and
  $rel -notlike '.claude*' -and
  $rel -notlike '*_files*'
}

$missing = @()
$nobrand = @()
$cardsSeen = 0
foreach ($p in $pages) {
  $txt = [IO.File]::ReadAllText($p.FullName)
  $rel = $p.FullName.Substring($repo.Length + 1)
  if ($txt -notmatch '<!-- meta:start') { $missing += $rel }

  # Brand logos, wiped by exactly the same accident as the meta block.
  #
  # tools/add-card-brands.ps1 stamps a logo onto every product card as a step of
  # its own, after the generators have run. Rebuild a listing and the cards come
  # back bare; nothing else notices, because a card without its logo is valid
  # markup that lays out correctly and links where it should. That is how 116
  # cards across 54 pages went out unbranded.
  $cards = ([regex]::Matches($txt, '<a class="pcard"')).Count
  if ($cards -gt 0) {
    $cardsSeen += $cards
    $logos = ([regex]::Matches($txt, 'pcard__brand')).Count
    if ($logos -lt $cards) { $nobrand += ($rel + '  (' + $logos + ' of ' + $cards + ')') }
  }
}

if ($missing.Count -gt 0) {
  Write-Host ""
  Write-Host "   META BLOCK MISSING on $($missing.Count) page(s):" -ForegroundColor Red
  foreach ($m in $missing) { Write-Host "     $m" -ForegroundColor Red }
  Write-Host ""
  Write-Host "   A page generator rewrote these and build-meta.ps1 was not run after."
  Write-Host "   Fix it by running:"
  Write-Host "     powershell -ExecutionPolicy Bypass -File tools/build-meta.ps1"
  Write-Host ""
  exit 1
}

if ($nobrand.Count -gt 0) {
  Write-Host ""
  Write-Host "   BRAND LOGO MISSING on $($nobrand.Count) page(s):" -ForegroundColor Red
  foreach ($m in $nobrand) { Write-Host "     $m" -ForegroundColor Red }
  Write-Host ""
  Write-Host "   A page generator rewrote these and add-card-brands.ps1 was not run after."
  Write-Host "   Fix it by running:"
  Write-Host "     powershell -ExecutionPolicy Bypass -File tools/add-card-brands.ps1"
  Write-Host ""
  exit 1
}

Write-Host "   Meta check  : ok - all $($pages.Count) pages tagged, $cardsSeen cards branded"
exit 0
