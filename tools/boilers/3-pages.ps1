# Generate the boiler series pages, both languages.
#
# Chrome is spliced from an existing product page so the header, footer, drawer
# and floating bar cannot drift; markers are found by content, never by line
# number. Same approach as tools/vortice/vortice-gen.ps1.
#
# The spec table carries identity and output only. There is no spec sheet for
# boilers and the manufacturer range pages publish features, not figures, so
# efficiency, DHW flow and heat input are deliberately absent rather than
# guessed. See README.md.
. (Join-Path $PSScriptRoot 'config.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'families.json')       -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'boilers-pages.json')  -Raw -Encoding UTF8 | ConvertFrom-Json
# Only the published outputs get a page -- see visible.ps1 for the threshold.
# A family whose models all fall below it ends up with an empty group and is
# skipped by the existing count guard, so no page is written for it.
. (Join-Path $sp 'visible.ps1')
$mods = @($mods | Where-Object { (BoilerKw $_.name) -ge $BOILER_KWMIN })
# The families list has to be narrowed as well, not just the models. The "you
# might also like" pair at the foot of each page is picked by walking $fams by
# index, so a held-back family left in here gets linked from a published page
# to a page that was never written -- which is exactly what linkcheck caught.
$fams = @($fams | Where-Object {
  $s = $_.slug                                    # capture before $_ is rebound
  @($mods | Where-Object { $_.slug -eq $s }).Count -gt 0
})
$NAMES = @('main','front','angle','detail','room')
# model -> its own images, where the range has visually distinct units
$gals = Get-Content (Join-Path $sp 'boilers-galleries.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$L = @{
  ka = @{ file='.html'; tpl='vortice-lineo.html'
    home='მთავარი'; products='პროდუქტი'; cat='ქვაბი'
    lblModel='მოდელი'; specs='მახასიათებლები'; cert='სერტიფიკატები'; dl='დოკუმენტაცია'
    thModel='მოდელი'; thCode='კოდი'; thMfr='მწარმოებლის კოდი'; thBrand='ბრენდი'
    thKw='სიმძლავრე'; thCountry='წარმოშობა'; thRange='მოდელების რიგი'
    thHeat='თბური სიმძლავრე'; thDhw='ცხელი წყალი'; thEff='მარგი ქმედება'; thMod='მოდულაცია'; thNox='NOx კლასი'; dhwUnit='ლ/წთ'
    cta='მოითხოვეთ შეთავაზება'; eyebrowRel='მსგავსი პროდუქტი'; headRel='სხვა სერიები'
    certTxt='CE. სრული სერტიფიცირება მოთხოვნისამებრ.'
    dlTxt='ტექნიკური დოკუმენტაცია მოთხოვნისამებრ - დაგვიკავშირდით კონკრეტული მოდელისთვის.'
    kw='kW'; prev='წინა'; next='შემდეგი' }
  en = @{ file='-en.html'; tpl='vortice-lineo-en.html'
    home='Home'; products='Products'; cat='Boilers'
    lblModel='Model'; specs='Specifications'; cert='Certificates'; dl='Documentation'
    thModel='Model'; thCode='Code'; thMfr='Manufacturer code'; thBrand='Brand'
    thKw='Output'; thCountry='Origin'; thRange='Model range'
    thHeat='Heat output'; thDhw='Hot water'; thEff='Efficiency'; thMod='Modulation'; thNox='NOx class'; dhwUnit='L/min'
    cta='Request a quote'; eyebrowRel='Related products'; headRel='Other ranges'
    certTxt='CE. Full certification available on request.'
    dlTxt='Technical documentation on request - contact us about a specific model.'
    kw='kW'; prev='Previous'; next='Next' }
}
# Origin drives the flag in the panel corner. Only countries actually present in
# the workbook are listed: a missing entry renders no flag rather than a guess.
$COUNTRY = @{
  'იტალია'  = @{ ka='იტალია';  en='Italy';  flag='it'; madeKa='წარმოებულია იტალიაში'; madeEn='Made in Italy'  }
  'თურქეთი' = @{ ka='თურქეთი'; en='Turkey'; flag='tr'; madeKa='წარმოებულია თურქეთში'; madeEn='Made in Turkey' }
}

# Manufacturer figures, keyed by the chip label. Only Warmhaus publishes any --
# see the _source note inside specs.json for the exact pages and for why
# dimensions and weight are absent. A model with no entry simply renders no
# extra rows, which is why Beretta and Riello pages are unchanged.
$SPECS = @{}
$raw = Get-Content (Join-Path $sp 'specs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($pr in $raw.PSObject.Properties) {
  if ($pr.Name -eq '_source') { continue }
  $SPECS[$pr.Name] = $pr.Value
}
$SPECKEYS = @('heat','dhw','eff','mod','nox')
function SpecAttrs($name, $t) {
  $out = ''
  foreach ($k in $SPECKEYS) {
    $v = SpecOf $name $k
    if ($v) {
      if ($k -eq 'dhw') { $v = "$v $($t.dhwUnit)" }
      $out += '" data-' + $k + '="' + (HtmlEnc $v)
    }
  }
  return $out
}
function SpecOf($name, $key) {
  $e = $SPECS[$name]
  if (-not $e) { return '' }
  $v = $e.$key
  if (-not $v) { return '' }
  return $v
}

function HtmlEnc($s){ if($null -eq $s){return ''}; $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }
# the output is the number in the model name: CITY 24 -> 24, VIWA S 150 -> 150
function Kw($name){ $m=[regex]::Match($name,'\b(\d{2,3})\b'); if($m.Success){return $m.Groups[1].Value}; return '' }
# strip the Georgian boilerplate and the brand off the end for a chip label
function Chip($name){
  ($name -replace '\s*გათბობის ქვაბი.*$','' -replace '^\d{6,}\s+','' -replace 'CALDAIA\s+','').Trim()
}

$made = @()
foreach ($lang in 'ka','en') {
  $t = $L[$lang]
  $tpl = Get-Content (Join-Path $repo ('products\' + $t.tpl)) -Raw -Encoding UTF8
  $iH = $tpl.IndexOf('<!-- ===================== PRODUCT DETAIL')
  $iF = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($iH -lt 0 -or $iF -lt 0) { throw "markers not found in $($t.tpl)" }
  $head = $tpl.Substring(0,$iH); $tail = $tpl.Substring($iF)
  $head = [regex]::Replace($head,'(?s)[ \t]*<!-- meta:start.*?<!-- meta:end -->\r?\n','')

  for ($fi=0; $fi -lt $fams.Count; $fi++) {
    $f = $fams[$fi]
    $name = if ($lang -eq 'ka') { $f.nameKa } else { $f.nameEn }
    $desc = if ($lang -eq 'ka') { $f.descKa } else { $f.descEn }
    $g = @($mods | Where-Object { $_.slug -eq $f.slug } | Sort-Object { [int]("0" + (Kw $_.name)) })
    # "LAWA 18 BLACK" is the same boiler in a black body. It comes out of the
    # chip list and becomes a finish switch below, so the range is not padded
    # with a second entry for a colour.
    $blackImgs = @(Get-ChildItem (Join-Path $repo ('assets\img\products\' + $f.slug)) -Filter 'black-*.avif' -EA SilentlyContinue | Sort-Object Name | ForEach-Object { $_.Name })
    if ($blackImgs.Count) { $g = @($g | Where-Object { $_.name -notmatch '\bBLACK\b' }) }
    if (-not $g.Count) { continue }

    $pg = $gals.PSObject.Properties[$f.slug]
    $pageGal = if ($pg) { $pg.Value } else { $null }
    function GalOf($n) { if (-not $pageGal) { return $null }; $q = $pageGal.PSObject.Properties[$n]; if ($q) { return @($q.Value) }; return $null }
    $imgdir = Join-Path $repo ('assets\img\products\' + $f.slug)
    $have = @(GalOf $g[0].name)
    if (-not $have -or -not $have[0]) {
      $have = @($NAMES | Where-Object { Test-Path (Join-Path $imgdir ($_ + '.avif')) } | ForEach-Object { $_ + '.avif' })
    }
    $thumbs = ($have | ForEach-Object {
      '          <img src="../assets/img/products/' + $f.slug + '/' + $_ + '" alt="' + (HtmlEnc $name) + '">' }) -join "`r`n"

    $chips = @()
    for ($i=0; $i -lt $g.Count; $i++) {
      $m = $g[$i]
      $cls = if ($i -eq 0) { 'chip active' } else { 'chip' }
      $kw = Kw $m.name; $kwTxt = if ($kw) { "$kw $($t.kw)" } else { '-' }
      $ctry = if ($m.country -and $COUNTRY[$m.country]) { $COUNTRY[$m.country][$lang] } else { '-' }
      $mg = @(GalOf $m.name)
      $imgAttr = if ($mg -and $mg[0]) { '" data-alt="' + (HtmlEnc (Chip $m.name)) + '" data-imgs="' + ($mg -join ',') } else { '' }
      $chips += '          <button class="' + $cls + '" type="button" data-model="' + (HtmlEnc (Chip $m.name)) +
                '" data-code="' + (HtmlEnc $(if($m.code){$m.code}else{'-'})) +
                '" data-mfr="' + (HtmlEnc $(if($m.mfr){$m.mfr}else{'-'})) +
                '" data-kw="' + $kwTxt + '" data-country="' + (HtmlEnc $ctry) + (SpecAttrs (Chip $m.name) $t) + $imgAttr + '">' +
                (HtmlEnc (Chip $m.name)) + '</button>'
    }
    $first = $g[0]
    $fKw = Kw $first.name; $fKwTxt = if ($fKw) { "$fKw $($t.kw)" } else { '-' }
    $fCtry = if ($first.country -and $COUNTRY[$first.country]) { $COUNTRY[$first.country][$lang] } else { '-' }
    # the flag only appears when the origin is one we have a file for
    $flagTag = ''
    $co = $null
    if ($first.country) { $co = $COUNTRY[$first.country] }
    if ($co -and $co.flag) {
      $madeIn = if ($lang -eq 'ka') { $co.madeKa } else { $co.madeEn }
      $flagTag = '          <div class="pbuy__origin" title="' + (HtmlEnc $madeIn) + '">' +
                 '<img src="../assets/img/flags/' + $co.flag + '.webp" alt="' + (HtmlEnc $madeIn) + '" loading="lazy"></div>'
    }
    # One row per published figure, and only where some model on this page has
    # it: an all-empty row reads as a hole in the datasheet rather than as an
    # absence of data. Beretta and Riello therefore keep the original table.
    $LBL = @{ heat=$t.thHeat; dhw=$t.thDhw; eff=$t.thEff; mod=$t.thMod; nox=$t.thNox }
    $specRows = ''
    foreach ($k in $SPECKEYS) {
      if (-not @($g | Where-Object { SpecOf (Chip $_.name) $k }).Count) { continue }
      $v = SpecOf (Chip $first.name) $k
      if (-not $v) { $v = '-' } elseif ($k -eq 'dhw') { $v = "$v $($t.dhwUnit)" }
      $specRows += "`r`n          <tr><th>$($LBL[$k])</th><td data-spec=`"$k`">" + (HtmlEnc $v) + '</td></tr>'
    }
    $kws = @($g | ForEach-Object { Kw $_.name } | Where-Object { $_ } | ForEach-Object { [int]$_ } | Sort-Object)
    $range = if ($kws.Count -gt 1) { "$($kws[0])-$($kws[-1]) $($t.kw)" } elseif ($kws.Count) { "$($kws[0]) $($t.kw)" } else { '-' }

    $finish = ''
    if ($blackImgs.Count) {
      $std = ($have -join ',')
      $blk = ($blackImgs -join ',')
      $lblF = if ($lang -eq 'ka') { 'ფერი' } else { 'Finish' }
      $lblW = if ($lang -eq 'ka') { 'თეთრი' } else { 'White' }
      $lblB = if ($lang -eq 'ka') { 'შავი' } else { 'Black' }
      $finish = "        <div class=`"pbuy__label`">$lblF</div>`r`n" +
                "        <div class=`"chipset`" data-imgswitch data-imgbase=`"../assets/img/products/$($f.slug)/`">`r`n" +
                "          <button class=`"chip chip--sw active`" type=`"button`" style=`"--sw:#f2f2f4`" title=`"$lblW`" aria-label=`"$lblW`" data-alt=`"$(HtmlEnc $name) - $lblW`" data-imgs=`"$std`"></button>`r`n" +
                "          <button class=`"chip chip--sw`" type=`"button`" style=`"--sw:#17171b`" title=`"$lblB`" aria-label=`"$lblB`" data-alt=`"$(HtmlEnc $name) - $lblB`" data-imgs=`"$blk`"></button>`r`n" +
                "        </div>`r`n"
    }

    $sib = @(); for ($k=1; $k -le 2; $k++) { $sib += $fams[($fi+$k) % $fams.Count] }
    $rel = ($sib | ForEach-Object {
      $sn = if ($lang -eq 'ka') { $_.nameKa } else { $_.nameEn }
      '      <a class="pcard" href="' + $_.slug + $t.file + '"><span class="pcard__img"><img src="../assets/img/products/' +
      $_.slug + '/main.avif" alt="' + (HtmlEnc $sn) + '"></span><span class="pcard__body"><h4>' + (HtmlEnc $sn) + '</h4></span></a>' }) -join "`r`n"

    $body = @"
<!-- ===================== PRODUCT DETAIL ===================== -->
<section class="page-hero">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../index.html#products">$($t.products)</a><span class="sep">/</span>
      <a href="boilers$($t.file)">$($t.cat)</a><span class="sep">/</span>
      <b>$(HtmlEnc $name)</b>
    </nav>
    <div class="pdetail">
      <div class="pgal reveal">
        <div class="pgal__main">
          <button class="pgal__arrow pgal__prev" type="button" aria-label="$($t.prev)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m15 6-6 6 6 6"/></svg></button>
          <img src="../assets/img/products/$($f.slug)/$($have[0])" alt="$(HtmlEnc $name)">
          <button class="pgal__arrow pgal__next" type="button" aria-label="$($t.next)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 6 6 6-6 6"/></svg></button>
        </div>
        <div class="pgal__thumbs">
$thumbs
        </div>
      </div>
      <div class="pbuy reveal">
        <h1>$(HtmlEnc $name)</h1>
        <div class="pbuy__ident">
          <div>
            <div class="pbuy__brand" style="--m:url('../img/partners/$($f.brand.ToLower()).svg')"><img src="../assets/img/partners/$($f.brand.ToLower()).svg" alt="$($f.brand)"></div>
            <div class="pbuy__kw">$range</div>
          </div>
$flagTag
        </div>
        <div class="pbuy__label">$($t.lblModel)</div>
        <div class="chipset" data-modelswitch$(if ($pageGal) { ' data-imgbase="../assets/img/products/' + $f.slug + '/"' })>
$($chips -join "`r`n")
        </div>
$finish        <p class="pbuy__desc">$(HtmlEnc $desc)</p>
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
          <tr><th>$($t.thModel)</th><td data-spec="model">$(HtmlEnc (Chip $first.name))</td></tr>
          <tr><th>$($t.thBrand)</th><td>$($f.brand)</td></tr>
          <tr><th>$($t.thKw)</th><td data-spec="kw">$fKwTxt</td></tr>
          <tr><th>$($t.thCode)</th><td data-spec="code">$(HtmlEnc $(if($first.code){$first.code}else{'-'}))</td></tr>
          <tr><th>$($t.thMfr)</th><td data-spec="mfr">$(HtmlEnc $(if($first.mfr){$first.mfr}else{'-'}))</td></tr>
          <tr><th>$($t.thCountry)</th><td data-spec="country">$(HtmlEnc $fCtry)</td></tr>
          <tr><th>$($t.thRange)</th><td>$range</td></tr>$specRows
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
$rel
    </div>
  </div>
</section>

"@
    $h = $head; $tl = $tail
    foreach ($s in 'vortice-lineo-en.html','vortice-lineo.html') {
      $to = if ($s -like '*-en.html') { $f.slug + '-en.html' } else { $f.slug + '.html' }
      $h = $h.Replace($s,$to); $tl = $tl.Replace($s,$to)
    }
    $h = [regex]::Replace($h,'(?s)<title>.*?</title>',('<title>' + (HtmlEnc $name) + ' - ' + $(if($lang -eq 'ka'){'ბიომი'}else{'Biomi'}) + '</title>'))
    $h = [regex]::Replace($h,'(?s)(<meta name="description" content=").*?(">)',('${1}' + (HtmlEnc $desc) + '${2}'))
    [IO.File]::WriteAllText((Join-Path $repo ('products\' + $f.slug + $t.file)), ($h + $body + $tl), (New-Object Text.UTF8Encoding($false)))
    $made += ($f.slug + $t.file)
  }
}
Write-Host ("pages written: " + $made.Count)
