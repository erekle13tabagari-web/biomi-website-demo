# Write the documents list into every product page, in both languages.
#
# The list lives in the "downloads" tab panel, which every product page already
# has -- pages with nothing to offer carry a "documentation on request" line.
# This replaces the contents of that panel, so it is re-runnable: adding a file
# to the library and re-running the three scripts updates the pages.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$BOM  = New-Object Text.UTF8Encoding($true)

# No @() around these: ConvertFrom-Json emits the whole JSON array as a single
# object, so @(...) wraps it into a one-element array holding the array, and
# every page then lists every document at once.
$pub  = Get-Content (Join-Path $sp 'published.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$pub += Get-Content (Join-Path $sp 'legacy.json')    -Raw -Encoding UTF8 | ConvertFrom-Json
$TITLE = Get-Content (Join-Path $sp 'titles.json')   -Raw -Encoding UTF8 | ConvertFrom-Json

$LABEL = @{
  brochure  = @{ ka = 'ბროშურა';                     en = 'Brochure' }
  datasheet = @{ ka = 'ტექნიკური მონაცემები';         en = 'Technical data sheet' }
  energy    = @{ ka = 'ენერგოეფექტურობის მონაცემები'; en = 'Energy data' }
  install   = @{ ka = 'მონტაჟის ინსტრუქცია';          en = 'Installation manual' }
  user      = @{ ka = 'მომხმარებლის ინსტრუქცია';      en = 'User manual' }
  booklet   = @{ ka = 'ინსტრუქცია';                   en = 'Instruction booklet' }
  wiring    = @{ ka = 'შეერთების სქემა';               en = 'Wiring diagram' }
  safety    = @{ ka = 'უსაფრთხოების ინსტრუქცია';      en = 'Safety instructions' }
  other     = @{ ka = 'დოკუმენტაცია';                 en = 'Documentation' }
}
# most useful to a buyer first, installer detail last
$ORDER = @{ brochure = 1; datasheet = 2; energy = 3; install = 4; user = 5
            booklet = 6; wiring = 7; safety = 8; other = 9 }
$BRAND = @{ beretta = 'Beretta'; riello = 'Riello'; warmhaus = 'Warmhaus'; omega = 'Omega'
            samsung = 'Samsung'; mitsubishi = 'Mitsubishi Electric'; vortice = 'Vortice' }

$EMPTY = @{
  ka = '<p style="color:var(--muted)">ტექნიკური დოკუმენტაცია მოთხოვნისამებრ - დაგვიკავშირდით კონკრეტული მოდელისთვის.</p>'
  en = '<p style="color:var(--muted)">Technical documentation on request - contact us about a specific model.</p>'
}
$ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3v12M8 11l4 4 4-4"/><path d="M4 21h16"/></svg>'

function Size($mb) {
  if ($null -eq $mb -or $mb -le 0) { return 'PDF' }
  if ($mb -lt 1) { return ('PDF · ' + [math]::Round($mb * 1024) + ' KB') }
  return ('PDF · ' + ('{0:N1}' -f $mb) + ' MB')
}
function BrandOf($slug) {
  foreach ($k in $BRAND.Keys) { if ($slug.StartsWith($k)) { return $BRAND[$k] } }
  return ''
}
# What names this document on the page: its model where one is known, otherwise
# a hand-written title from titles.json. Empty for the many documents that are
# the only one of their kind on their page and need no qualifier at all.
function Named($d, $lang) {
  if ($d.model) { return $d.model }
  $t = $TITLE.($d.name)
  if ($t) { return $t.$lang }
  return ''
}
# Revision year out of a Vortice filename. It has to match a date-shaped group,
# not any 19xx/20xx run: "70_EN_12000_Libretti_…" carries article code 12000,
# and a bare year search happily reads that as the year 2000.
#   …_5371084101_17_09_2004_12946   …__27-11-2017_…   …__29062009_…
function RevYear($name) {
  $m = [regex]::Matches($name, '[_ ](\d{1,2})[-_]?(\d{1,2})[-_]?((?:19|20)\d{2})[_ ]')
  if ($m.Count -eq 0) { return '' }
  return $m[$m.Count - 1].Groups[3].Value
}

# page slug -> its documents
$bySlug = @{}
foreach ($d in $pub) {
  foreach ($s in $d.slugs) {
    if (-not $bySlug.ContainsKey($s)) { $bySlug[$s] = New-Object System.Collections.ArrayList }
    [void]$bySlug[$s].Add($d)
  }
}

$written = 0; $emptied = 0; $missing = @()
foreach ($slugFile in (Get-ChildItem (Join-Path $repo 'products') -Filter '*.html' -File)) {
  $lang = if ($slugFile.Name -like '*-en.html') { 'en' } else { 'ka' }
  $slug = $slugFile.Name -replace '(-en)?\.html$', ''
  $s = [IO.File]::ReadAllText($slugFile.FullName)

  $open = $s.IndexOf('<div class="ptabs__panel" data-panel="dl">')
  if ($open -lt 0) { $missing += $slugFile.Name; continue }
  $a = $s.IndexOf('>', $open) + 1
  $b = $s.IndexOf('</div>', $a)
  # On a page that already carries a list, the first </div> closes the list, not
  # the panel -- replacing only up to it left one stray </div> behind on every
  # re-run. The list holds nothing but links, so the panel closes at the next one.
  $list = $s.IndexOf('<div class="dl-list">', $a)
  if ($b -ge 0 -and $list -ge 0 -and $list -lt $b) { $b = $s.IndexOf('</div>', $b + 6) }
  if ($b -lt 0) { $missing += $slugFile.Name; continue }

  if ($bySlug.ContainsKey($slug)) {
    $items = @($bySlug[$slug] |
      Sort-Object @{ e = { $ORDER[$_.class] } }, @{ e = { $_.model } }, @{ e = { $_.file } })

    # A page can hold several revisions of the same booklet or diagram for the
    # same model, which would otherwise render as four identical links. Where
    # the filename carries a revision date they are told apart by year;
    # otherwise they are simply numbered.
    $suffix = @{}
    foreach ($grp in ($items | Group-Object { $_.class + '|' + (Named $_ $lang) })) {
      if ($grp.Count -lt 2) { continue }
      $years = @($grp.Group | ForEach-Object { RevYear $_.name })
      $ok = ($years -notcontains '') -and (@($years | Sort-Object -Unique).Count -eq $grp.Count)
      for ($j = 0; $j -lt $grp.Count; $j++) {
        $suffix[$grp.Group[$j].file] = if ($ok) { ' (' + $years[$j] + ')' } else { ' ' + ($j + 1) }
      }
    }

    $html = '\n        <div class="dl-list">'
    foreach ($d in $items) {
      # Not $label: PowerShell variable names are case-insensitive, so a local
      # $label is the same variable as the $LABEL table and wipes it out on the
      # first iteration, leaving every later lookup null.
      $lbl = if ($d.labelKa) { if ($lang -eq 'ka') { $d.labelKa } else { $d.labelEn } }
             else            { $LABEL[$d.class][$lang] }
      if ($suffix.ContainsKey($d.file)) { $lbl += $suffix[$d.file] }
      $nm = Named $d $lang
      $head = if ($nm) { $nm + ' - ' + $lbl } else { $lbl }
      $meta = (@((BrandOf $slug), (Size $d.mb)) | Where-Object { $_ }) -join ' · '
      $html += '\n          <a href="../assets/downloads/' + $d.file + '" target="_blank" rel="noopener">' +
               $ICON + '<span>' + $head + '<small>' + $meta + '</small></span></a>'
    }
    $html += '\n        </div>\n      '
    $written++
  } else {
    $html = $EMPTY[$lang]
    $emptied++
  }
  # The product pages are not consistent: the Vortice generator wrote LF, the
  # others CRLF. Inserting one style into the other leaves a file with mixed
  # endings and a diff that touches every line the next time anything runs over
  # it, so each file keeps whichever style it already predominantly uses.
  $crlf = ([regex]::Matches($s, "`r`n")).Count
  $lf   = ([regex]::Matches($s, "`n")).Count - $crlf
  $nl   = if ($crlf -ge $lf) { "`r`n" } else { "`n" }
  $html = $html.Replace('\n', $nl)

  $s = $s.Substring(0, $a) + $html + $s.Substring($b)
  # normalise the whole file, in case an earlier run mixed them
  $s = [regex]::Replace($s, "`r`n|`n", $nl)
  [IO.File]::WriteAllText($slugFile.FullName, $s, $BOM)
}
Write-Host ("pages with a documents list : $written")
Write-Host ("pages left on 'on request'  : $emptied")
if ($missing.Count) { Write-Host ("no downloads panel found    : " + ($missing -join ', ')) }
