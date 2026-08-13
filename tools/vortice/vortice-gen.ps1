# Generate the Vortice family pages, in both languages.
#
# The header, footer, floating bar and drawer are lifted from an existing
# product page rather than retyped, so the chrome cannot drift out of sync.
# Markers are located by content, never by line number -- the Georgian and
# English pages differ in length, and hardcoded offsets spliced a Samsung
# comparison table into eleven Mitsubishi pages last time.
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'vortice-families.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'vortice-pages.json')    -Raw -Encoding UTF8 | ConvertFrom-Json
$NAMES = @('main','front','angle','detail','room')
# code -> image list, only for pages whose models really do look different
$gals = Get-Content (Join-Path $sp 'vortice-galleries.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function GalFor($gal, $code) {
  if (-not $gal) { return $null }
  $p = $gal.PSObject.Properties[$code]
  if ($p) { return @($p.Value) }
  return $null
}

# ---------------------------------------------------------------- language kit
$L = @{
  ka = @{
    file='.html'; tplName='mitsubishi-msz-ap.html'
    home='მთავარი'; products='პროდუქტი'; vent='ვენტილაცია'
    lblModel='მოდელი'; specs='მახასიათებლები'; cert='სერტიფიკატები'; dl='დოკუმენტაცია'
    thModel='მოდელი'; thCode='კოდი'; thType='ტიპი'; thAir='ჰაერის ხარჯი'
    thWatt='მოხმარებული სიმძლავრე'; thDia='ნომინალური დიამეტრი'; thNoise='ხმაური'
    thPower='კვება'; thRange='მოდელების რიგი'
    cta='მოითხოვეთ შეთავაზება'; eyebrowRel='მსგავსი პროდუქტი'; headRel='Vortice-ის სხვა სერიები'
    eyebrowCmp='შედარება'; headCmp='პროდუქტების შედარება'; view='ნახვა'
    certTxt='CE · RoHS · ERP. სრული სერტიფიცირება მოთხოვნისამებრ.'
    dlTxt='ტექნიკური დოკუმენტაცია მოთხოვნისამებრ — დაგვიკავშირდით კონკრეტული მოდელისთვის.'
    uAir='მ³/სთ'; uW='ვტ'; uMm='მმ'; uDb='dBA'
    ph1='1 ფაზა, 220–240 V, 50 Hz'; phMix='1 / 3 ფაზა (მოდელის მიხედვით)'
  }
  en = @{
    file='-en.html'; tplName='mitsubishi-msz-ap-en.html'
    home='Home'; products='Products'; vent='Ventilation'
    lblModel='Model'; specs='Specifications'; cert='Certificates'; dl='Documentation'
    thModel='Model'; thCode='Code'; thType='Type'; thAir='Airflow'
    thWatt='Absorbed power'; thDia='Nominal diameter'; thNoise='Sound pressure'
    thPower='Power supply'; thRange='Model range'
    cta='Request a quote'; eyebrowRel='Related products'; headRel='Other Vortice ranges'
    eyebrowCmp='Comparison'; headCmp='Compare products'; view='View'
    certTxt='CE · RoHS · ERP. Full certification available on request.'
    dlTxt='Technical documentation on request — contact us about a specific model.'
    uAir='m³/h'; uW='W'; uMm='mm'; uDb='dBA'
    ph1='1 phase, 220–240 V, 50 Hz'; phMix='1 / 3 phase (depending on model)'
  }
}
# ranges that mix single- and three-phase models
$MIXED = @('vortice-qbk','vortice-qbk-sal','vortice-cms','vortice-roof')

function HtmlEnc($s) { $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }

# A chip label has to fit on a chip, so it drops whatever every model on the
# page shares and then stops at a word boundary near 22 characters. The full
# model name still travels on data-model and lands in the spec table.
function ChipLabel($model, $prefix) {
  $s = $model
  if ($prefix -and $s.StartsWith($prefix)) { $s = $s.Substring($prefix.Length).Trim() }
  if (-not $s) { $s = $model }
  if ($s.Length -le 22) { return $s }
  $out = ''
  foreach ($w in $s.Split(' ')) {
    if (($out + ' ' + $w).Trim().Length -gt 22) { break }
    $out = ($out + ' ' + $w).Trim()
  }
  if (-not $out) { $out = $s.Substring(0,22) }
  return $out
}

