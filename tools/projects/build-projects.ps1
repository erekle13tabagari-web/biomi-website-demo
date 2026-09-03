# Project pages, cloned from projects/terminal.html for chrome.
#
# terminal.html is the newest project page, so it already carries the current
# layout: no stat tiles, the h1 descriptor as a subtitle, and the video moved
# down to just above the "all projects" footer. Cloning it keeps every relative
# path valid, since the new files land in the same folder.
#
# Galleries are dropped rather than filled with grey boxes -- the photos are not
# organised yet, and a row of placeholders reads as a broken page. Dropping the
# block in the markup makes adding the real one later a straight paste, exactly
# as it was for PASHA Bank.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$DATA = Get-Content (Join-Path $sp 'projects.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10
$wrote = 0

# Replace everything between two markers, failing loudly rather than silently
# writing a page with a Terminal Towers heading still in it.
function Swap($s, $a, $b, $new, $what) {
  $i = $s.IndexOf($a)
  if ($i -lt 0) { throw "template marker not found: $what" }
  $j = $s.IndexOf($b, $i + $a.Length)
  if ($j -lt 0) { throw "template marker not closed: $what" }
  return $s.Substring(0, $i) + $new + $s.Substring($j + $b.Length)
}

function SwapGallery($s, $proj, $t, $lang, $repo) {
  # Gallery. The count is not stored anywhere -- the folder is the source of
  # truth, so dropping more images in and re-running is all it takes. A project
  # with no folder yet loses the block entirely rather than showing empty
  # frames, and gains it the moment the photos arrive.
  $gdir = Join-Path $repo ('assets\img\' + $proj.slug + '-gallery')
  $shots = @()
  if (Test-Path $gdir) {
    $shots = @(Get-ChildItem $gdir -Filter '*.avif' -File |
               Sort-Object { [int]($_.BaseName -replace '^.*-', '') })
  }
  $g = $s.IndexOf('<div class="gallery"')
  if ($g -ge 0) {
    $e = $s.IndexOf('</div>', $g) + 6
    if ($shots.Count) {
      $label = if ($lang -eq 'ka') { 'პროექტის გალერეა' } else { 'Project gallery' }
      $shot  = if ($lang -eq 'ka') { ' - პროექტის ფოტო ' } else { ' - project photo ' }
      $gal = '<div class="gallery" aria-label="' + $label + '">' + "`r`n"
      for ($k = 0; $k -lt $shots.Count; $k++) {
        $gal += '        <img src="../assets/img/' + $proj.slug + '-gallery/' + $shots[$k].Name +
                '" alt="' + $t.alt + $shot + ($k + 1) + '" data-lightbox>' + "`r`n"
      }
      $gal += '      </div>'
      $s = $s.Substring(0, $g) + $gal + $s.Substring($e)
    } else {
      $s = $s.Substring(0, $g).TrimEnd(" ", [char]13, [char]10) + "`r`n`r`n      " +
           $s.Substring($e).TrimStart(" ", [char]13, [char]10)
    }
  }
  return $s
}

foreach ($proj in $DATA) {
  # Pages written by hand. ORO, PASHA and Terminal predate this generator and
  # carry copy that was never in projects.json, so rebuilding them from the
  # template would throw that copy away. They are listed here only so their
  # gallery tracks the photo folder like everyone else's; nothing else on the
  # page is touched.
  if ($proj.PSObject.Properties['generated'] -and -not $proj.generated) {
    foreach ($lang in 'ka', 'en') {
      $sfx = if ($lang -eq 'en') { '-en.html' } else { '.html' }
      $out = Join-Path $repo ('projects\' + $proj.slug + $sfx)
      if (-not (Test-Path $out)) { Write-Host ('  ! no page at projects\' + $proj.slug + $sfx); continue }
      $s = [IO.File]::ReadAllText($out)
      $was = $s
      $s = SwapGallery $s $proj ($proj.$lang) $lang $repo
      if ($s -ne $was) {
        [IO.File]::WriteAllText($out, $s, $UTF8)
        Write-Host ('  refreshed the gallery in projects\' + $proj.slug + $sfx)
      } else {
        Write-Host ('  gallery already current in projects\' + $proj.slug + $sfx)
      }
    }
    continue
  }
  foreach ($lang in 'ka', 'en') {
    $sfx = if ($lang -eq 'en') { '-en.html' } else { '.html' }
    $t   = $proj.$lang
    $s   = [IO.File]::ReadAllText((Join-Path $repo ('projects\terminal' + $sfx)))

    $s = [regex]::Replace($s, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
    $s = [regex]::Replace($s, '<meta name="description" content="[^"]*"',
                          ('<meta name="description" content="' + $t.desc + '"'))
    # build-meta.ps1 regenerates the canonical/og block; drop the stale one
    $s = [regex]::Replace($s, '(?s)\s*<!-- meta:start.*?<!-- meta:end[^>]*-->', '')

    $s = Swap $s '<b>' '</b>' ('<b>' + $t.crumb + '</b>') 'breadcrumb'
    $s = Swap $s '<span class="news__cat">' '</span>' `
               ('<span class="news__cat">' + $t.cat + '</span>') 'category badge'
    $s = Swap $s '<h1>' '</h1>' `
               ('<h1>' + $t.h1 + '<span class="article__sub">' + $t.sub + '</span></h1>') 'h1'
    $s = Swap $s '<p class="article__lead">' '</p>' `
               ('<p class="article__lead">' + $t.lead + '</p>') 'lead'
    $s = Swap $s '<img src="../assets/img/proj-terminal.jpg"' '>' `
               ('<img src="../assets/img/' + $proj.hero + '" alt="' + $t.alt + '" data-lightbox>') 'hero image'
    $s = Swap $s '<figcaption>' '</figcaption>' `
               ('<figcaption>' + $t.cap + '</figcaption>') 'hero caption'

    $s = SwapGallery $s $proj $t $lang $repo

    # client logo chip -- removed outright where no logo exists yet
    if ($proj.logo) {
      # A stacked lockup (mark over text) collapses to a smudge at the chip's
      # default height, so it gets the taller box. Wide wordmarks do not.
      if ($proj.lockup) {
        $s = $s.Replace('<span class="proj__logo">', '<span class="proj__logo proj__logo--lockup">')
      }
      $s = $s.Replace('clients/terminal.svg" alt="Terminal Towers"',
                      'clients/' + $proj.logo + '" alt="' + $t.alt + '"')
    } else {
      $l = $s.IndexOf('<span class="proj__logo"')
      if ($l -ge 0) {
        $e = $s.IndexOf('</span>', $s.IndexOf('<img', $l)) + 7
        $s = $s.Substring(0, $l).TrimEnd(" ", [char]13, [char]10) + $s.Substring($e)
      }
    }

    # End at the video block, not the footer: the video sits between the body
    # and the footer, so searching back from the footer lands on the video's
    # own closing tag and swallows the iframe.
    $open  = $s.IndexOf('<div class="article__body">')
    $vid   = $s.IndexOf('<div class="article__video">', $open)
    $close = $s.LastIndexOf('</div>', $vid)
    $body  = ($t.body | ForEach-Object { if ($_) { '        ' + $_ } else { '' } }) -join "`r`n"
    $s = $s.Substring(0, $open) + '<div class="article__body">' + "`r`n" + $body + "`r`n      " +
         $s.Substring($close)

    # No video yet: drop the block rather than leaving an iframe pointing at
    # youtube-nocookie.com/embed/ with no id, which renders as a black error panel.
    if ($proj.video) {
      $s = $s.Replace('Fux3suuntOE', $proj.video)
      $vt = if ($lang -eq 'ka') { $t.h1 + ' - პროექტის ვიდეო' } else { $t.h1 + ' - project video' }
      $s = [regex]::Replace($s, 'title="Terminal Towers[^"]*"', ('title="' + $vt + '"'))
    } else {
      $v = $s.IndexOf('<div class="article__video">')
      if ($v -ge 0) {
        $e = $s.IndexOf('</div>', $s.IndexOf('</iframe>', $v)) + 6
        $s = $s.Substring(0, $v).TrimEnd(' ', [char]13, [char]10) + $CRLF + $CRLF + '      ' +
             $s.Substring($e).TrimStart(' ', [char]13, [char]10)
      }
    }

    # Language switch. The template's own slug is whatever page it was last
    # cloned from -- it read oro.html once and reads terminal.html now -- so
    # rewrite whatever slug the GEO/ENG links carry rather than naming one.
    # Both the header and the mobile drawer carry a copy, hence the global
    # replace. Which of the two is marked is-active comes from the template and
    # is already right for each language.
    $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">GEO',
                          ('href="' + $proj.slug + '.html">GEO'))
    $s = [regex]::Replace($s, 'href="[a-z0-9-]+\.html">ENG',
                          ('href="' + $proj.slug + '-en.html">ENG'))

    $out = Join-Path $repo ('projects\' + $proj.slug + $sfx)
    [IO.File]::WriteAllText($out, $s, $UTF8)
    $wrote++
    Write-Host ('  wrote projects\' + $proj.slug + $sfx)
  }
}
Write-Host ('pages written: ' + $wrote)
