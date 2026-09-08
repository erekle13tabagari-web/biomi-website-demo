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
  # Brand entries no longer have a landing page of their own: they point at
  # their category listing with ?brand=<slug>, which main.js reads and
  # pre-ticks. Items with no page at all fall back to the holding page.
  function Href($n) {
    if (-not $n.page) { return $A }
    $q = ''
    if ($n.brand) { $q = '?brand=' + $n.brand }
    return $P + $n.page + $sfx + $q
  }

  # ------------------------------------------------------- desktop mega-menu
  $menu = '<div class="dropdown prod-menu">' + "`r`n"
  foreach ($ch in $tree) {
    $menu += '          <div class="prod-menu__chapter">' + "`r`n"
    $menu += '            <button class="prod-menu__btn" type="button">' + $ch.$lang + "`r`n"
    $menu += '              ' + $CARET + "`r`n"
    $menu += '            </button>' + "`r`n"
    $menu += '            <div class="prod-menu__panel">' + "`r`n"
    foreach ($it in $ch.items) {
      $kids = @($it.kids)
      if ($kids.Count) {
        $menu += '              <div class="prod-sub">' + "`r`n"
        $menu += '                <div class="prod-sub__head">' + "`r`n"
        $menu += '                  <a class="prod-sub__btn" href="' + (Href $it) + '">' + $it.$lang + '</a>' + "`r`n"
        $menu += '                  <button class="prod-sub__toggle" type="button" aria-expanded="false" aria-label="' + $subAria + '">' + $CARET + '</button>' + "`r`n"
        $menu += '                </div>' + "`r`n"
        $menu += '                <div class="prod-sub__panel">' + "`r`n"
        foreach ($k in $kids) { $menu += '                  <a href="' + (Href $k) + '">' + $k.$lang + '</a>' + "`r`n" }
        $menu += '                </div>' + "`r`n"
        $menu += '              </div>' + "`r`n"
      } else {
        $menu += '              <a href="' + (Href $it) + '">' + $it.$lang + '</a>' + "`r`n"
      }
    }
    $menu += '            </div>' + "`r`n"
    $menu += '          </div>' + "`r`n"
  }
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
    [IO.File]::WriteAllText($f.FullName, $txt, (New-Object Text.UTF8Encoding($false)))
    $done++
  }
}
Write-Host ("pages rebuilt : $done")
if ($missMenu.Count)   { Write-Host ('menu not found on  : ' + ($missMenu -join ', ')) }
if ($missDrawer.Count) { Write-Host ('drawer not found on: ' + ($missDrawer -join ', ')) }
