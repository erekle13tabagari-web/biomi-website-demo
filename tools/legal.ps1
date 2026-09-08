# The two legal pages, and the footer links that reach them.
#
# Replaces the earlier "Legal" footer column, which this script removes: the
# column carried a single placeholder Terms of Service link. The real documents
# sit as links under the social icons instead of a whole column of their own.
#
# The footer is hand-written into every page rather than generated, so this
# script is the only safe way to change its shape -- doing it by hand guarantees
# drift between languages and folders.
#
# ---- where the text comes from
#
# Each document's body lives in tools/legal/<slug>-ka.html, generated from the
# .docx the client sends. This script only wraps it in the page. Earlier the
# privacy policy was six page images built into this script, so re-running it
# would have overwritten the text version; keeping the body in a file means a
# new draft is a fragment swap and a re-run, and nothing here has to change.
#
# The images are gone. They were a deterrent against copying, but a policy has
# to be readable by a screen reader, searchable and quotable, and the deterrent
# was thin anyway -- nothing on a web page stops a screenshot.
#
# ---- English
#
# Both documents exist in Georgian only. The English pages carry English chrome
# and the Georgian text, which is what the English lede says. Swap in an -en
# fragment here once a translation exists.
$repo  = Split-Path $PSScriptRoot -Parent
$BOM   = New-Object Text.UTF8Encoding($true)
$NOBOM = New-Object Text.UTF8Encoding($false)

# the documents, in the order their links appear in the footer
$DOCS = @(
  @{ slug='privacy'; body='privacy-ka.html'
     ka = @{ link='კონფიდენციალურობის პოლიტიკა'
             title='კონფიდენციალურობის პოლიტიკა - ბიომი'
             h2='კონფიდენციალურობის პოლიტიკა'
             lede='სს „ბიომი ჰოლდინგის“ პერსონალურ მონაცემთა დაცვის პოლიტიკა.' }
     en = @{ link='Privacy Policy'
             title='Privacy Policy - Biomi'
             h2='Privacy Policy'
             lede='The personal-data protection policy of JSC Biomi Holding, published in Georgian.' } }
  @{ slug='consent'; body='consent-ka.html'
     ka = @{ link='თანხმობა პერსონალურ მონაცემთა დამუშავების შესახებ'
             title='თანხმობა პერსონალურ მონაცემთა დამუშავების შესახებ - ბიომი'
             h2='თანხმობა პერსონალურ მონაცემთა დამუშავების შესახებ'
             lede='რა მონაცემებს ვამუშავებთ ონლაინ ფორმიდან, რა მიზნით და რაზე გაძლევთ არჩევანს.' }
     en = @{ link='Data Processing Consent'
             title='Consent to the processing of personal data - Biomi'
             h2='Consent to the processing of personal data'
             lede='What we do with the data sent through the online form, why, and what you get to choose. Published in Georgian.' } }
)

# $CHROME, not $LANG: PowerShell variable names are case-insensitive, so the
# foreach ($lang in ...) below would empty the table on its first pass.
$CHROME = @{
  ka = @{ sfx='.html';    eyebrow='იურიდიული'; home='მთავარი'
          note='დოკუმენტთან დაკავშირებული კითხვებისთვის დაგვიკავშირდით:' }
  en = @{ sfx='-en.html'; eyebrow='Legal';     home='Home'
          note='For questions about this document, please get in touch:' }
}

