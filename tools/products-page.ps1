# The product catalogue as a page, and the holding page behind it.
#
# The menu's "პროდუქტი" pointed at #products, a homepage section that has since
# been hidden, so the top-level product link went nowhere on all 164 pages.
# This builds the destination it should have had: the same tree the dropdown is
# drawn from, laid out to be read rather than hovered.
#
# menu-tree.json is the single source for both. Add a category there and it
# appears in the menu, the drawer and this page together; there is no second
# list to keep in step.
#
# Items with "page": null are ranges we carry but have no listing for yet. They
# used to be dead anchors. They point at soon.html now, which says so plainly
# and offers the contact form -- a customer who wants underfloor heating should
# reach a sentence and a way to ask, not a link that does nothing.
$sp   = $PSScriptRoot
$repo = Split-Path $sp -Parent
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10

$TREE = Get-Content (Join-Path $sp 'menu-tree.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# One pictogram per chapter, at assets/img/cat-icons/<icon>.svg, where <icon> is
# the chapter's "icon" field in menu-tree.json. To swap one, replace that file.
#
# Linked rather than inlined, which matters here: these are Illustrator exports
# and all five declare the same .st0-.st76 class names in their own <style>
# block. Inline, those blocks are global to the page and the last one read would
# restyle the other four. As <img> each file is its own document, so the classes
# and the clip-path ids stay inside it. They are brand-coloured by design -- a
# ring and a symbol per category -- so they want no colour from the page, which
# is what would otherwise argue for inlining them.
$ICODIR = 'assets/img/cat-icons/'

# What each chapter shows beside its categories, keyed on the chapter's own icon
# slug so a chapter cannot end up with a pictogram and no picture.
#
# Two layers. photo is the scene -- one of our own installations wherever there
# is one, which is four of the five. hero is the product standing in front of
# it: a transparent cut-out written by tools/cutout.ps1 from the render the
# listing already uses, so the boiler in front of "გათბობა" is a boiler we sell.
# The renders themselves are shot on solid white and cannot be laid over a
# photograph as they are -- that script is what makes them into a cut-out.
#
# Water supply has no listing yet and so no product to stand there; its panel is
# the photograph alone, and the layout closes the gap under it.
# Paths have no prefix: products.html sits at the site root.
$MEDIA = @{
  'heating'     = @{ photo = 'assets/img/terminal-gallery/terminal-7.avif'
                     hero  = 'assets/img/cutouts/heating.png' }
  'cooling'     = @{ photo = 'assets/img/prod-cooling.jpg'
                     hero  = 'assets/img/cutouts/cooling.png' }
  'ventilation' = @{ photo = 'assets/img/terminal-gallery/terminal-5.avif'
                     hero  = 'assets/img/cutouts/ventilation.png' }
  'ducting'     = @{ photo = 'assets/img/news-duct-production.jpg'
                     hero  = 'assets/img/cutouts/ducting.png' }
  'water'       = @{ photo = 'assets/img/prod-water.jpg'
                     hero  = '' }
}

# $PAGE, not $T: PowerShell variable names are case-insensitive, so $t = $PAGE[$lang]
# inside the loop would overwrite the table with its own first entry.
$PAGE = @{
  ka = @{ sfx='.html'
          crumbHome='მთავარი'; crumb='პროდუქტი'
          eyebrow='პროდუქტი'; h2='ჩვენი პროდუქცია'
          title='პროდუქტი - ბიომი'
          # No standing lede on either page: the chapter headings below say what
          # the catalogue holds, and the holding page's own heading is already
          # the whole message. desc stays - that is the search-result text.
          desc='ბიომი ჰოლდინგის პროდუქცია - ქვაბები, ბოილერები, კონდიცირება, ვენტილაცია, ჰაერსატარები და წყალმომარაგება.'
          soonTitle='მალე დაემატება - ბიომი'
          soonH2='პროდუქტები მალე დაემატება'
          soonCrumb='მალე დაემატება'
          soonDesc='ბიომი ჰოლდინგის პროდუქციის ეს განყოფილება მალე დაემატება.'
          cta='დაგვიკავშირდით'; back='პროდუქციაზე დაბრუნება' }
  en = @{ sfx='-en.html'
          crumbHome='Home'; crumb='Products'
          eyebrow='Products'; h2='Our products'
          title='Products - Biomi'
          desc='Products from Biomi Holding - boilers, water heaters, air conditioning, ventilation, ducting and water supply.'
          soonTitle='Coming soon - Biomi'
          soonH2='Products will be added soon'
          soonCrumb='Coming soon'
          soonDesc='This part of the Biomi Holding catalogue will be added soon.'
          cta='Get in touch'; back='Back to products' }
}

function Esc([string]$s) { ($s -replace '&(?!(amp|lt|gt|quot|#\d+);)','&amp;' -replace '<','&lt;' -replace '>','&gt;') }

# A node can pin any of the listing's filters: ?cat= for a section of the range,
# ?brand= for a make, the two together for a make within a section. The listing
# ticks the matching boxes from the query string, so this is the whole mechanism.
# Same shape as Href in tools/menu-rebuild.ps1, which reads the same tree.
function Query($n) {
  $q = @()
  if ($n.cat)   { $q += 'cat='   + $n.cat }
  if ($n.brand) { $q += 'brand=' + $n.brand }
  # &amp;, not &: the result only ever goes into an href attribute, and a bare
  # ampersand there is an unterminated character reference.
  if ($q.Count) { return '?' + ($q -join '&amp;') }
  return ''
}

$ARROW = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'

# No renders on the cards. Only five of the eleven categories have product
# photography at all, so six would have sat empty beside them, and the images
# made each card tall enough that the four columns could not balance.

# Build one page out of about.html's chrome. Same approach as the ducting
# builder: take the head and the footer, drop the donor's meta block so
# build-meta.ps1 can write a correct one, and repoint the language switch.
function Shell([string]$title, [string]$desc, [string]$body, [string]$outName, [string]$sfx) {
  $tpl = [IO.File]::ReadAllText((Join-Path $repo ('about' + $sfx)))
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in about' + $sfx) }
  $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)

  $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
  $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $title + '</title>'))
  $head = [regex]::Replace($head, '<meta name="description" content="[^"]*"',
                           ('<meta name="description" content="' + (Esc $desc) + '"'))
  # the donor's language switch still points at the donor
  $base = $outName -replace '(-en)?\.html$',''
  foreach ($part in 'head','tail') {
    $v = if ($part -eq 'head') { $head } else { $tail }
    $v = $v.Replace('href="about.html">GEO<',    ('href="' + $base + '.html">GEO<'))
    $v = $v.Replace('href="about-en.html">ENG<', ('href="' + $base + '-en.html">ENG<'))
    if ($part -eq 'head') { $head = $v } else { $tail = $v }
  }

  $out = $head + $body + $tail
  $out = [regex]::Replace($out, "`r`n|`n", $CRLF)
  [IO.File]::WriteAllText((Join-Path $repo $outName), $out, $UTF8)
}

