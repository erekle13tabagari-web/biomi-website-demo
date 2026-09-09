# Stamp each product card with its brand logo.
#
# The brand is read from the card's own href, so this stays right as products
# move between pages -- listing cards, related-product cards and compatibility
# cards all get the same treatment without being enumerated anywhere.
#
# Re-runnable: a card that already carries a logo is skipped.
$repo = Split-Path $PSScriptRoot -Parent
$BRANDS = @(
  @{ prefix='samsung';    file='samsung.svg';             name='Samsung' },
  @{ prefix='mitsubishi'; file='mitsubishi-electric.svg'; name='Mitsubishi Electric' },
  @{ prefix='vortice';    file='vortice.svg';             name='Vortice' },
  @{ prefix='beretta';    file='beretta.svg';             name='Beretta' },
  @{ prefix='riello';     file='riello.svg';              name='Riello' },
  @{ prefix='warmhaus';   file='warmhaus.svg';            name='Warmhaus' },
  @{ prefix='omega';      file='omega.svg';               name='Omega' }
)

$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and $_.FullName -notmatch '\\(backup|_files|\.git|\.claude|tools)' }

$pages = 0; $stamped = 0
foreach ($f in $files) {
  $txt = [IO.File]::ReadAllText($f.FullName)
  if ($txt -notmatch '<a class="pcard"') { continue }
  $orig = $txt
  # depth of this page relative to the repo root, for the asset path
  $rel = $f.DirectoryName.Substring($repo.Length).Trim('\')
  $up = if ($rel) { '../' } else { '' }

  $txt = [regex]::Replace($txt, '(?s)(<a class="pcard" href="([^"]+)"[^>]*>\s*<span class="pcard__img">)(?!<span class="pcard__brand">)', {
    param($m)
    $href = $m.Groups[2].Value
    $leaf = ($href -split '/')[-1]
    foreach ($b in $BRANDS) {
      if ($leaf.StartsWith($b.prefix)) {
        $script:stamped++
        return $m.Groups[1].Value + '<span class="pcard__brand"><img src="' + $up +
               'assets/img/partners/' + $b.file + '" alt="' + $b.name + '" loading="lazy"></span>'
      }
    }
    return $m.Groups[1].Value
  })

  if ($txt -ne $orig) {
    # With the BOM, like the pages themselves: stamping a page must not also
    # strip its BOM, or a four-card fix arrives as four whole-file diffs. Safe
    # against the generators that read pages back as templates -- both
    # ReadAllText and Get-Content -Raw -Encoding UTF8 consume the BOM on read.
    [IO.File]::WriteAllText($f.FullName, $txt, (New-Object Text.UTF8Encoding($true)))
    $pages++
  }
}
Write-Host "pages updated : $pages"
Write-Host "cards stamped : $stamped"