function CommonPrefix($names) {
  $split = @($names | ForEach-Object { ,$_.Split(' ') })
  $pref = @()
  for ($i = 0; $i -lt $split[0].Count; $i++) {
    $w = $split[0][$i]
    $all = $true
    foreach ($s in $split) { if ($i -ge $s.Count -or $s[$i] -ne $w) { $all = $false; break } }
    if (-not $all) { break }
    $pref += $w
  }
  # never swallow the whole name of any model -- a chip needs something left to
  # show. Note $a[0..($a.Count-2)] reverses a one-element array, so drop the
  # last word by rebuilding rather than by slicing.
  while ($pref.Count -gt 0) {
    $p = ($pref -join ' ')
    $bad = $false
    foreach ($n in $names) { if ($n.Trim() -eq $p) { $bad = $true } }
    if (-not $bad) { return $p }
    if ($pref.Count -eq 1) { break }
    $pref = @($pref[0..($pref.Count-2)])
  }
  return ''
}

# ------------------------------------------------------------------ generation
$made = @()
foreach ($lang in 'ka','en') {
  $t = $L[$lang]
  $tpl = Get-Content (Join-Path $repo ('products\' + $t.tplName)) -Raw -Encoding UTF8
  $iHead = $tpl.IndexOf('<!-- ===================== PRODUCT DETAIL')
  $iFoot = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($iHead -lt 0 -or $iFoot -lt 0) { throw "markers not found in $($t.tplName)" }
  $head = $tpl.Substring(0, $iHead)
  $tail = $tpl.Substring($iFoot)
  # The template's head carries its own canonical, og: tags and Product schema.
  # Copying those would give every generated page the template product's title,
  # image and structured data. tools/build-meta.ps1 owns that block and rewrites
  # it per page, so drop it here and let run-all.ps1 put it back.
  $head = [regex]::Replace($head, '(?s)[ \t]*<!-- meta:start.*?<!-- meta:end -->\r?\n', '')

  for ($fi = 0; $fi -lt $fams.Count; $fi++) {
    $f    = $fams[$fi]
    $name = if ($lang -eq 'ka') { $f.nameKa } else { $f.nameEn }
    $tag  = if ($lang -eq 'ka') { $f.tagKa }  else { $f.tagEn }
    $type = if ($lang -eq 'ka') { $f.typeKa } else { $f.typeEn }
    $desc = if ($lang -eq 'ka') { $f.descKa } else { $f.descEn }
    # The breadcrumb wants the range name, not the whole descriptive title:
    # "M / ME bathroom fan" -> "M / ME". Range names are upper-case codes and
    # separators, so take the leading run of those and stop at the first
    # ordinary word -- which works for the Georgian titles too.
    $shortWords = @()
    foreach ($w in ($name -split ' ')) {
      if ($w -cnotmatch '^[A-Z0-9/\-\.]+$') { break }   # -cnotmatch: -notmatch ignores case
      $shortWords += $w
    }
    $short = if ($shortWords.Count) { $shortWords -join ' ' } else { ($name -split ' ')[0] }

    $g = @($mods | Where-Object { $_.slug -eq $f.slug } | Sort-Object { [double]$_.airflow })
    $prefix = CommonPrefix (@($g | ForEach-Object { $_.model }))

    # ---- gallery
    # On a switching page the opening gallery is the first chip's set, so the
    # page loads showing the model its spec table describes.
    $imgdir = Join-Path $repo ('assets\img\products\' + $f.slug)
    $gal = $gals.PSObject.Properties[$f.slug]
    $gal = if ($gal) { $gal.Value } else { $null }
    # @() at the call site too: a one-element array unrolls to a scalar on
    # return, and then $have[0] indexes the string, not the list
    $have = @(GalFor $gal $g[0].code)
    if (-not $have -or -not $have[0]) {
      $have = @($NAMES | Where-Object { Test-Path (Join-Path $imgdir ($_ + '.avif')) } | ForEach-Object { $_ + '.avif' })
    }
    $thumbs = ($have | ForEach-Object {
      '          <img src="../assets/img/products/' + $f.slug + '/' + $_ + '" alt="' + (HtmlEnc $name) + '">'
    }) -join "`r`n"

    # ---- chips
    # A truncated label that is no longer unique tells the reader nothing --
    # pink, white and black gold all came out as "ME 100/4" LL ORO". Where the
    # short form collides, spell the model out in full and let the chip wrap.
    $labels = @{}
    foreach ($m in $g) { $labels[$m.code] = ChipLabel $m.model $prefix }
    $dupe = @($labels.Values | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    if ($dupe.Count) {
      foreach ($m in $g) { if ($dupe -contains $labels[$m.code]) { $labels[$m.code] = $m.model } }
    }
    # Some models collide even at full length: the price list lists two
    # different products as "CA 100 V0 D" (200 and 235 m3/h). The Vortice code
    # is the only thing that separates them, so it goes on the chip.
    $dupe = @($labels.Values | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    if ($dupe.Count) {
      foreach ($m in $g) { if ($dupe -contains $labels[$m.code]) { $labels[$m.code] = $m.model + ' · ' + $m.code } }
    }
    $chips = @()
    for ($i = 0; $i -lt $g.Count; $i++) {
      $m = $g[$i]
      $cls = if ($i -eq 0) { 'chip active' } else { 'chip' }
      $dia = if ($m.diameter) { $m.diameter + ' ' + $t.uMm } else { '—' }
      $db  = if ($m.db)       { $m.db + ' ' + $t.uDb }       else { '—' }
      $imgAttr = ''
      $lst = GalFor $gal $m.code
      if ($lst) { $imgAttr = '" data-alt="' + (HtmlEnc $m.model) + '" data-imgs="' + ($lst -join ',') }
      $chips += '          <button class="' + $cls + '" type="button" data-model="' + (HtmlEnc $m.model) +
                '" data-code="' + $m.code + '" data-air="' + $m.airflow + ' ' + $t.uAir +
                '" data-watt="' + $m.watts + ' ' + $t.uW + '" data-dia="' + $dia +
                '" data-db="' + $db + $imgAttr + '">' + (HtmlEnc $labels[$m.code]) + '</button>'
    }
    $first = $g[0]
    $fDia = if ($first.diameter) { $first.diameter + ' ' + $t.uMm } else { '—' }
    $fDb  = if ($first.db)       { $first.db + ' ' + $t.uDb }       else { '—' }
    $lo = [double]($g[0].airflow); $hi = [double]($g[-1].airflow)
    $range = if ($g.Count -gt 1) { "$lo–$hi $($t.uAir)" } else { "$lo $($t.uAir)" }
    $power = if ($MIXED -contains $f.slug) { $t.phMix } else { $t.ph1 }

    # ---- siblings for the related + comparison blocks
    $sib = @()
    for ($k = 1; $k -le 2; $k++) { $sib += $fams[($fi + $k) % $fams.Count] }
    $relCards = ($sib | ForEach-Object {
      $sn = if ($lang -eq 'ka') { $_.nameKa } else { $_.nameEn }
      '      <a class="pcard" href="' + $_.slug + $t.file + '"><span class="pcard__img"><img src="../assets/img/products/' +
      $_.slug + '/main.avif" alt="' + (HtmlEnc $sn) + '"></span><span class="pcard__body"><h4>' + (HtmlEnc $sn) + '</h4></span></a>'
    }) -join "`r`n"

    $cmpCols = @($f) + $sib
    $cmpHead = ($cmpCols | ForEach-Object {
      $sn = if ($lang -eq 'ka') { $_.nameKa } else { $_.nameEn }
      '<th><img src="../assets/img/products/' + $_.slug + '/main.avif" alt="">' + (HtmlEnc $sn) + '</th>'
    }) -join ''
    function CmpCell($fam, $key, $isThis) {
      $gg = @($mods | Where-Object { $_.slug -eq $fam.slug } | Sort-Object { [double]$_.airflow })
      $v = switch ($key) {
        'model' { $gg[0].model }
        'type'  { if ($lang -eq 'ka') { $fam.typeKa } else { $fam.typeEn } }
        'air'   { '' + [double]$gg[0].airflow + '–' + [double]$gg[-1].airflow + ' ' + $t.uAir }
        'db'    { $q = @($gg | Where-Object { $_.db }); if ($q.Count) { '' + [double]$q[0].db + '–' + [double]$q[-1].db + ' ' + $t.uDb } else { '—' } }
      }
      $c = if ($isThis) { ' class="is-this"' } else { '' }
      return '<td' + $c + '>' + (HtmlEnc $v) + '</td>'
    }
    $cmpRows = ''
    foreach ($k in @(@('model',$t.thModel), @('type',$t.thType), @('air',$t.thAir), @('db',$t.thNoise))) {
      $cells = ''
      for ($ci = 0; $ci -lt $cmpCols.Count; $ci++) { $cells += (CmpCell $cmpCols[$ci] $k[0] ($ci -eq 0)) }
      $cmpRows += '          <tr><th>' + $k[1] + '</th>' + $cells + "</tr>`r`n"
    }
    $cmpLinks = ($cmpCols | ForEach-Object { '<td><a class="link-more" href="' + $_.slug + $t.file + '">' + $t.view + '</a></td>' }) -join ''
    $cmpRows += '          <tr><th></th>' + $cmpLinks + '</tr>'

    # ---- assemble
    $body = @"
<!-- ===================== PRODUCT DETAIL ===================== -->
<section class="page-hero">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../index.html#products">$($t.products)</a><span class="sep">/</span>
      <a href="ventilation$($t.file)">$($t.vent)</a><span class="sep">/</span>
      <a href="vortice$($t.file)">Vortice</a><span class="sep">/</span>
      <b>$(HtmlEnc $short)</b>
    </nav>
    <div class="pdetail">
      <div class="pgal reveal">
        <div class="pgal__main">
          <button class="pgal__arrow pgal__prev" type="button" aria-label="$(if($lang -eq 'ka'){'წინა'}else{'Previous'})"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m15 6-6 6 6 6"/></svg></button>
          <img src="../assets/img/products/$($f.slug)/$($have[0])" alt="$(HtmlEnc $name)">
          <button class="pgal__arrow pgal__next" type="button" aria-label="$(if($lang -eq 'ka'){'შემდეგი'}else{'Next'})"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 6 6 6-6 6"/></svg></button>
        </div>
        <div class="pgal__thumbs">
$thumbs
        </div>
      </div>
      <div class="pbuy reveal">
        <h1>$(HtmlEnc $name)</h1>
        <div class="pbuy__tag">$(HtmlEnc $tag)</div>
        <div class="pbuy__label">$($t.lblModel)</div>
        <div class="chipset" data-modelswitch$(if ($gal) { ' data-imgbase="../assets/img/products/' + $f.slug + '/"' })>
$($chips -join "`r`n")
        </div>
        <p class="pbuy__desc">$(HtmlEnc $desc)</p>
        <a class="btn btn--gold" href="../index.html#contact">$($t.cta)
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a>
      </div>
    </div>
  </div>
</section>

<section class="section" style="padding-top:24px">
  <div class="container">
    <div class="ptabs reveal">
      <div class="ptabs__nav">
        <button class="active" type="button" data-tab="specs">$($t.specs)</button>
        <button type="button" data-tab="cert">$($t.cert)</button>
        <button type="button" data-tab="dl">$($t.dl)</button>
      </div>
      <div class="ptabs__panel active" data-panel="specs">
        <table class="spec-table" style="max-width:640px">
          <tr><th>$($t.thModel)</th><td data-spec="model">$(HtmlEnc $first.model)</td></tr>
          <tr><th>$($t.thCode)</th><td data-spec="code">$($first.code)</td></tr>
          <tr><th>$($t.thType)</th><td>$(HtmlEnc $type)</td></tr>
          <tr><th>$($t.thAir)</th><td data-spec="air">$($first.airflow) $($t.uAir)</td></tr>
          <tr><th>$($t.thWatt)</th><td data-spec="watt">$($first.watts) $($t.uW)</td></tr>
          <tr><th>$($t.thDia)</th><td data-spec="dia">$fDia</td></tr>
          <tr><th>$($t.thNoise)</th><td data-spec="db">$fDb</td></tr>
          <tr><th>$($t.thPower)</th><td>$power</td></tr>
          <tr><th>$($t.thRange)</th><td>$range</td></tr>
        </table>
      </div>
      <div class="ptabs__panel" data-panel="cert"><p style="color:var(--muted)">$($t.certTxt)</p></div>
      <div class="ptabs__panel" data-panel="dl"><p style="color:var(--muted)">$($t.dlTxt)</p></div>
    </div>
  </div>
</section>

<section class="section section--soft">
  <div class="container">
    <div class="section__head reveal"><span class="eyebrow">$($t.eyebrowRel)</span><h2>$($t.headRel)</h2></div>
    <div class="pcard-grid reveal">
$relCards
    </div>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="section__head reveal"><span class="eyebrow">$($t.eyebrowCmp)</span><h2>$($t.headCmp)</h2></div>
    <div class="compare reveal">
      <table>
        <thead><tr><th></th>$cmpHead</tr></thead>
        <tbody>
$cmpRows
        </tbody>
      </table>
    </div>
  </div>
</section>

"@

    # ---- head/tail: point every self-reference at this page, then retitle
    $h = $head; $tl = $tail
    foreach ($s in 'mitsubishi-msz-ap-en.html','mitsubishi-msz-ap.html') {
      $to = if ($s -like '*-en.html') { $f.slug + '-en.html' } else { $f.slug + '.html' }
      $h  = $h.Replace($s, $to); $tl = $tl.Replace($s, $to)
    }
    $h = [regex]::Replace($h, '(?s)<title>.*?</title>', ('<title>' + (HtmlEnc $name) + ' — ' + $(if ($lang -eq 'ka') { 'ბიომი' } else { 'Biomi' }) + '</title>'))
    $h = [regex]::Replace($h, '(?s)(<meta name="description" content=").*?(">)', ('${1}' + (HtmlEnc $desc) + '${2}'))
    $out = Join-Path $repo ('products\' + $f.slug + $t.file)
    [IO.File]::WriteAllText($out, ($h + $body + $tl), (New-Object Text.UTF8Encoding($false)))
    $made += ($f.slug + $t.file)
  }
}
Write-Host ("pages written: " + $made.Count)
$made | ForEach-Object { Write-Host ('   ' + $_) }
