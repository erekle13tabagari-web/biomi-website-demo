# Project pages, the homepage's project cards and the projects page, from
# content/projects/<slug>.json (load-projects.ps1).
#
# Since 2026-10-01 every project page is built here, ORO, PASHA and Terminal
# included, so the editor at /admin can change any of them. The page around the
# article - head, header, drawer, footer, the breadcrumb's first two steps and
# the closing row - is taken from an existing project page (Terminal's, or any
# other if that one is gone), so it moves on whenever the rest of the site does.
# The article itself is written out whole from the project's file: blocks a
# project lacks (logo, gallery, video) are simply not written, and nothing
# depends on the donor page having them.
#
# Then the homepage rail (index.html / index-en.html) gets one card per project
# in "order", and build-index.ps1 copies those cards onto projects.html.
# A page with no project file any more is deleted.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
. (Join-Path $sp 'load-projects.ps1')
$DATA = Get-ProjectItems
if (-not $DATA.Count) { throw 'no project files in content\projects' }
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10
$wrote = 0

$LBL = @{
  ka = @{ gallery = 'პროექტის გალერეა'; shot = ' - პროექტის ფოტო '; video = ' - პროექტის ვიდეო' }
  en = @{ gallery = 'Project gallery'; shot = ' - project photo '; video = ' - project video' }
}

