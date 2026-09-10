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
          eyebrow='ჰაერსატარი'; h2='თუნუქის ჰაერსატარი'
          title='ჰაერსატარი - ბიომი'
          lede='ჰაერსატარები, მუხლები, სამკაპები და გადამყვანები.'
          desc='თუნუქის ჰაერსატარი, მუხლი, სამკაპი და გადამყვანი - სს „ბიომი ჰოლდინგის“ საკუთარი წარმოება.'
          search='ძებნა...'; filter='ფილტრი'; clear='გასუფთავება'
          fType='ტიპი'; fShape='ფორმა'
          empty='პროდუქტი ვერ მოიძებნა.'
          note='ზომები და კონფიგურაცია განისაზღვრება ობიექტის მიხედვით.'
          cta='მოითხოვეთ შეთავაზება'
          # A group in ducting.json that names a page gets one of its own, keyed
          # here by that name; the ducting listing keeps whatever is left over.
          own=[ordered]@{
            accessories=@{ out='accessories.html'; crumb='აქსესუარები'; eyebrow='აქსესუარები'
                           h2='ჰაერსატარის აქსესუარები'
                           title='ჰაერსატარის აქსესუარები - ბიომი'
                           lede='გამოსასვლელი ყუთები, თუნუქის მასალა, გადაბმა და დამჭერები.'
                           desc='ჰაერსატარის აქსესუარები - გამოსასვლელი ყუთები, თუნუქის მასალა, გადაბმა, დამჭერები და რეგულატორი.' }
            grilles=@{     out='grilles.html'; crumb='ცხაურა'; eyebrow='ცხაურა'
                           h2='ცხაურები'
                           title='ცხაურები - ბიომი'
                           lede='ცხაურები ჰაერსატარისა და სავენტილაციო სისტემებისთვის.'
                           desc='ცხაურები ჰაერსატარისა და სავენტილაციო სისტემებისთვის - სს „ბიომი ჰოლდინგი“.' }
          } }
  en = @{ sfx='-en.html'; donor='ventilation-en.html'; out='ducting-en.html'
          crumbHome='Home'; crumbProd='Products'; crumb='Ducting'
          eyebrow='Ducting'; h2='Sheet-metal ducting'
          title='Ducting - Biomi'
          lede='Ducts, elbows, tees and reducers.'
          desc='Sheet-metal ducts, elbows, tees and reducers, made in Biomi Holding''s own plant.'
          search='Search...'; filter='Filter'; clear='Clear'
          fType='Type'; fShape='Shape'
          empty='No products found.'
          note='Sizes and configuration are set by the building.'
          cta='Request a quote'
          own=[ordered]@{
            accessories=@{ out='accessories-en.html'; crumb='Accessories'; eyebrow='Accessories'
                           h2='Ducting accessories'
                           title='Ducting accessories - Biomi'
                           lede='Outlet boxes, sheet material, flange connectors and brackets.'
                           desc='Ducting accessories - outlet boxes, sheet material, flange connectors, brackets and damper regulators.' }
            grilles=@{     out='grilles-en.html'; crumb='Grilles'; eyebrow='Grilles'
                           h2='Grilles'
                           title='Grilles - Biomi'
                           lede='Grilles for duct and ventilation systems.'
                           desc='Grilles for duct and ventilation systems, from Biomi Holding.' }
          } }
}

function Esc([string]$s) { ($s -replace '&(?!(amp|lt|gt|quot|#\d+);)','&amp;' -replace '<','&lt;' -replace '>','&gt;') }

# The shape vocabulary, fixed rather than read off the data: a shape nobody makes
# should still be absent from the filter, not silently appear the day one part
# gets tagged with it. A part may carry two -- a reducer is rectangular at one
# end and round at the other, and belongs under both.
#
# Oval is gone, filter option and both oval parts with it: the range is
# rectangular and round now.
#
# The U-channel, the angle and the sheet carry none. They are profile and raw
# material rather than a shaped part, so a shape filter drops them, which is the
# honest answer rather than filing them under a shape they do not have.
$SHAPES = @(
  @{ slug = 'rect';  ka = 'ოთხკუთხედი'; en = 'Rectangular' },
  @{ slug = 'round'; ka = 'მრგვალი';    en = 'Round' }
)