# ---- 1. the pages, spliced off about.html for chrome
foreach ($doc in $DOCS) {
  $fragment = [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('legal\' + $doc.body)))
  foreach ($lang in 'ka','en') {
    $g = $CHROME[$lang]; $t = $doc[$lang]
    $tpl = [IO.File]::ReadAllText((Join-Path $repo ('about' + $g.sfx)))
    $i = $tpl.IndexOf('<section class="page-hero')
    $j = $tpl.IndexOf('<!-- ===================== FOOTER')
    if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in about' + $g.sfx) }
    $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)
    # the meta block belongs to tools/build-meta.ps1; drop about.html's copy so
    # this page does not inherit its canonical URL and description
    $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
    $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
    # The chrome still carries About's own language switch -- one copy in the
    # header ($head) and one in the drawer ($tail). Matching on the GEO/ENG
    # labels leaves the nav's link to the About page alone.
    # Both replacements are parenthesised: PowerShell binds the comma tighter
    # than +, so without them the element is just 'href="' and the language
    # switch gets flattened into href="/a>.
    foreach ($pair in @(@('href="about.html">GEO<',    ('href="' + $doc.slug + '.html">GEO<')),
                        @('href="about-en.html">ENG<', ('href="' + $doc.slug + '-en.html">ENG<')))) {
      $head = $head.Replace($pair[0], $pair[1])
      $tail = $tail.Replace($pair[0], $pair[1])
    }

    $body = @'
<section class="page-hero page-hero--policy">
  <div class="container">
    <div class="policy-head">
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
  </div>
</section>

<section class="section">
  <div class="container">
      <div class="policy" role="document" aria-label="{H2}">
{BODY}
      </div>
      <p class="policy__note">{NOTE}
        <a href="mailto:info@biomi.ge">info@biomi.ge</a> &middot;
        <a href="tel:+995322151115">+995 322 15 11 15</a></p>
  </div>
</section>

'@
    $body = $body.Replace('{SFX}', $g.sfx).Replace('{HOME}', $g.home).Replace('{H2}', $t.h2).
                  Replace('{EYEBROW}', $g.eyebrow).Replace('{LEDE}', $t.lede).
                  Replace('{BODY}', $fragment).Replace('{NOTE}', $g.note)

    [IO.File]::WriteAllText((Join-Path $repo ($doc.slug + $g.sfx)), ($head + $body + $tail), $NOBOM)
    Write-Host ('  wrote ' + $doc.slug + $g.sfx)
  }
}

# ---- 2. the footer, on every page: drop the Legal column, add the policy links
$SHIELD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">' +
          '<path d="M12 3l7 3v6c0 4.2-2.9 7.7-7 9-4.1-1.3-7-4.8-7-9V6l7-3Z"/></svg>'

$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and
                        $_.FullName -notmatch 'backup|_files' -and
                        $_.FullName -notlike '*.git*' -and $_.FullName -notlike '*.claude*' }
$dropped = 0; $linked = 0
foreach ($f in $files) {
  $s = [IO.File]::ReadAllText($f.FullName)
  $before = $s
  $lang = if ($f.Name -like '*-en.html') { 'en' } else { 'ka' }
  $sfx  = $CHROME[$lang].sfx
  # root pages link straight at the page; anything in a subfolder needs ../
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

  # The links live in their own wrapper under the social icons. The wrapper is
  # what the footer's phone layout moves below the map, so the two links travel
  # together instead of being repositioned one at a time.
  $links = ''
  foreach ($doc in $DOCS) {
    $links += "`r`n" + '          <a class="footer__policy" href="' + $prefix + $doc.slug + $sfx + '">' +
              $SHIELD + $doc[$lang].link + '</a>'
  }
  $block = "`r`n" + '        <div class="footer__policies">' + $links + "`r`n" + '        </div>'

  if ($s.Contains('<div class="footer__policies">')) {
    # rebuild it, so a changed label or a new document lands on every page
    $a = $s.IndexOf('<div class="footer__policies">')
    $b = $s.IndexOf('</div>', $s.LastIndexOf('</a>', $s.IndexOf('</div>', $s.IndexOf('<a class="footer__policy"', $a))))
    $b = $s.IndexOf('</div>', $a)
    # step past each nested </a> to the wrapper's own </div>
    $scan = $a
    while ($true) {
      $nextA = $s.IndexOf('<a class="footer__policy"', $scan + 1)
      $close = $s.IndexOf('</div>', $scan + 1)
      if ($nextA -lt 0 -or $nextA -gt $close) { $b = $close + 6; break }
      $scan = $nextA
    }
    $s = $s.Substring(0, $a).TrimEnd(" ", [char]13, [char]10) + $block.TrimStart([char]13, [char]10) +
         $s.Substring($b)
    $linked++
  }
  else {
    # first run on this page: place the block under the social icons.
    # .footer__social holds only <a> elements, so the first </div> closes it.
    # An older single link may be sitting there; take it out first.
    $s = [regex]::Replace($s, '(?s)\s*<a class="footer__policy".*?</a>', '')
    $a = $s.IndexOf('<div class="footer__social">')
    if ($a -ge 0) {
      $b = $s.IndexOf('</div>', $a) + 6
      $s = $s.Substring(0, $b) + $block + $s.Substring($b)
      $linked++
    }
  }
  if ($s -ne $before) { [IO.File]::WriteAllText($f.FullName, $s, $BOM) }
}
Write-Host ("legal column removed : $dropped   footer links written : $linked")

# ---- 3. the placeholder Terms pages the Legal column pointed at
foreach ($n in 'terms.html', 'terms-en.html') {
  $p = Join-Path $repo $n
  if (Test-Path $p) { Remove-Item $p; Write-Host ('  removed ' + $n) }
}
