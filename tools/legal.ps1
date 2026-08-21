# Adds the Legal column to the footer on every page, and creates the pages it
# points at.
#
# The footer is hand-written into all 160 pages rather than generated, so this
# script is the only safe way to change its shape: doing it by hand guarantees
# drift between languages and folders.
#
# The pages live at the repo root next to about.html, NOT in a legal/ folder.
# A subfolder would mean rewriting every relative path in the spliced chrome
# (assets/, index.html, products/…) for no benefit at this size.
#
# The Terms page is a deliberate placeholder: it says the terms are being
# prepared and gives contact details. No invented legal text -- a fabricated
# terms-of-service is worse than an honest empty one. Replace the body between
# the page-hero and the FOOTER marker when the real document arrives.
$repo = Split-Path $PSScriptRoot -Parent

$L = @{
  ka = @{ sfx='.html';    h4='იურიდიული'; terms='მომხმარებლის პირობები'
          eyebrow='იურიდიული'; home='მთავარი'
          title='მომხმარებლის პირობები — ბიომი'
          lede='გამოყენების პირობები მზადდება და მალე გამოქვეყნდება ამ გვერდზე.'
          body='ამ დროისთვის დეტალებისთვის დაგვიკავშირდით:' }
  en = @{ sfx='-en.html'; h4='Legal';      terms='Terms of Service'
          eyebrow='Legal'; home='Home'
          title='Terms of Service — Biomi'
          lede='Our terms of use are being prepared and will be published on this page.'
          body='In the meantime, please get in touch:' }
}

# ---- 1. the pages themselves, spliced off about.html for chrome
foreach ($lang in 'ka','en') {
  $t = $L[$lang]
  $src = Join-Path $repo ('about' + $t.sfx)
  $tpl = Get-Content $src -Raw -Encoding UTF8
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw "markers not found in $src" }
  $head = $tpl.Substring(0,$i); $tail = $tpl.Substring($j)
  # the meta block is owned by tools/build-meta.ps1; drop about.html's copy so
  # this page does not inherit its canonical and description
  $head = [regex]::Replace($head,'(?s)<!-- meta:start -->.*?<!-- meta:end -->\s*','')
  $head = [regex]::Replace($head,'(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
  $body = @"
<section class="page-hero">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="index$($t.sfx)">$($t.home)</a><span class="sep">/</span>
      <b>$($t.terms)</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">$($t.eyebrow)</span>
      <h2>$($t.terms)</h2>
      <p class="page-lede">$($t.lede)</p>
    </div>
  </div>
</section>

<section class="section">
  <div class="container">
    <p style="color:var(--muted);max-width:66ch">$($t.body)
      <a href="mailto:info@biomi.ge">info@biomi.ge</a> &middot;
      <a href="tel:+995322151115">+995 322 15 11 15</a></p>
  </div>
</section>

"@
  $out = Join-Path $repo ('terms' + $t.sfx)
  [IO.File]::WriteAllText($out, ($head + $body + $tail), (New-Object Text.UTF8Encoding($false)))
  Write-Host ("  wrote terms" + $t.sfx)
}

# ---- 2. the footer column, on every page
$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and
                        $_.FullName -notmatch 'backup|_files' -and
                        $_.FullName -notlike '*.git*' -and $_.FullName -notlike '*.claude*' }
$done = 0; $skip = 0
foreach ($f in $files) {
  $s = [IO.File]::ReadAllText($f.FullName)
  if ($s.Contains('footer__legal')) { $skip++; continue }
  $anchor = $s.IndexOf('<div class="footer__bottom">')
  if ($anchor -lt 0) { continue }
  # the </div> immediately before footer__bottom closes .footer__grid
  $close = $s.LastIndexOf('</div>', $anchor)
  if ($close -lt 0) { continue }
  $t = if ($f.Name -like '*-en.html') { $L['en'] } else { $L['ka'] }
  # depth: root pages link straight at terms.html, anything in a subfolder needs ../
  $prefix = if ((Split-Path $f.FullName -Parent) -eq $repo) { '' } else { '../' }
  $col = "`r`n" + @"
      <div class="footer__legal">
        <h4>$($t.h4)</h4>
        <nav class="footer__links">
          <a href="$($prefix + 'terms' + $t.sfx)">$($t.terms)</a>
        </nav>
      </div>

"@
  $s = $s.Substring(0,$close) + $col + $s.Substring($close)
  [IO.File]::WriteAllText($f.FullName, $s, (New-Object Text.UTF8Encoding($true)))
  $done++
}
Write-Host ("footer updated : $done   already had it : $skip")