# Three pages out of one file, and it is the data that says which. A group that
# names a "page" gets one of its own -- the accessories the menu points at, the
# grilles beside them -- and whatever is left is the ducting listing: the parts
# that go in a duct run. They were one grid, which put a sheet of metal between
# two reducers and 23 grilles after it.
$DUCT = @($DATA | Where-Object { -not $_.group.page })
$OWN  = @($DATA | Where-Object { $_.group.page })

# .webp or .jpg, whichever is on disk. The first shots were supplied as WebP;
# the ones after them are written as JPEG by tools/ducting/import.ps1, there
# being no WebP encoder on this machine. Neither the data nor the page has to
# know which is which.
function Shot([string]$img) {
  foreach ($ext in '.webp', '.jpg') {
    if (Test-Path (Join-Path $repo ('assets\img\ducting\' + $img + $ext))) { return ($img + $ext) }
  }
  return ($img + '.webp')
}

# The page furniture -- everything above the hero and everything from the footer
# down -- lifted off a page that already carries it, with the donor's own title,
# description and language switch replaced. Both pages come through here.
function Shell([string]$lang, [string]$title, [string]$desc, [string]$slug) {
  $t = $PAGE[$lang]
  $tpl = [IO.File]::ReadAllText((Join-Path $repo ('products\' + $t.donor)))
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in ' + $t.donor) }
  $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)

  # the meta block belongs to tools/build-meta.ps1; drop the donor's copy so
  # this page does not inherit its canonical URL and description
  $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
  $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $title + '</title>'))
  $head = [regex]::Replace($head, '<meta name="description" content="[^"]*"',
                           ('<meta name="description" content="' + (Esc $desc) + '"'))
  # the donor's language switch still points at the donor
  $head = $head.Replace('href="ventilation.html">GEO<',    'href="' + $slug + '.html">GEO<')
  $head = $head.Replace('href="ventilation-en.html">ENG<', 'href="' + $slug + '-en.html">ENG<')
  $tail = $tail.Replace('href="ventilation.html">GEO<',    'href="' + $slug + '.html">GEO<')
  $tail = $tail.Replace('href="ventilation-en.html">ENG<', 'href="' + $slug + '-en.html">ENG<')
  return @($head, $tail)
}

# One card per part, and the same card on both pages -- a function rather than
# two copies of it: the ducting page hands it four groups and the accessories
# page hands it one.
function Cards($groups, [string]$lang) {
  $rows = New-Object System.Collections.Generic.List[string]
  foreach ($g in $groups) {
    foreach ($it in $g.items) {
      $d = $it.$lang
      # Both languages go into data-name, which is what the search box reads:
      # the parts are ordered by people who say "elbow" as readily as "მუხლი".
      $terms = $d.name + ' ' + $it.ka.name + ' ' + $it.en.name
      $rows.Add('        <figure class="duct" data-type="' + $g.group.slug +
                '" data-shape="' + ($it.shape -join ',') +
                '" data-name="' + (Esc $terms) + '">')
      # data-lightbox: the renders are the whole content of a card, and at
      # 228px a sheet-metal part is a grey shape. Clicking one opens it big,
      # and the arrows walk the range from there.
      $rows.Add('          <span class="duct__shot"><img src="../assets/img/ducting/' + (Shot $it.img) +
                '" alt="' + (Esc $d.name) + '" loading="lazy" width="900" height="600" data-lightbox></span>')
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
  return ,$rows
}

foreach ($lang in 'ka','en') {
  $t = $PAGE[$lang]
  $shell = Shell $lang $t.title $t.desc 'ducting'
  $head = $shell[0]; $tail = $shell[1]

  # ---- the gallery: one flat grid, because the filter now does the grouping
  # the headings used to do. Keeping both would mean a heading left standing
  # over nothing every time its group is filtered out.
  $rows = Cards $DUCT $lang

  # one checkbox per group, in the order the data lists them
  $opts = New-Object System.Collections.Generic.List[string]
  foreach ($g in $DUCT) {
    $opts.Add('            <label><input type="checkbox" name="type" value="' + $g.group.slug +
              '">' + (Esc $g.group.$lang) + '</label>')
  }
  $sopts = New-Object System.Collections.Generic.List[string]
  foreach ($sh in $SHAPES) {
    $sopts.Add('            <label><input type="checkbox" name="shape" value="' + $sh.slug +
               '">' + (Esc $sh.$lang) + '</label>')
  }

  $body = @'
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index{SFX}">{CRUMBHOME}</a><span class="sep">/</span>
      <a href="../products{SFX}">{CRUMBPROD}</a><span class="sep">/</span>
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
        <div class="pfilter__group">
          <h4>{FSHAPE} <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg></h4>
          <div class="pfilter__opts">
{SOPTS}
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
                Replace('{FSHAPE}', $t.fShape).Replace('{EMPTY}', $t.empty).
                Replace('{OPTS}', ($opts -join $CRLF)).
                Replace('{SOPTS}', ($sopts -join $CRLF)).
                Replace('{ROWS}', ($rows -join $CRLF))

  $out = $head + $body + $tail
  $out = [regex]::Replace($out, "`r`n|`n", $CRLF)
  [IO.File]::WriteAllText((Join-Path $repo ('products\' + $t.out)), $out, $UTF8)
  Write-Host ('  wrote products\' + $t.out + ' : ' + (($DUCT | ForEach-Object { $_.items.Count }) |
              Measure-Object -Sum).Sum + ' items')
}

# ---- the pages a group asks for ---------------------------------------------
# One group each, and no shape between the parts in them: a filter column here
# would be a search box and two lists that never change anything. It is the grid
# on its own.
foreach ($g in $OWN) {
  $key = [string]$g.group.page
  foreach ($lang in 'ka','en') {
    $t = $PAGE[$lang]
    $p = $t.own[$key]
    if (-not $p) { throw ('no page strings for "' + $key + '" in ' + $lang) }
    $shell = Shell $lang $p.title $p.desc ($p.out -replace '(-en)?\.html$','')
    $head = $shell[0]; $tail = $shell[1]
    $rows = Cards @($g) $lang

  $body = @'
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index{SFX}">{CRUMBHOME}</a><span class="sep">/</span>
      <a href="../products{SFX}">{CRUMBPROD}</a><span class="sep">/</span>
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
  <div class="container">
    <div class="pgrid">
{ROWS}
    </div>

    <p class="duct__note">{NOTE}
      <a class="btn btn--outline" href="../index{SFX}#contact">{CTA}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a></p>
  </div>
</section>

'@
    $body = $body.Replace('{SFX}', $t.sfx).Replace('{CRUMBHOME}', $t.crumbHome).
                  Replace('{CRUMBPROD}', $t.crumbProd).Replace('{CRUMB}', $p.crumb).
                  Replace('{EYEBROW}', $p.eyebrow).Replace('{H2}', $p.h2).
                  Replace('{LEDE}', $p.lede).
                  Replace('{NOTE}', $t.note).Replace('{CTA}', $t.cta).
                  Replace('{ROWS}', ($rows -join $CRLF))

    $out = $head + $body + $tail
    $out = [regex]::Replace($out, "`r`n|`n", $CRLF)
    [IO.File]::WriteAllText((Join-Path $repo ('products\' + $p.out)), $out, $UTF8)
    Write-Host ('  wrote products\' + $p.out + ' : ' + $g.items.Count + ' items')
  }
}
