# News article pages, cloned from the template beside this script.
#
# The template lives in tools/ rather than news/ so it is never served, never
# tagged by build-meta.ps1 and never reaches the sitemap. It supplies the header,
# drawer, footer and every relative path; this swaps the content in.
# Blocks that an article does not have are dropped rather than left empty --
# a gallery of nothing, or a video panel with no video, reads as a broken page.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$DATA = Get-Content (Join-Path $sp 'news.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10
$wrote = 0

# Replace everything between two markers, failing loudly rather than silently
# writing a page with the template's own heading still in it.
function Swap($s, $a, $b, $new, $what) {
  $i = $s.IndexOf($a)
  if ($i -lt 0) { throw "template marker not found: $what" }
  $j = $s.IndexOf($b, $i + $a.Length)
  if ($j -lt 0) { throw "template marker not closed: $what" }
  return $s.Substring(0, $i) + $new + $s.Substring($j + $b.Length)
}

# Cut a block out entirely, from $open to the end of the tag that closes it.
function DropBlock($s, $open, $closeAfter) {
  $i = $s.IndexOf($open)
  if ($i -lt 0) { return $s }
  $k = if ($closeAfter) { $s.IndexOf($closeAfter, $i) } else { $i }
  if ($k -lt 0) { return $s }
  $e = $s.IndexOf('</div>', $k) + 6
  return $s.Substring(0, $i).TrimEnd(' ', [char]13, [char]10) + $CRLF + $CRLF + '      ' +
         $s.Substring($e).TrimStart(' ', [char]13, [char]10)
}

function Esc($s) { $s -replace '&(?!(amp|lt|gt|quot|#\d+);)', '&amp;' -replace '"', '&quot;' }

