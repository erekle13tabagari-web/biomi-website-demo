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
  if ($dir -eq $repo)                  { $P = 'products/';    $A = '#products' }
  elseif ($dir -eq (Join-Path $repo 'products')) { $P = '';    $A = '../index.html#products' }
  else                                 { $P = '../products/'; $A = '../index.html#products' }
  $subAria = if ($en) { 'Subcategories' } else { 'ქვეკატეგორიები' }
  function Href($page) { if ($page) { return $P + $page + $sfx } else { return $A } }

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
        $menu += '                  <a class="prod-sub__btn" href="' + (Href $it.page) + '">' + $it.$lang + '</a>' + "`r`n"
        $menu += '                  <button class="prod-sub__toggle" type="button" aria-expanded="false" aria-label="' + $subAria + '">' + $CARET + '</button>' + "`r`n"
        $menu += '                </div>' + "`r`n"
        $menu += '                <div class="prod-sub__panel">' + "`r`n"
        foreach ($k in $kids) { $menu += '                  <a href="' + (Href $k.page) + '">' + $k.$lang + '</a>' + "`r`n" }
        $menu += '                </div>' + "`r`n"
        $menu += '              </div>' + "`r`n"
      } else {
        $menu += '              <a href="' + (Href $it.page) + '">' + $it.$lang + '</a>' + "`r`n"
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
  $draw = '<div class="m-acc__panel">' + "`r`n"
  foreach ($ch in $tree) {
    $draw += '          <div class="m-acc__group">' + $ch.$lang + '</div>' + "`r`n"
    foreach ($it in $ch.items) {
      $draw += '          <a href="' + (Href $it.page) + '" data-close>' + $it.$lang + '</a>' + "`r`n"
      foreach ($k in @($it.kids)) {
        $draw += '          <a class="m-sub" href="' + (Href $k.page) + '" data-close>' + $k.$lang + '</a>' + "`r`n"
      }
    }
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
    if ($txt.Substring($a, $b - $a).Contains('m-acc__group')) {
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
