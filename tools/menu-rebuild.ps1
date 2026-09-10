# Rebuild the product menu -- desktop mega-menu and mobile drawer -- on every
# page, from the single tree in menu-tree.json.
#
# The old three-chapter menu (heating+cooling / ventilation / water) becomes
# five, matching the supplied structure. Items with no page yet keep pointing at
# the products anchor, exactly as the placeholders did before.
#
# The blocks are found by depth-counting <div>...</div> rather than by regex,
# because both contain nested divs and a lazy regex would stop at the first
# inner closing tag.
$repo = Split-Path $PSScriptRoot -Parent
$sp   = $PSScriptRoot
$tree = Get-Content (Join-Path $sp 'menu-tree.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$CARET = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg>'
# The card arrow, and the one on the "all products" link. Same mark the
# catalogue's category rows carry, so the two pages read as one list.
$ARROW = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'

# A picture's path if the file is really there, and '' if it is not: a category
# with nothing photographed yet gets a card with the chapter's wash and no
# product, rather than a broken image. Drop the picture in, run tools/cutout.ps1
# and the card fills itself in -- there is no list of them here.
function Pic([string]$rel) {
  if (Test-Path (Join-Path $repo ($rel -replace '/','\'))) { return $rel }
  return ''
}

# Return the index just past the </div> that closes the <div> starting at $i.
function DivEnd([string]$s, [int]$i) {
  $depth = 0
  $rx = [regex]'</?div\b'
  $m = $rx.Match($s, $i)
  while ($m.Success) {
    if ($m.Value -eq '<div') { $depth++ } else { $depth-- }
    if ($depth -eq 0) { return $s.IndexOf('>', $m.Index) + 1 }
    $m = $m.NextMatch()
  }
  return -1
}

$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and $_.FullName -notmatch '\\(backup|_files|\.git|\.claude)' }

$done = 0; $missMenu = @(); $missDrawer = @()
foreach ($f in $files) {
  $txt = [IO.File]::ReadAllText($f.FullName)
  if (-not $txt.Contains('dropdown prod-menu')) { continue }
  $orig = $txt
  $en  = $f.Name -like '*-en.html'
  $sfx = if ($en) { '-en.html' } else { '.html' }
  $lang = if ($en) { 'en' } else { 'ka' }
  $dir = $f.DirectoryName
  # $U is the prefix back up to the site root, for the two pages that live there.
  if ($dir -eq $repo)                  { $P = 'products/';    $U = '' }
  elseif ($dir -eq (Join-Path $repo 'products')) { $P = '';    $U = '../' }
  else                                 { $P = '../products/'; $U = '../' }
  # Where an entry with no listing goes. This was #products, an anchor on a
  # homepage section that has since been hidden, so every one of those links
  # scrolled nowhere. soon.html says the range is coming and offers the contact
  # form, which is what someone clicking "underfloor heating" actually needs.
  $A = $U + 'soon' + $sfx
  $subAria = if ($en) { 'Subcategories' } else { 'ქვეკატეგორიები' }
  $allTxt  = if ($en) { 'View all products' } else { 'ყველა პროდუქტის ნახვა' }
  # Brand entries no longer have a landing page of their own: they point at
  # their category listing with ?brand=<slug>, which main.js reads and
  # pre-ticks. Items with no page at all fall back to the holding page.
  function Href($n) {
    if (-not $n.page) { return $A }
    # A node can pin any of the listing's filters: ?cat= for a section of the
    # range, ?brand= for a make, the two together for a make within a section.
    # main.js ticks boxes by name from the query string, so a pair needs nothing
    # special there.
    $q = @()
    if ($n.cat)   { $q += 'cat='   + $n.cat }
    if ($n.brand) { $q += 'brand=' + $n.brand }
    # &amp;, not &: this only ever lands in an href attribute, and a bare
    # ampersand there is an unterminated character reference.
    $qs = if ($q.Count) { '?' + ($q -join '&amp;') } else { '' }
    return $P + $n.page + $sfx + $qs
  }

  # ------------------------------------------------------- desktop mega-menu
  #
  # A row of chapters, and under whichever one is up, a card for each of its
  # categories: the picture the catalogue shows for that category, its name and
  # an arrow. What was here before was five accordions of nested lists -- three
  # clicks from the menu to a brand, and not a picture of anything in it.
  #
  # Brands are not on this row. They are still a level down in the drawer and a
  # filter on every listing, and a card has no line to carry three of them
  # without turning back into the list this replaces.
  #
  # No tab roles written here: as on the catalogue, the tabs are only real once
  # the script has run, so main.js writes the roles and the class that shows one
  # panel at a time. With no JavaScript the five panels stand one under another
  # -- a longer menu, but every link in it still works.
  $menu = '<div class="dropdown prod-menu">' + "`r`n"
  $menu += '          <div class="prod-menu__tabs">' + "`r`n"
  $fi = $true
  foreach ($ch in $tree) {
    $on = if ($fi) { ' is-on' } else { '' }
    $fi = $false
    $menu += '            <button class="pm-tab' + $on + '" type="button" data-ch="' + $ch.icon + '">' +
             $ch.$lang + '</button>' + "`r`n"
  }
  $menu += '          </div>' + "`r`n"
  $menu += '          <div class="prod-menu__body">' + "`r`n"
  $fi = $true
  foreach ($ch in $tree) {
    $on = if ($fi) { ' is-on' } else { '' }
    $fi = $false
    $menu += '            <div class="pm-panel' + $on + '" data-ch="' + $ch.icon + '">' + "`r`n"
    # The chapter's wash behind every card, its products on top: the pair the
    # catalogue uses, at menu size. Both are held in data- attributes rather
    # than src, because a dropdown that is only hidden -- not display:none --
    # fetches everything in it on page load whether or not anyone opens it, and
    # that is two and a half megabytes of product on all 168 pages.
    $wash = Pic ('assets/img/cat-bg/' + $ch.icon + '.jpg')
    $head = $true
    foreach ($it in $ch.items) {
      $key = ''
      if ($it.cat)      { $key = [string]$it.cat }
      elseif ($it.page) { $key = [string]$it.page }
      $pic = ''
      if ($key) { $pic = Pic ('assets/img/cutouts/sm/' + $ch.icon + '-' + $key + '.png') }
      # A chapter's own picture is a picture of the first thing under it -- the
      # duct for ducting, the outdoor unit for cooling -- so it stands in there
      # and nowhere else, rather than repeating down the row.
      if (-not $pic -and $head) { $pic = Pic ('assets/img/cutouts/sm/' + $ch.icon + '.png') }
      $head = $false
      $bg  = if ($wash) { ' data-bg="' + $U + $wash + '"' } else { '' }
      $img = if ($pic)  { '<img data-src="' + $U + $pic + '" alt="">' } else { '' }
      # A range we carry but have no listing for yet goes to the holding page,
      # and its name is muted here the way the catalogue mutes its row.
      $soon = if ($it.page) { '' } else { ' pm-card--soon' }
      $menu += '              <a class="pm-card' + $soon + '" href="' + (Href $it) + '">' + "`r`n"
      $menu += '                <span class="pm-card__pic"' + $bg + '>' + $img + '</span>' + "`r`n"
      $menu += '                <span class="pm-card__name">' + $it.$lang + ' ' + $ARROW + '</span>' + "`r`n"
      $menu += '              </a>' + "`r`n"
    }
    $menu += '            </div>' + "`r`n"
  }
  $menu += '          </div>' + "`r`n"
  $menu += '          <a class="prod-menu__all" href="' + $U + 'products' + $sfx + '">' +
           $allTxt + ' ' + $ARROW + '</a>' + "`r`n"
  $menu += '        </div>'

  $i = $txt.IndexOf('<div class="dropdown prod-menu">')
  $j = DivEnd $txt $i
  if ($j -lt 0) { $missMenu += $f.Name; continue }
  $txt = $txt.Substring(0, $i) + $menu + $txt.Substring($j)

  # ----------------------------------------------------------- mobile drawer
  # Each chapter collapses here too. Flattened, the five chapters and their
  # children came to 29 links and 1548px inside a drawer 812px tall, so opening
  # Products turned the menu into one long scroll. Desktop already collapses them.
  $draw = '<div class="m-acc__panel">' + "`r`n"
  foreach ($ch in $tree) {
    $draw += '          <div class="m-sec">' + "`r`n"
    $draw += '            <button class="m-sec__btn" type="button">' + $ch.$lang + ' ' + $CARET + '</button>' + "`r`n"
    $draw += '            <div class="m-sec__panel">' + "`r`n"
    foreach ($it in $ch.items) {
      $kids = @($it.kids)
      if (-not $kids.Count) {
        # nothing to expand, so no chevron -- a disclosure control that reveals
        # nothing is worse than none
        $draw += '              <a href="' + (Href $it) + '" data-close>' + $it.$lang + '</a>' + "`r`n"
        continue
      }
      # the label stays a link to the category; the chevron beside it only opens
      # the brand list, so tapping the name and tapping the arrow do different
      # things on purpose
      $draw += '              <div class="m-itm">' + "`r`n"
      $draw += '                <div class="m-itm__head">' + "`r`n"
      $draw += '                  <a href="' + (Href $it) + '" data-close>' + $it.$lang + '</a>' + "`r`n"
      $draw += '                  <button class="m-itm__btn" type="button" aria-expanded="false" aria-label="' + $subAria + '">' + $CARET + '</button>' + "`r`n"
      $draw += '                </div>' + "`r`n"
      $draw += '                <div class="m-itm__panel">' + "`r`n"
      foreach ($k in $kids) {
        $draw += '                  <a class="m-sub" href="' + (Href $k) + '" data-close>' + $k.$lang + '</a>' + "`r`n"
      }
      $draw += '                </div>' + "`r`n"
      $draw += '              </div>' + "`r`n"
    }
    $draw += '            </div>' + "`r`n"
    $draw += '          </div>' + "`r`n"
  }
  $draw += '        </div>'

  # the About accordion also uses .m-acc__panel; the products one is the one
  # carrying group headings
  $found = $false
  $pos = 0
  while ($true) {
    $a = $txt.IndexOf('<div class="m-acc__panel">', $pos)
    if ($a -lt 0) { break }
    $b = DivEnd $txt $a
    if ($b -lt 0) { break }
    if ($txt.Substring($a, $b - $a) -match 'm-acc__group|m-sec') {
      $txt = $txt.Substring(0, $a) + $draw + $txt.Substring($b)
      $found = $true; break
    }
    $pos = $b
  }
  if (-not $found) { $missDrawer += $f.Name }

  if ($txt -ne $orig) {
    # With the BOM, which is what the pages carry. Without it this stripped the
    # BOM from all 171 of them on every run, so a one-line menu change arrived as
    # a whole-site diff and the real edit was impossible to see in review.
    [IO.File]::WriteAllText($f.FullName, $txt, (New-Object Text.UTF8Encoding($true)))
    $done++
  }
}
Write-Host ("pages rebuilt : $done")
if ($missMenu.Count)   { Write-Host ('menu not found on  : ' + ($missMenu -join ', ')) }
if ($missDrawer.Count) { Write-Host ('drawer not found on: ' + ($missDrawer -join ', ')) }