foreach ($item in $DATA) {
  foreach ($lang in 'ka', 'en') {
    $sfx = if ($lang -eq 'en') { '-en.html' } else { '.html' }
    $t   = $item.$lang
    $s   = [IO.File]::ReadAllText((Join-Path $sp ('_template' + $sfx)))

    $s = [regex]::Replace($s, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
    $s = [regex]::Replace($s, '<meta name="description" content="[^"]*"',
                          ('<meta name="description" content="' + (Esc $t.desc) + '"'))
    # build-meta.ps1 regenerates the canonical/og block; drop the stale one
    $s = [regex]::Replace($s, '(?s)\s*<!-- meta:start.*?<!-- meta:end[^>]*-->', '')

    $s = Swap $s '<b>' '</b>' ('<b>' + $t.crumb + '</b>') 'breadcrumb'
    $s = Swap $s '<span class="news__cat">' '</span>' `
               ('<span class="news__cat">' + $t.cat + '</span>') 'category badge'
    $s = [regex]::Replace($s, '<time class="article__date" datetime="[^"]*">',
                          ('<time class="article__date" datetime="' + $item.date + '">'))
    # the date text is the last line inside <time>, after the calendar icon
    $s = [regex]::Replace($s, '(?s)(</svg>\s*\r?\n\s*)[^<\r\n]+(\r?\n\s*</time>)',
                          ('${1}' + $t.dateText + '${2}'))
    $s = Swap $s '<h1>' '</h1>' ('<h1>' + $t.h1 + '</h1>') 'h1'
    $s = Swap $s '<p class="article__lead">' '</p>' `
               ('<p class="article__lead">' + $t.lead + '</p>') 'lead'

    # ---- hero
    $s = [regex]::Replace($s, '<img src="\.\./assets/img/[^"]*" alt="[^"]*" data-lightbox>',
                          ('<img src="../assets/img/' + $item.hero + '" alt="' + (Esc $t.alt) + '" data-lightbox>'), 1)
    if ($t.cap) {
      $s = Swap $s '<figcaption>' '</figcaption>' ('<figcaption>' + $t.cap + '</figcaption>') 'hero caption'
    } else {
      # no verified caption for this photo: drop the line rather than invent one
      $s = [regex]::Replace($s, '(?s)\s*<figcaption>.*?</figcaption>', '')
    }

    # ---- gallery. The count is not stored anywhere -- the folder is the source
    #      of truth, so dropping more photos in and re-running is all it takes.
    $gdir = Join-Path $repo ('assets\img\' + $item.slug + '-gallery')
    $shots = @()
    if (Test-Path $gdir) {
      $shots = @(Get-ChildItem $gdir -Filter '*.avif' -File |
                 Sort-Object { [int]($_.BaseName -replace '^.*-', '') })
    }
    $g = $s.IndexOf('<div class="gallery"')
    if ($g -ge 0) {
      $e = $s.IndexOf('</div>', $g) + 6
      if ($shots.Count) {
        $label = if ($lang -eq 'ka') { 'ფოტოგალერეა' } else { 'Photo gallery' }
        $shot  = if ($lang -eq 'ka') { ' - ფოტო ' } else { ' - photo ' }
        $gal = '<div class="gallery" aria-label="' + $label + '">' + $CRLF
        for ($k = 0; $k -lt $shots.Count; $k++) {
          $gal += '        <img src="../assets/img/' + $item.slug + '-gallery/' + $shots[$k].Name +
                  '" alt="' + (Esc $t.alt) + $shot + ($k + 1) + '" data-lightbox>' + $CRLF
        }
        $gal += '      </div>'
        $s = $s.Substring(0, $g) + $gal + $s.Substring($e)
      } else {
        $s = $s.Substring(0, $g).TrimEnd(' ', [char]13, [char]10) + $CRLF + $CRLF + '      ' +
             $s.Substring($e).TrimStart(' ', [char]13, [char]10)
      }
    }

    # ---- body. Each FIGURE line on its own becomes the next captioned photo
    #      from this item's figures list, in order. A FIGURE with no figure
    #      left to spend is dropped, which is how a withdrawn photo takes its
    #      caption out of the article with it rather than pairing that caption
    #      with some other picture.
    $lines = @()
    $fi = 0
    foreach ($line in $t.body) {
      if ($line -eq 'FIGURE') {
        $fig = if ($item.figures -and $fi -lt @($item.figures).Count) { @($item.figures)[$fi] } else { $null }
        $fi++
        if ($fig) {
          $ft = $fig.$lang
          $lines += '<figure class="article__img">'
          $lines += '  <img src="../assets/img/' + $fig.img + '" alt="' + (Esc $ft.alt) + '" data-lightbox>'
          $lines += '  <figcaption>' + $ft.cap + '</figcaption>'
          $lines += '</figure>'
        }
      } else {
        $lines += $line
      }
    }
    $body = ($lines | ForEach-Object { if ($_) { '        ' + $_ } else { '' } }) -join $CRLF

    $open  = $s.IndexOf('<div class="article__body">')
    $close = $s.IndexOf('<!-- body:end -->', $open)
    if ($open -lt 0 -or $close -lt 0) { throw "body markers not found in $($item.slug)$sfx" }
    $s = $s.Substring(0, $open) + '<div class="article__body">' + $CRLF + $body + $CRLF + '      </div>' +
         $CRLF + $CRLF + '      ' + $s.Substring($close + '<!-- body:end -->'.Length).TrimStart(' ', [char]13, [char]10)

    # ---- neither article has a video
    $s = [regex]::Replace($s, '(?s)\s*<h2 class="video-h">.*?</div>\s*(?=<div class="article__foot">)', ($CRLF + $CRLF + '      '))

    # ---- the "other news" strip at the foot. The template carries three
    #      placeholder cards; rebuild it from news.json so it lists the real
    #      articles and nothing else. One card is lifted from the template and
    #      restamped, which keeps its markup, labels and inline SVGs exactly as
    #      they are rather than retyping them here.
    $gs = $s.IndexOf('<div class="news-grid">')
    if ($gs -ge 0) {
      $ge = $s.IndexOf('</div>' + $CRLF + '  </div>', $gs)
      if ($ge -lt 0) { $ge = $s.LastIndexOf('</article>') + '</article>'.Length }
      else { $ge = $s.LastIndexOf('</article>', $ge) + '</article>'.Length }
      $cs = $s.IndexOf('<article class="news reveal">', $gs)
      $ce = $s.IndexOf('</article>', $cs) + '</article>'.Length
      $card = $s.Substring($cs, $ce - $cs)

      $cards = @()
      foreach ($o in $DATA) {
        if ($o.slug -eq $item.slug) { continue }
        $ot = $o.$lang
        $c = $card
        $c = [regex]::Replace($c, 'src="\.\./assets/img/[^"]*"', ('src="../assets/img/' + $o.hero + '"'))
        $c = [regex]::Replace($c, '<span class="news__cat">[^<]*</span>', ('<span class="news__cat">' + $ot.cat + '</span>'))
        $c = [regex]::Replace($c, '(?s)<h3>.*?</h3>', ('<h3>' + $ot.h1 + '</h3>'))
        $c = [regex]::Replace($c, '<a class="link-more" href="[^"]*"', ('<a class="link-more" href="' + $o.slug + $sfx + '"'))
        $cards += $c
      }
      if ($cards.Count) {
        $s = $s.Substring(0, $cs) + ($cards -join ($CRLF + '      ')) + $s.Substring($ge)
      } else {
        # nothing else published yet: drop the whole section rather than show an
        # empty grid under a "more news" heading
        $ss = $s.LastIndexOf('<section', $gs)
        $se = $s.IndexOf('</section>', $gs) + '</section>'.Length
        $s = $s.Substring(0, $ss).TrimEnd(' ', [char]13, [char]10) + $CRLF + $CRLF + $s.Substring($se).TrimStart(' ', [char]13, [char]10)
      }
    }
    # the template's language switch points at itself -- point both at this slug
    $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">GEO', ('href="' + $item.slug + '.html">GEO'))
    $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">ENG', ('href="' + $item.slug + '-en.html">ENG'))

    $out = Join-Path $repo ('news\' + $item.slug + $sfx)
    [IO.File]::WriteAllText($out, $s, $UTF8)
    $wrote++
    Write-Host ('  wrote news\' + $item.slug + $sfx)
  }
}

# ---- the homepage rail. Same restamping as the "other news" strip, so the
#      cards on index.html can never drift from the articles that exist. The
#      homepage sits one folder up, so its paths have no "../" and its links
#      carry the "news/" prefix.
foreach ($lang in 'ka', 'en') {
  $sfx  = if ($lang -eq 'en') { '-en.html' } else { '.html' }
  $file = if ($lang -eq 'en') { 'index-en.html' } else { 'index.html' }
  $fp = Join-Path $repo $file
  $s  = [IO.File]::ReadAllText($fp)

  $sec = $s.IndexOf('id="news"')
  if ($sec -lt 0) { Write-Host ("  ! no news section in $file"); continue }
  $gs = $s.IndexOf('<div class="news-grid">', $sec)
  if ($gs -lt 0) { Write-Host ("  ! no news grid in $file"); continue }
  $cs = $s.IndexOf('<article class="news reveal">', $gs)
  $ce = $s.IndexOf('</article>', $cs) + '</article>'.Length
  $card = $s.Substring($cs, $ce - $cs)
  $last = $s.LastIndexOf('</article>', $s.IndexOf('</div>' + $CRLF, $ce)) + '</article>'.Length
  # the grid runs to the last </article> before the grid closes
  $ge = $s.IndexOf('</div>', $ce)
  while ($true) {
    $nxt = $s.IndexOf('<article class="news reveal">', $ge)
    if ($nxt -lt 0 -or $nxt -gt $s.IndexOf('</section>', $gs)) { break }
    $ge = $s.IndexOf('</div>', $s.IndexOf('</article>', $nxt))
  }
  $ge = $s.LastIndexOf('</article>', $s.IndexOf('</section>', $gs)) + '</article>'.Length

  $cards = @()
  foreach ($o in $DATA) {
    $ot = $o.$lang
    $c = $card
    $c = [regex]::Replace($c, 'src="assets/img/[^"]*"', ('src="assets/img/' + $o.hero + '"'))
    $c = [regex]::Replace($c, '<span class="news__cat">[^<]*</span>', ('<span class="news__cat">' + $ot.cat + '</span>'))
    $c = [regex]::Replace($c, '(?s)<h3>.*?</h3>', ('<h3>' + $ot.h1 + '</h3>'))
    $c = [regex]::Replace($c, '<a class="link-more" href="[^"]*"', ('<a class="link-more" href="news/' + $o.slug + $sfx + '"'))
    $cards += $c
  }
  $s = $s.Substring(0, $cs) + ($cards -join ($CRLF + '        ')) + $s.Substring($ge)
  $s = [regex]::Replace($s, "`r`n|`n", $CRLF)
  [IO.File]::WriteAllText($fp, $s, $UTF8)
  Write-Host ("  rebuilt the news rail in $file : " + $cards.Count + ' cards')
}
Write-Host ('pages written: ' + $wrote)
