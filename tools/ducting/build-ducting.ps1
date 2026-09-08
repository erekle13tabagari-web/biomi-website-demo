# The ducting page: one gallery, not sixteen product pages.
#
# These are made-to-order sheet-metal parts, so a card-and-page-per-item
# listing would be sixteen pages each saying a name and showing one render.
# They are a gallery instead, grouped by what the part does, with the
# dimensions written beside the ones that have them.
#
# ---- what the spec lines may say
#
# Only what the supplier's own pages state. Three of the sixteen carry
# dimension fields (the rectangular, round and oval ducts); the rest give a
# name and a photo and nothing else, so they carry no spec line at all rather
# than an invented one. Gauge, material grade and standards are not published
# anywhere we can see -- when the factory supplies them, add them to the
# "spec" arrays in ducting.json and re-run. Nothing here needs changing.
#
# Prices are deliberately absent.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10

$DATA = Get-Content (Join-Path $sp 'ducting.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# $PAGE, not $T: PowerShell variable names are case-insensitive, so $t = $PAGE[$lang]
# inside the loop would overwrite the table with its own first entry.
$PAGE = @{
  ka = @{ sfx='.html'; donor='ventilation.html'; out='ducting.html'
          crumbHome='მთავარი'; crumbProd='პროდუქტი'; crumb='ჰაერსატარი'
          eyebrow='ჰაერსატარი'; h2='თუნუქის ჰაერსატარი და მაკომპლექტებელი'
          title='ჰაერსატარი და მაკომპლექტებელი - ბიომი'
          lede='ჰაერსატარები, მუხლები, სამკაპები და გადამყვანები.'
          desc='თუნუქის ჰაერსატარი, მუხლი, სამკაპი, გადამყვანი და მაკომპლექტებელი - სს „ბიომი ჰოლდინგის“ საკუთარი წარმოება.'
          search='ძებნა...'; filter='ფილტრი'; clear='გასუფთავება'; fType='ტიპი'
          empty='პროდუქტი ვერ მოიძებნა.'
          note='ზომები და კონფიგურაცია განისაზღვრება ობიექტის მიხედვით.'
          cta='მოითხოვეთ შეთავაზება' }
  en = @{ sfx='-en.html'; donor='ventilation-en.html'; out='ducting-en.html'
          crumbHome='Home'; crumbProd='Products'; crumb='Ducting'
          eyebrow='Ducting'; h2='Sheet-metal ducting and fittings'
          title='Ducting and fittings - Biomi'
          lede='Ducts, elbows, tees and reducers.'
          desc='Sheet-metal ducts, elbows, tees, reducers and fittings, made in Biomi Holding''s own plant.'
          search='Search...'; filter='Filter'; clear='Clear'; fType='Type'
          empty='No products found.'
          note='Sizes and configuration are set by the building.'
          cta='Request a quote' }
}

function Esc([string]$s) { ($s -replace '&(?!(amp|lt|gt|quot|#\d+);)','&amp;' -replace '<','&lt;' -replace '>','&gt;') }

foreach ($lang in 'ka','en') {
  $t = $PAGE[$lang]
  $tpl = [IO.File]::ReadAllText((Join-Path $repo ('products\' + $t.donor)))
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in ' + $t.donor) }
  $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)

  # the meta block belongs to tools/build-meta.ps1; drop the donor's copy so
  # this page does not inherit its canonical URL and description
  $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
  $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $t.title + '</title>'))
  $head = [regex]::Replace($head, '<meta name="description" content="[^"]*"',
                           ('<meta name="description" content="' + (Esc $t.desc) + '"'))
  # the donor's language switch still points at the donor
  $head = $head.Replace('href="ventilation.html">GEO<',    'href="ducting.html">GEO<')
  $head = $head.Replace('href="ventilation-en.html">ENG<', 'href="ducting-en.html">ENG<')
  $tail = $tail.Replace('href="ventilation.html">GEO<',    'href="ducting.html">GEO<')
  $tail = $tail.Replace('href="ventilation-en.html">ENG<', 'href="ducting-en.html">ENG<')

  # ---- the gallery: one flat grid, because the filter now does the grouping
  # the headings used to do. Keeping both would mean a heading left standing
  # over nothing every time its group is filtered out.
  $rows = New-Object System.Collections.Generic.List[string]
  foreach ($g in $DATA) {
    foreach ($it in $g.items) {
      $d = $it.$lang
      # Both languages go into data-name, which is what the search box reads:
      # the parts are ordered by people who say "elbow" as readily as "მუხლი".
      $terms = $d.name + ' ' + $it.ka.name + ' ' + $it.en.name
      $rows.Add('        <figure class="duct" data-type="' + $g.group.slug +
                '" data-name="' + (Esc $terms) + '">')
      $rows.Add('          <span class="duct__shot"><img src="../assets/img/ducting/' + $it.img +
                '.webp" alt="' + (Esc $d.name) + '" loading="lazy" width="900" height="600"></span>')
      $rows.Add('          <figcaption>')
      $rows.Add('            <b>' + (Esc $d.name) + '</b>')
      if ($d.spec.Count) {
        $rows.Add('            <ul>')
        foreach ($s in $d.spec) { $rows.Add('              <li>' + (Esc $s) + '</li>') }
        $rows.Add('            </ul>')
      }
      $rows.Add('          </figcaption>')
      $rows.Add('        </figure>')
    }
  }

  # one checkbox per group, in the order the data lists them
  $opts = New-Object System.Collections.Generic.List[string]
  foreach ($g in $DATA) {
    $opts.Add('            <label><input type="checkbox" name="type" value="' + $g.group.slug +
              '">' + (Esc $g.group.$lang) + '</label>')
  }

  $body = @'
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index{SFX}">{CRUMBHOME}</a><span class="sep">/</span>
      <a href="ventilation{SFX}">{CRUMBPROD}</a><span class="sep">/</span>
      <b>{CRUMB}</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">{EYEBROW}</span>
      <h2>{H2}</h2>
      <p class="page-lede">{LEDE}</p>
    </div>
  </div>
</section>

<section class="section" style="padding-top:26px">
  <div class="container" data-plist>
    <div class="plist">
      <aside class="pfilter">
        <div class="pfilter__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
          <input type="search" placeholder="{SEARCH}">
        </div>
        <div class="pfilter__head"><span>{FILTER}</span><a data-clear>{CLEAR}</a></div>
        <div class="pfilter__group">
          <h4>{FTYPE} <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg></h4>
          <div class="pfilter__opts">
{OPTS}
          </div>
        </div>
      </aside>

      <div class="pgrid">
{ROWS}
        <div class="pgrid__empty" style="display:none">{EMPTY}</div>
      </div>
    </div>

    <p class="duct__note">{NOTE}
      <a class="btn btn--outline" href="../index{SFX}#contact">{CTA}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a></p>
  </div>
</section>

'@
  $body = $body.Replace('{SFX}', $t.sfx).Replace('{CRUMBHOME}', $t.crumbHome).
                Replace('{CRUMBPROD}', $t.crumbProd).Replace('{CRUMB}', $t.crumb).
                Replace('{EYEBROW}', $t.eyebrow).Replace('{H2}', $t.h2).Replace('{LEDE}', $t.lede).
                Replace('{NOTE}', $t.note).Replace('{CTA}', $t.cta).
                Replace('{SEARCH}', $t.search).Replace('{FILTER}', $t.filter).
                Replace('{CLEAR}', $t.clear).Replace('{FTYPE}', $t.fType).
                Replace('{EMPTY}', $t.empty).
                Replace('{OPTS}', ($opts -join $CRLF)).
                Replace('{ROWS}', ($rows -join $CRLF))

  $out = $head + $body + $tail
  $out = [regex]::Replace($out, "`r`n|`n", $CRLF)
  [IO.File]::WriteAllText((Join-Path $repo ('products\' + $t.out)), $out, $UTF8)
  Write-Host ('  wrote products\' + $t.out + ' : ' + (($DATA | ForEach-Object { $_.items.Count }) |
              Measure-Object -Sum).Sum + ' items')
}