# text for an element, and for an attribute
function TxtEsc([string]$s) { return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;') }
function AttEsc([string]$s) { return (TxtEsc $s).Replace('"', '&quot;') }

# The hero as the full-size AVIF twin 2-images.ps1 writes beside the JPEG (a
# third of the size; the lightbox opens the same file), or the JPEG if there
# is no twin yet. The cards take the 1400px AVIF copy.
function PageImg($f) {
  $a = $f -replace '\.jpe?g$', '.avif'
  if ($a -ne $f -and (Test-Path (Join-Path $repo ('assets\img\' + $a)))) { return $a }
  return $f
}
function CardImg($f) {
  $c = $f -replace '\.jpe?g$', '-card.avif'
  if ($c -ne $f -and (Test-Path (Join-Path $repo ('assets\img\' + $c)))) { return $c }
  return $f
}
# the client logo chip, on the page ("../") and on the cards ("")
function LogoChip($p, $t, [string]$up) {
  if (-not $p.logo) { return '' }
  $cls = if ($p.lockup) { 'proj__logo proj__logo--lockup' } else { 'proj__logo' }
  $st  = if ($p.logoHeight) { ' style="--logo-h:' + $p.logoHeight + 'px"' } else { '' }
  return '<span class="' + $cls + '"><img src="' + $up + 'assets/img/' + $p.logo + '" alt="' + (AttEsc $t.card) + '"' + $st + '></span>'
}

# ---- the page around the article, from a donor page, read before anything is written
$DONOR = @{}
foreach ($lang in 'ka', 'en') {
  $sfx = if ($lang -eq 'en') { '-en.html' } else { '.html' }
  $cand = @((Join-Path $repo ('projects\terminal' + $sfx))) +
          @(Get-ChildItem (Join-Path $repo 'projects') -Filter ('*' + $sfx) -File |
            Where-Object { $lang -eq 'en' -or $_.Name -notlike '*-en.html' } | ForEach-Object { $_.FullName })
  $file = $cand | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $file) { throw ('no project page left to take the page layout from (' + $lang + ')') }
  $s = [IO.File]::ReadAllText($file)
  $a = $s.IndexOf('<section class="page-hero">')
  $z = $s.IndexOf('</section>', $a)
  $crumbs = [regex]::Match($s, '(?s)<nav class="crumbs".*?</nav>')
  $foot = [regex]::Match($s, '(?s)<div class="article__foot">.*?</div>(?=\s*</article>)')
  if ($a -lt 0 -or $z -lt 0 -or -not $crumbs.Success -or -not $foot.Success) { throw ('layout markers missing in ' + $file) }
  $DONOR[$lang] = @{
    head = $s.Substring(0, $a); tail = $s.Substring($z + '</section>'.Length)
    crumbs = $crumbs.Value; foot = $foot.Value
  }
}

foreach ($p in $DATA) {
  foreach ($lang in 'ka', 'en') {
    $sfx = if ($lang -eq 'en') { '-en.html' } else { '.html' }
    $t = $p.$lang; $d = $DONOR[$lang]; $l = $LBL[$lang]

    $head = $d.head
    $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + (TxtEsc $t.title) + '</title>'))
    $head = [regex]::Replace($head, '<meta name="description" content="[^"]*"', ('<meta name="description" content="' + (AttEsc $t.desc) + '"'))
    # build-meta.ps1 writes the canonical/og block for this page; drop the donor's
    $head = [regex]::Replace($head, '(?s)\s*<!-- meta:start.*?<!-- meta:end[^>]*-->', '')

    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('<section class="page-hero">')
    $o.Add('  <div class="container">')
    $o.Add('    <article class="article">')
    $o.Add('      ' + [regex]::Replace($d.crumbs, '<b>[^<]*</b>', ('<b>' + (TxtEsc $t.crumb) + '</b>')))
    $o.Add('')
    $o.Add('      <div class="article__topmeta">')
    $o.Add('        <span class="news__cat">' + (TxtEsc $t.cat) + '</span>')
    $chip = LogoChip $p $t '../'
    if ($chip) { $o.Add('        ' + $chip) }
    $o.Add('      </div>')
    $sub = if ($t.sub) { '<span class="article__sub">' + (TxtEsc $t.sub) + '</span>' } else { '' }
    $o.Add('      <h1>' + (TxtEsc $t.h1) + $sub + '</h1>')
    $o.Add('      <p class="article__lead">' + (TxtEsc $t.lead) + '</p>')
    $o.Add('')
    $o.Add('      <figure class="article__img">')
    $o.Add('        <img src="../assets/img/' + (PageImg $p.hero) + '" alt="' + (AttEsc $t.alt) + '" data-lightbox>')
    if ($t.cap) { $o.Add('        <figcaption>' + (TxtEsc $t.cap) + '</figcaption>') }
    $o.Add('      </figure>')

    # Gallery. The count is not stored anywhere -- the folder is the source of
    # truth (2-images.ps1 fills it from the editor's uploads or the office
    # photo folder). No folder, no block, rather than a row of empty frames.
    $gdir = Join-Path $repo ('assets\img\' + $p.slug + '-gallery')
    $shots = @()
    if (Test-Path $gdir) {
      $shots = @(Get-ChildItem $gdir -Filter '*.avif' -File | Sort-Object { [int]($_.BaseName -replace '^.*-', '') })
    }
    if ($shots.Count) {
      $o.Add('')
      $o.Add('      <div class="gallery" aria-label="' + $l.gallery + '">')
      for ($k = 0; $k -lt $shots.Count; $k++) {
        $o.Add('        <img src="../assets/img/' + $p.slug + '-gallery/' + $shots[$k].Name + '" alt="' +
               (AttEsc ($t.alt + $l.shot + ($k + 1))) + '" loading="lazy" data-lightbox>')
      }
      $o.Add('      </div>')
    }

    $o.Add('')
    $o.Add('      <div class="article__body">')
    foreach ($line in $t.body) {
      if ($line -eq 'FIGURE' -or $line -like 'VIDEO:*') { continue }   # news markers; a project's video has its own place below
      $o.Add('        ' + $line)
    }
    $o.Add('      </div>')

    # the video sits between the text and the closing row
    if ($p.video) {
      $o.Add('')
      $o.Add('      <div class="article__video">')
      $o.Add('        <iframe src="https://www.youtube-nocookie.com/embed/' + $p.video + '?rel=0" title="' + (AttEsc ($t.h1 + $l.video)) + '"')
      $o.Add('          referrerpolicy="strict-origin-when-cross-origin" allowfullscreen')
      $o.Add('          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe>')
      $o.Add('      </div>')
    }
    $o.Add('')
    $o.Add('      ' + $d.foot)
    $o.Add('    </article>')
    $o.Add('  </div>')
    $o.Add('</section>')

    $s = $head + ($o -join $CRLF) + $d.tail
    # Language switch: the donor's links point at the donor. Both the header and
    # the mobile drawer carry a copy, hence the global replace.
    $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">GEO', ('href="' + $p.slug + '.html">GEO'))
    $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">ENG', ('href="' + $p.slug + '-en.html">ENG'))
    $s = [regex]::Replace($s, "`r`n|`n", $CRLF)

    $out = Join-Path $repo ('projects\' + $p.slug + $sfx)
    [IO.File]::WriteAllText($out, $s, $UTF8)
    $wrote++
  }
}
Write-Host ('  project pages written: ' + $wrote)

# ---- the homepage rail: one card per project, in order. The first card is the
#      tall one in the rail's bento layout (style.css, .proj:first-child). The
#      card photo is set by main.js from data-bg once the rail comes near, so
#      the eight photos are not fetched with the top of the homepage.
foreach ($lang in 'ka', 'en') {
  $sfx  = if ($lang -eq 'en') { '-en.html' } else { '.html' }
  $file = if ($lang -eq 'en') { 'index-en.html' } else { 'index.html' }
  $fp = Join-Path $repo $file
  $s  = [IO.File]::ReadAllText($fp)
  $gs = $s.IndexOf('<div class="proj-grid">')
  $nx = $s.IndexOf('<button class="rail__arrow rail__next"', $gs)
  if ($gs -lt 0 -or $nx -lt 0) { throw ('no project rail in ' + $file) }
  $ge = $s.LastIndexOf('</div>', $nx)
  $cards = @()
  foreach ($p in $DATA) {
    $t = $p.$lang
    $c = @('        <a class="proj reveal" href="projects/' + $p.slug + $sfx + '">')
    $c += '          <span class="proj__img" data-bg="assets/img/' + (CardImg $p.hero) + '"></span>'
    $chip = LogoChip $p $t ''
    if ($chip) { $c += '          ' + $chip }
    $c += '          <span class="proj__info">'
    $c += '            <span class="proj__meta"><span>' + (TxtEsc $t.cat) + '</span><h3>' + (TxtEsc $t.card) + '</h3></span>'
    $c += '          </span>'
    $c += '        </a>'
    $cards += ($c -join $CRLF)
  }
  $s = $s.Substring(0, $gs) + '<div class="proj-grid">' + $CRLF + ($cards -join $CRLF) + $CRLF + '      ' + $s.Substring($ge)
  [IO.File]::WriteAllText($fp, $s, $UTF8)
  Write-Host ('  rebuilt the project rail in ' + $file + ' : ' + $cards.Count + ' cards')
}

# A project deleted in the editor takes its two pages with it. Every page in
# projects/ is written by this script, so one without a project file is stale.
$keep = @{}; foreach ($p in $DATA) { $keep[$p.slug] = 1 }
foreach ($old in Get-ChildItem (Join-Path $repo 'projects') -Filter '*.html' -File) {
  if (-not $keep.ContainsKey(($old.BaseName -replace '-en$', ''))) {
    Remove-Item -LiteralPath $old.FullName
    Write-Host ('  removed projects\' + $old.Name + ' (no project file)')
  }
}

# projects.html / projects-en.html copy the rail's cards
& (Join-Path $sp 'build-index.ps1')
