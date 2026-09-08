# The projects gallery page: every project as a card, four across.
#
# The cards are lifted straight out of the homepage rail rather than rebuilt
# from projects.json. The rail is the canonical list -- it carries all eight,
# including ORO, PASHA and Terminal, whose pages predate projects.json -- and
# lifting means the two can never show a different set, a different photo or a
# different category. Reorder the rail and this page follows.
#
# The gallery sits outside .article, which is capped at 800px for a readable
# measure; four columns need the full container.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10

# $PAGE, not $T: PowerShell variable names are case-insensitive, so $t = $PAGE[$lang]
# inside the loop would overwrite the table with its own first entry.
$PAGE = @{
  ka = @{
    donor = 'service.html'; home = 'index.html'; out = 'projects.html'
    crumbHome = 'მთავარი'; crumb = 'პროექტები'
    eyebrow = 'პროექტები'; h1 = 'ჩვენი პროექტები'
    title = 'პროექტები - ბიომი'
    # No standing lede above the gallery: the projects speak for themselves and
    # the line only restated the services listed on the home page. desc stays --
    # it is the search-result description, which nobody reads on the page.
    desc  = 'ბიომი ჰოლდინგის განხორციელებული პროექტები - გათბობის, გაგრილების, ვენტილაციისა და წყალმომარაგების საინჟინრო სისტემები სხვადასხვა დანიშნულების ობიექტზე.'
  }
  en = @{
    donor = 'service-en.html'; home = 'index-en.html'; out = 'projects-en.html'
    crumbHome = 'Home'; crumb = 'Projects'
    eyebrow = 'Projects'; h1 = 'Our projects'
    title = 'Projects - Biomi'
    desc  = 'Projects delivered by Biomi Holding - heating, cooling, ventilation and water-supply engineering across buildings of every purpose.'
  }
}

foreach ($lang in 'ka', 'en') {
  $t = $PAGE[$lang]
  $s = [IO.File]::ReadAllText((Join-Path $repo $t.donor))

  # ---- the cards, lifted from the homepage rail
  $h = [IO.File]::ReadAllText((Join-Path $repo $t.home))
  $gs = $h.IndexOf('<div class="proj-grid">')
  if ($gs -lt 0) { throw "no proj-grid in $($t.home)" }
  $ge = $h.IndexOf('</div>', $h.LastIndexOf('</a>', $h.IndexOf('</section>', $gs)))
  $inner = $h.Substring($h.IndexOf('>', $gs) + 1, $ge - $h.IndexOf('>', $gs) - 1)
  $cards = @()
  foreach ($m in [regex]::Matches($inner, '(?s)<a class="proj[^"]*"[^>]*>.*?</a>')) {
    # the rail marks the first card as the bento feature; the gallery is a plain
    # grid, so the position classes come along only for their photo
    $cards += ('        ' + ($m.Value -replace '\r?\n\s*', ($CRLF + '          ')))
  }
  if ($cards.Count -lt 2) { throw "found $($cards.Count) cards in $($t.home)" }

  # Every element that concatenates is parenthesised: PowerShell binds the
  # comma tighter than +, so "a" + $x + "b", "c" parses as "a" + $x + ("b","c")
  # and the values end up on lines of their own inside the markup.
  $body = @(
    '<section class="page-hero">',
    '  <div class="container">',
    '    <article class="article article--flush">',
    '      <nav class="crumbs" aria-label="breadcrumb">',
    ('        <a href="' + $t.home + '">' + $t.crumbHome + '</a><span class="sep">/</span>'),
    ('        <b>' + $t.crumb + '</b>'),
    '      </nav>',
    '',
    ('      <span class="eyebrow">' + $t.eyebrow + '</span>'),
    ('      <h1>' + $t.h1 + '</h1>'),
    '    </article>',
    '',
    '    <div class="proj-gallery">',
    ($cards -join $CRLF),
    '    </div>',
    '  </div>',
    '</section>'
  ) -join $CRLF

  $a = $s.IndexOf('<section class="page-hero">')
  $b = $s.IndexOf('<!-- ===================== FOOTER')
  if ($a -lt 0 -or $b -lt 0) { throw "page-hero or footer marker missing in $($t.donor)" }
  $s = $s.Substring(0, $a) + $body + $CRLF + $s.Substring($b)

  $s = [regex]::Replace($s, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
  $s = [regex]::Replace($s, '<meta name="description" content="[^"]*"',
                        ('<meta name="description" content="' + $t.desc + '"'))
  # build-meta.ps1 regenerates the canonical/og block, and the donor is a hidden
  # page carrying robots noindex -- neither belongs on this one
  $s = [regex]::Replace($s, '(?s)\s*<!-- meta:start.*?<!-- meta:end[^>]*-->', '')

  # the donor's language switch points at the donor
  $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">GEO', 'href="projects.html">GEO')
  $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">ENG', 'href="projects-en.html">ENG')

  $s = [regex]::Replace($s, "`r`n|`n", $CRLF)
  [IO.File]::WriteAllText((Join-Path $repo $t.out), $s, $UTF8)
  Write-Host ('  wrote ' + $t.out + ' : ' + $cards.Count + ' cards')
}
