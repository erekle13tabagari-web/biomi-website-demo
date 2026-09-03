# The privacy-policy page, and the footer link that reaches it.
#
# Replaces the earlier "Legal" footer column, which this script now removes: the
# column carried a single placeholder Terms of Service link, and the real
# document that arrived is the confidentiality policy. It sits as one link under
# the social icons instead of a whole column of its own.
#
# The footer is hand-written into every page rather than generated, so this
# script is the only safe way to change its shape -- doing it by hand guarantees
# drift between languages and folders.
#
# The document is served as page images (assets/img/policy/p-N.webp), not as a
# PDF. That is deliberate: a PDF at a public URL is downloadable no matter what
# the viewer's toolbar is told to hide, whereas images mean there is no document
# file to fetch at all. Regenerate them with:
#
#   magick -density 200 "<the pdf>" -background white -alpha remove -alpha off `
#          -resize 1400x -quality 78 assets/img/policy/p-%d.webp
#
# (that writes p-0..p-5; the files are renamed to p-1..p-6).
#
# Selection, dragging and printing are suppressed in CSS. Screenshots cannot be
# prevented by any means available to a web page -- see the note in style.css.
$repo  = Split-Path $PSScriptRoot -Parent
$PAGES = 6
$BOM   = New-Object Text.UTF8Encoding($true)
$NOBOM = New-Object Text.UTF8Encoding($false)

$L = @{
  ka = @{ sfx='.html'; slug='privacy'
          link='კონფიდენციალურობის პოლიტიკა'
          eyebrow='იურიდიული'; home='მთავარი'
          title='კონფიდენციალურობის პოლიტიკა - ბიომი'
          h2='კონფიდენციალურობის პოლიტიკა'
          lede='სს „ბიომი ჰოლდინგის“ პერსონალურ მონაცემთა დაცვის პოლიტიკა.'
          alt='კონფიდენციალურობის პოლიტიკა - გვერდი'
          note='პოლიტიკასთან დაკავშირებული კითხვებისთვის დაგვიკავშირდით:'
          printn='კონფიდენციალურობის პოლიტიკა ხელმისაწვდომია მხოლოდ ვებ-გვერდზე: biomi.ge' }
  en = @{ sfx='-en.html'; slug='privacy'
          link='Privacy Policy'
          eyebrow='Legal'; home='Home'
          title='Privacy Policy - Biomi'
          h2='Privacy Policy'
          lede='The personal-data protection policy of JSC Biomi Holding, published in Georgian.'
          alt='Privacy policy - page'
          note='For questions about this policy, please get in touch:'
          printn='The privacy policy is available on the website only: biomi.ge' }
}

# ---- 1. the pages, spliced off about.html for chrome
foreach ($lang in 'ka','en') {
  $t   = $L[$lang]
  $tpl = [IO.File]::ReadAllText((Join-Path $repo ('about' + $t.sfx)))
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in about' + $t.sfx) }
  $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)
  # the meta block belongs to tools/build-meta.ps1; drop about.html's copy so
  # this page does not inherit its canonical URL and description
  $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
  $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
  # The chrome still carries About's own language switch -- one copy in the
  # header ($head) and one in the drawer ($tail). Matching on the GEO/ENG labels
  # leaves the nav's link to the About page alone.
  foreach ($pair in @(@('href="about.html">GEO<', 'href="privacy.html">GEO<'),
                      @('href="about-en.html">ENG<', 'href="privacy-en.html">ENG<'))) {
    $head = $head.Replace($pair[0], $pair[1])
    $tail = $tail.Replace($pair[0], $pair[1])
  }

  $imgs = ''
  for ($p = 1; $p -le $PAGES; $p++) {
    $lazy = if ($p -eq 1) { '' } else { ' loading="lazy"' }
    $imgs += '        <img src="assets/img/policy/p-' + $p + '.webp" alt="' + $t.alt + ' ' + $p +
             '" width="1400" height="1980" draggable="false"' + $lazy + '>' + "`r`n"
  }

  $body = @'
<section class="page-hero">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="index{SFX}">{HOME}</a><span class="sep">/</span>
      <b>{H2}</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">{EYEBROW}</span>
      <h2>{H2}</h2>
      <p class="page-lede">{LEDE}</p>
    </div>
  </div>
</section>

<section class="section">
  <div class="container">
      <div class="policy" role="document" aria-label="{H2}">
{IMGS}      </div>
      <p class="policy__print">{PRINTN}</p>
      <p class="policy__note">{NOTE}
        <a href="mailto:info@biomi.ge">info@biomi.ge</a> &middot;
        <a href="tel:+995322151115">+995 322 15 11 15</a></p>
  </div>
</section>

'@
  $body = $body.Replace('{SFX}', $t.sfx).Replace('{HOME}', $t.home).Replace('{H2}', $t.h2).
                Replace('{EYEBROW}', $t.eyebrow).Replace('{LEDE}', $t.lede).
                Replace('{IMGS}', $imgs).Replace('{NOTE}', $t.note).Replace('{PRINTN}', $t.printn)

  [IO.File]::WriteAllText((Join-Path $repo ($t.slug + $t.sfx)), ($head + $body + $tail), $NOBOM)
  Write-Host ('  wrote ' + $t.slug + $t.sfx)
}

# ---- 2. the footer, on every page: drop the Legal column, add the policy link
$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and
                        $_.FullName -notmatch 'backup|_files' -and
                        $_.FullName -notlike '*.git*' -and $_.FullName -notlike '*.claude*' }
$dropped = 0; $linked = 0
foreach ($f in $files) {
  $s = [IO.File]::ReadAllText($f.FullName)
  $before = $s
  $t = if ($f.Name -like '*-en.html') { $L['en'] } else { $L['ka'] }
  # root pages link straight at privacy.html; anything in a subfolder needs ../
  $prefix = if ((Split-Path $f.FullName -Parent) -eq $repo) { '' } else { '../' }

  # drop the Legal column. It holds an <h4> and a <nav>, no nested div, so the
  # first </div> after the opening tag is its own.
  $a = $s.IndexOf('<div class="footer__legal">')
  if ($a -ge 0) {
    $b = $s.IndexOf('</div>', $a) + 6
    $s = $s.Substring(0, $a).TrimEnd(" ", [char]13, [char]10) + "`r`n" +
         $s.Substring($b).TrimStart(" ", [char]13, [char]10)
    $dropped++
  }

  # add the policy link directly under the social icons. .footer__social holds
  # only <a> elements, so again the first </div> closes it.
  if (-not $s.Contains('footer__policy')) {
    $a = $s.IndexOf('<div class="footer__social">')
    if ($a -ge 0) {
      $b = $s.IndexOf('</div>', $a) + 6
      $link = "`r`n" + '        <a class="footer__policy" href="' + $prefix + $t.slug + $t.sfx + '">' +
              '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">' +
              '<path d="M12 3l7 3v6c0 4.2-2.9 7.7-7 9-4.1-1.3-7-4.8-7-9V6l7-3Z"/></svg>' +
              $t.link + '</a>'
      $s = $s.Substring(0, $b) + $link + $s.Substring($b)
      $linked++
    }
  }
  if ($s -ne $before) { [IO.File]::WriteAllText($f.FullName, $s, $BOM) }
}
Write-Host ("legal column removed : $dropped   policy link added : $linked")

# ---- 3. the placeholder Terms pages the Legal column pointed at
foreach ($n in 'terms.html', 'terms-en.html') {
  $p = Join-Path $repo $n
  if (Test-Path $p) { Remove-Item $p; Write-Host ('  removed ' + $n) }
}