foreach ($lang in 'ka','en') {
  $t = $PAGE[$lang]; $sfx = $t.sfx

  # ---- the catalogue: a rail of chapters, and a panel for the highlighted one
  #
  # The five chapters were five columns side by side, which meant reading across
  # a wall of every category at once. They are a rail now, with one chapter at a
  # time beside it: its name, its categories and one of its products.
  #
  # Every panel is in the markup either way. main.js adds .catalog--tabs, and
  # only under that class does the rail appear and the inactive panels go away.
  # With no JavaScript the rail -- five buttons that would do nothing -- is never
  # shown and the five chapters stack, which is what the page was before and what
  # a crawler reads regardless.
  #
  # No roles or aria-selected here for the same reason: the tab semantics are
  # only true once the script has run, so main.js is what writes them.
  $rows = New-Object System.Collections.Generic.List[string]
  $items = 0

  $rows.Add('      <div class="catalog__rail">')
  $first = $true
  foreach ($ch in $TREE) {
    $on  = if ($first) { ' is-on' } else { '' }
    # the subtitle previews what is inside rather than repeating the chapter
    $names = (($ch.items | ForEach-Object { $_.$lang }) -join ' · ')
    $rows.Add('        <button class="cat-tab' + $on + '" type="button" data-ch="' + $ch.icon + '">')
    if ($ch.icon) {
      # Empty alt: the chapter name is right beside it, so a description here
      # would only say the same thing twice.
      $rows.Add('          <img class="cat-tab__ico" src="' + $ICODIR + $ch.icon +
                '.svg" alt="" width="34" height="34">')
    }
    $rows.Add('          <span class="cat-tab__txt"><b>' + (Esc $ch.$lang) + '</b><small>' +
              (Esc $names) + '</small></span>')
    $rows.Add('        </button>')
    $first = $false
  }
  $rows.Add('      </div>')

  $rows.Add('      <div class="catalog__view">')
  $first = $true
  foreach ($ch in $TREE) {
    $on = if ($first) { ' is-on' } else { '' }
    $first = $false
    $rows.Add('      <section class="catalog__chapter' + $on + '" data-ch="' + $ch.icon + '">')
    $rows.Add('        <h3>' + (Esc $ch.$lang) + '</h3>')
    # The pictogram is the rail's job now -- it names the chapter there, beside
    # the tab it belongs to, and repeating it over the heading it already sits
    # next to said the same thing twice.
    #
    # Both pictures are decorative: the heading beside them names the chapter
    # and the list under it names every category, so alt text here would only
    # repeat what a screen reader has already read.
    if ($MEDIA.ContainsKey([string]$ch.icon)) {
      $m = $MEDIA[[string]$ch.icon]
      # Only the open chapter's pictures are wanted up front. The other four
      # panels are display:none until their tab is chosen, and a lazy image
      # inside one is not fetched until it is -- which is the whole reason the
      # cut-outs can be PNGs at all.
      $lazy = if ($on) { '' } else { ' loading="lazy"' }
      $plain = if ($m.hero) { '' } else { ' catalog__media--plain' }
      $rows.Add('        <div class="catalog__media' + $plain + '">')
      $rows.Add('          <div class="catalog__frame"><img class="catalog__photo" src="' +
                $m.photo + '" alt=""' + $lazy + '></div>')
      if ($m.hero) {
        $rows.Add('          <img class="catalog__hero" src="' + $m.hero + '" alt=""' + $lazy + '>')
      }
      $rows.Add('        </div>')
    }
    $rows.Add('        <div class="catalog__grid">')
    foreach ($it in $ch.items) {
      $items++
      $kids = @($it.kids)
      if ($it.page) {
        $href = 'products/' + $it.page + $sfx + (Query $it)
        $rows.Add('          <div class="catalog__item">')
        $rows.Add('            <a class="catalog__name" href="' + $href + '">' + (Esc $it.$lang) + ' ' + $ARROW + '</a>')
        if ($kids.Count) {
          $rows.Add('            <div class="catalog__subs">')
          foreach ($k in $kids) {
            # the listing pre-ticks from the query, so a brand here lands on that
            # brand's products rather than the whole category -- and a kid that
            # also carries a section lands inside it
            $kh = if ($k.page) { 'products/' + $k.page + $sfx + (Query $k) }
                  else { 'soon' + $sfx }
            $rows.Add('              <a href="' + $kh + '">' + (Esc $k.$lang) + '</a>')
          }
          $rows.Add('            </div>')
        }
        $rows.Add('          </div>')
      } else {
        # no listing yet: the name goes to the holding page, and the sub-items
        # stay as plain text so the customer still sees what the range covers
        $rows.Add('          <div class="catalog__item catalog__item--soon">')
        $rows.Add('            <a class="catalog__name" href="soon' + $sfx + '">' + (Esc $it.$lang) + ' ' + $ARROW + '</a>')
        if ($kids.Count) {
          $rows.Add('            <div class="catalog__subs">')
          foreach ($k in $kids) { $rows.Add('              <span>' + (Esc $k.$lang) + '</span>') }
          $rows.Add('            </div>')
        }
        $rows.Add('          </div>')
      }
    }
    $rows.Add('        </div>')
    $rows.Add('      </section>')
  }
  $rows.Add('      </div>')

  $body = @'
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="index{SFX}">{CRUMBHOME}</a><span class="sep">/</span>
      <b>{CRUMB}</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">{EYEBROW}</span>
      <h2>{H2}</h2>
    </div>
  </div>
</section>

<section class="section" style="padding-top:26px">
  <div class="container">
    <div class="catalog">
{ROWS}
    </div>
  </div>
</section>

'@
  $body = $body.Replace('{SFX}', $sfx).Replace('{CRUMBHOME}', $t.crumbHome).
                Replace('{CRUMB}', $t.crumb).Replace('{EYEBROW}', $t.eyebrow).
                Replace('{H2}', $t.h2).
                Replace('{ROWS}', ($rows -join $CRLF))

  Shell $t.title $t.desc $body ('products' + $sfx) $sfx
  Write-Host ('  wrote products' + $sfx + ' : ' + $TREE.Count + ' chapters, ' + $items + ' categories')

  # ---- the holding page
  $soon = @'
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="index{SFX}">{CRUMBHOME}</a><span class="sep">/</span>
      <a href="products{SFX}">{CRUMB}</a><span class="sep">/</span>
      <b>{SOONCRUMB}</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">{EYEBROW}</span>
      <h2>{SOONH2}</h2>
    </div>
  </div>
</section>

<section class="section" style="padding-top:26px">
  <div class="container">
    <p class="duct__note">
      <a class="btn btn--outline" href="products{SFX}">{BACK}</a>
      <a class="btn btn--gold" href="index{SFX}#contact">{CTA}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a></p>
  </div>
</section>

'@
  $soon = $soon.Replace('{SFX}', $sfx).Replace('{CRUMBHOME}', $t.crumbHome).
                Replace('{CRUMB}', $t.crumb).Replace('{SOONCRUMB}', $t.soonCrumb).
                Replace('{EYEBROW}', $t.eyebrow).Replace('{SOONH2}', $t.soonH2).
                Replace('{BACK}', $t.back).
                Replace('{CTA}', $t.cta)

  Shell $t.soonTitle $t.soonDesc $soon ('soon' + $sfx) $sfx
  Write-Host ('  wrote soon' + $sfx)
}
