# Link the brand logo on every product page to that brand's own page.
#
# The brand pages (samsung.html, vortice.html, beretta.html ...) are complete
# listings of one make, and the search index is built from them, but since the
# menu started pointing at the category listings with ?brand= nothing linked to
# them at all - 14 orphan pages (SEO audit, 2026-09-21). They are the pages that
# can answer a search like "Samsung DVM" or "Vortice", so every product now
# links its maker's logo there: 134 internal links with the brand as their text
# (the logo's alt).
#
# The logo is written as a <div class="pbuy__brand"> by three generators
# (tools/boilers/3-pages.ps1, tools/vortice/vortice-gen.ps1,
# tools/water-heaters/3-pages.ps1) and by the hand-built Samsung and Mitsubishi
# pages. Rather than teach each one, this runs after them, like
# add-card-brands.ps1: re-run it whenever product pages are regenerated.
# Re-runnable - a logo that is already a link just gets its address refreshed.
$repo = Split-Path $PSScriptRoot -Parent

# page-name prefix -> brand page. Riello has two: the burners and the rest.
# Omega has no page of its own, so its logo stays as it is.
function HubFor([string]$name) {
  switch -Regex ($name) {
    '^samsung-'          { return 'samsung' }
    '^mitsubishi-'       { return 'mitsubishi-electric' }
    '^vortice-'          { return 'vortice' }
    '^beretta-'          { return 'beretta' }
    '^riello-gulliver-'  { return 'riello-burners' }
    '^riello-'           { return 'riello' }
    '^warmhaus-'         { return 'warmhaus' }
  }
  return $null
}

$done = 0; $skipped = @()
foreach ($f in Get-ChildItem (Join-Path $repo 'products') -Filter '*.html' -File) {
  $txt = [IO.File]::ReadAllText($f.FullName)
  if ($txt -notmatch 'class="pbuy__brand') { continue }
  $base = $f.BaseName -replace '-en$', ''
  $hub = HubFor $base
  if (-not $hub) { $skipped += $f.Name; continue }
  $sfx = if ($f.Name -like '*-en.html') { '-en.html' } else { '.html' }
  if ($base -eq $hub) { continue }   # the brand page itself
  $href = $hub + $sfx
  if (-not (Test-Path (Join-Path $repo ('products\' + $href)))) { $skipped += $f.Name; continue }
  $new = [regex]::Replace($txt,
    # the class may carry a modifier (pbuy__brand--tall on the Mitsubishi pages)
    '(?s)<(div|a) class="(pbuy__brand[^"]*)"(?: href="[^"]*")?([^>]*)>(.*?)</\1>',
    { param($m) '<a class="' + $m.Groups[2].Value + '" href="' + $href + '"' + $m.Groups[3].Value + '>' + $m.Groups[4].Value + '</a>' })
  if ($new -ne $txt) {
    [IO.File]::WriteAllText($f.FullName, $new, (New-Object Text.UTF8Encoding($true)))
    $done++
  }
}
Write-Host ("brand logos linked : " + $done + " pages")
if ($skipped.Count) { Write-Host ("no brand page      : " + ($skipped -join ', ')) }
