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
# ---- the pictures -----------------------------------------------------------
#
# All of them are written by tools/cutout.ps1 out of the menu-images folder, and
# all of them are found here by name rather than listed in a table. Drop a
# picture into the right folder, re-run that script, and this one picks it up:
#
#   assets/img/cat-bg/<icon>.jpg             the wash behind the whole band
#   assets/img/cutouts/sm/<icon>.png         the chapter's own product
#   assets/img/cutouts/sm/<icon>-<key>.png   one category's product, <key> being
#                                            the category's cat= filter where it
#                                            has one and its page otherwise
#
# The sm copies, not the full-size ones beside them: a card is about 280px wide
# and a chapter shows several at once, where the full cut-out is sized to be one
# picture filling half a page.
#
# A chapter with no product of its own lends it to the first of its categories
# that has none, so heating's boiler and cooling's outdoor unit land where they
# belong without anything having to say so.
# Paths have no prefix: products.html sits at the site root.
$SMDIR = 'assets/img/cutouts/sm/'
$BGDIR  = 'assets/img/cat-bg/'
# A category photographed in place rather than cut out, as a 4:3 JPEG -- see
# tools/water/build-water.ps1. Only looked at where there is no cut-out.
$PHOTODIR = 'assets/img/cat-photo/'

# The slug a category's picture is filed under. The four ventilation categories
# share one listing and are told apart by cat=, so that comes first.
function PicKey($it) {
  if ($it.cat)  { return [string]$it.cat }
  if ($it.page) { return [string]$it.page }
  return ''
}
# Returns the path if the file is actually there, and '' if it is not -- so a
# category with no picture yet simply has none, rather than a broken image.
function PicFor([string]$rel) {
  if ($rel -and (Test-Path (Join-Path $repo ($rel -replace '/','\')))) { return $rel }
  return ''
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

# Two things the page can carry under a name, both off for now:
#
#   RAIL_PREVIEW  the categories of a chapter, listed small under its name in
#                 the rail -- "ქვაბი · ბოილერები · იატაკის გათბობა · აქსესუარები"
#   BRAND_CHIPS   the makes under each category in the panel, as pill links that
#                 land on that make's products
#
# Set either back to $true and re-run; the CSS for both is still in place, so
# nothing else has to change. Kept as switches rather than deleted because this
# is a "for now", not a decision.
$RAIL_PREVIEW = $false
$BRAND_CHIPS  = $false

function Esc([string]$s) { ($s -replace '&(?!(amp|lt|gt|quot|#\d+);)','&amp;' -replace '<','&lt;' -replace '>','&gt;') }

# A chapter's name on its pill in the rail, with the "and ..." half of it marked
# so the stylesheet can drop that half on a phone, where the pill is half the
# width of the screen -- see .cat-tab__tail. Split at the conjunction rather
# than at a width: what is left has to still name the chapter, and
# "ჰაერსატარი" / "Ducting" does, where the first ten characters would not.
$CONJ = @(' და ', ' and ', ' & ')
function PillName([string]$name) {
  foreach ($c in $CONJ) {
    $i = $name.IndexOf($c)
    if ($i -ge 0) {
      return (Esc $name.Substring(0, $i)) +
             '<span class="cat-tab__tail">' + (Esc $name.Substring($i)) + '</span>'
    }
  }
  return (Esc $name)
}

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
    $rows.Add('        <button class="cat-tab' + $on + '" type="button" data-ch="' + $ch.icon + '">')
    if ($ch.icon) {
      # Empty alt: the chapter name is right beside it, so a description here
      # would only say the same thing twice.
      $rows.Add('          <img class="cat-tab__ico" src="' + $ICODIR + $ch.icon +
                '.svg" alt="" width="34" height="34">')
    }
    # the preview lists what is inside rather than repeating the chapter
    $prev = ''
    if ($RAIL_PREVIEW) {
      $prev = '<small>' + (Esc (($ch.items | ForEach-Object { $_.$lang }) -join ' · ')) + '</small>'
    }
    $rows.Add('          <span class="cat-tab__txt"><b>' + (PillName $ch.$lang) + '</b>' + $prev + '</span>')
    $rows.Add('        </button>')
    $first = $false
  }
  $rows.Add('      </div>')

  $rows.Add('      <div class="catalog__view">')
  $first = $true
  foreach ($ch in $TREE) {
    $on = if ($first) { ' is-on' } else { '' }
    $first = $false
    # The chapter's wash goes behind its products rather than behind the page:
    # one picture spread across the whole band turned every page it was on into
    # a dark section, where the cards are the only thing that wants a ground.
    # Written into the card itself rather than set from script, so it is there
    # with the stylesheet alone.
    $bg = PicFor ($BGDIR + $ch.icon + '.jpg')
    $bgStyle = if ($bg) { ' style="background-image:url(' + $bg + ')"' } else { '' }
    $rows.Add('      <section class="catalog__chapter' + $on + '" data-ch="' + $ch.icon + '">')
    $rows.Add('        <h3>' + (Esc $ch.$lang) + '</h3>')
    $rows.Add('        <div class="catalog__grid">')
    # A card per category: its own product, its name, an arrow. The pictures are
    # the menu-size copies -- a card is 280px wide and the full cut-out is half
    # a megabyte, which is a price worth paying for one hero and not for twelve.
    $head = $true
    foreach ($it in $ch.items) {
      $items++
      $pic = PicFor ($SMDIR + $ch.icon + '-' + (PicKey $it) + '.png')
      # A chapter's own picture is a picture of the first thing under it -- the
      # duct for ducting, the outdoor unit for cooling -- so it stands in there
      # and nowhere else, rather than repeating down the row.
      if (-not $pic -and $head) { $pic = PicFor ($SMDIR + $ch.icon + '.png') }
      $head = $false
      # Failing both, a photograph, drawn to cover the card (.catalog__pic--photo)
      $photoCls = ''
      if (-not $pic) {
        $pic = PicFor ($PHOTODIR + $ch.icon + '-' + (PicKey $it) + '.jpg')
        if ($pic) { $photoCls = ' catalog__pic--photo' }
      }
      # Only the open chapter's pictures are wanted up front. The other four
      # panels are display:none until their tab is chosen, and a lazy image
      # inside one is not fetched until it is -- which is the whole reason
      # these can be PNGs at all.
      $lazy = if ($on) { '' } else { ' loading="lazy"' }
      # Decorative: the name is on the card under it, and the heading above
      # names the chapter, so alt text would only say it a third time.
      $img = if ($pic) { '<img src="' + $pic + '" alt=""' + $lazy + '>' } else { '' }
      # A range we carry but have no listing for yet goes to the holding page,
      # and its name is grey until it has one.
      if ($it.page) {
        $href = 'products/' + $it.page + $sfx + (Query $it)
        $soon = ''
      } else {
        $href = 'soon' + $sfx
        $soon = ' catalog__card--soon'
      }
      $rows.Add('          <a class="catalog__card' + $soon + '" href="' + $href + '">')
      $rows.Add('            <span class="catalog__pic' + $photoCls + '"' + $bgStyle + '>' + $img + '</span>')
      $rows.Add('            <span class="catalog__name">' + (Esc $it.$lang) + ' ' + $ARROW + '</span>')
      $rows.Add('          </a>')
    }
    $rows.Add('        </div>')
    $rows.Add('      </section>')
  }
  $rows.Add('      </div>')

  $body = @'
<section class="page-hero page-hero--brand page-hero--tight">
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

<section class="section" style="padding-top:22px">
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
