# Turn the category pages into real product listings.
#
# vrf-vrv and ventilation were brand pickers: a heading and one logo tile each,
# costing a click and a page load to reach anything. They now list every
# product in the category from all of its brands at once, with brand as the
# first filter. The per-brand hubs stay, reachable from the menu.
#
# Cards are lifted from the brand hubs rather than restated, so the two views
# can never disagree about what exists. Add a product to a hub and it appears
# here on the next run.
$repo = Split-Path $PSScriptRoot -Parent
$prod = Join-Path $repo 'products'

$PAGES = @(
  @{ out='vrf-vrv'; from=@(
       @{ hub='samsung';             brand='samsung';    ka='Samsung';             en='Samsung' },
       @{ hub='mitsubishi-electric'; brand='mitsubishi'; ka='Mitsubishi Electric'; en='Mitsubishi Electric' })
     eyebrowKa='გაგრილება'; eyebrowEn='Cooling'
     headKa='Multisplit / VRV / VRF'; headEn='Multisplit / VRV / VRF'
     crumbKa='გაგრილება'; crumbEn='Cooling'
     series=@(@('dvm','DVM','DVM'),@('cac','CAC','CAC'),@('fjm','FJM','FJM'),
              @('m-series','M Series','M Series'),@('mr-slim','Mr Slim','Mr Slim'),@('citymulti','City Multi','City Multi'))
     seriesKa='სერია'; seriesEn='Series'
     typeKa='ტიპი'; typeEn='Type'
     types=@(@('wall','კედლის','Wall'),@('cassette','კასეტური','Cassette'),@('duct','არხული','Duct'),
             @('ceiling','ჭერის','Ceiling'),@('outdoor','გარე ბლოკი','Outdoor unit'))
     extraKa='მაცივარაგენტი'; extraEn='Refrigerant'; extraName='ref'
     extras=@(@('r32','R32','R32'),@('r410a','R410A','R410A')) },

  @{ out='ventilation'; from=@(
       @{ hub='vortice'; brand='vortice'; ka='Vortice'; en='Vortice' })
     eyebrowKa='ვენტილაცია'; eyebrowEn='Ventilation'
     headKa='სავენტილაციო სისტემები'; headEn='Ventilation systems'
     crumbKa='ვენტილაცია'; crumbEn='Ventilation'
     series=@(@('home','საყოფაცხოვრებო','Residential'),@('duct','არხული','In-line'),
              @('ind','სამრეწველო','Commercial'),@('hrv','რეკუპერაცია','Heat recovery'))
     seriesKa='კატეგორია'; seriesEn='Category'
     typeKa='ტიპი'; typeEn='Type'
     types=@(@('wall','კედლის','Wall'),@('ceiling','ჭერის','Ceiling'),@('duct','არხული','In-duct'),
             @('window','ფანჯრის','Window'),@('roof','სახურავის','Roof'),@('centrifugal','ცენტრიდანული','Centrifugal'))
     extraKa='ჰაერის ხარჯი'; extraEn='Airflow'; extraName='air'
     extras=@(@('low','500 მ³/სთ-მდე','Up to 500 m³/h'),@('mid','500–2000 მ³/სთ','500–2000 m³/h'),
              @('high','2000 მ³/სთ-ზე მეტი','Over 2000 m³/h')) }
)
$L = @{
  ka = @{ sfx='.html'; home='მთავარი'; products='პროდუქტი'; search='ძებნა...'
          filter='ფილტრი'; clear='გასუფთავება'; brand='ბრენდი'; empty='პროდუქტი ვერ მოიძებნა.' }
  en = @{ sfx='-en.html'; home='Home'; products='Products'; search='Search...'
          filter='Filter'; clear='Clear'; brand='Brand'; empty='No products found.' }
}
$CARET = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg>'

function FilterGroup($label, $name, $opts, $li) {
  $s = "        <div class=`"pfilter__group`">`r`n          <h4>$label $CARET</h4>`r`n          <div class=`"pfilter__opts`">`r`n"
  foreach ($o in $opts) {
    $txt = if ($li -eq 'ka') { $o[1] } else { $o[2] }
    $s += "            <label><input type=`"checkbox`" name=`"$name`" value=`"$($o[0])`">$txt</label>`r`n"
  }
  return $s + "          </div>`r`n        </div>`r`n"
}

foreach ($p in $PAGES) {
  foreach ($lang in 'ka','en') {
    $t = $L[$lang]; $sfx = $t.sfx
    $file = Join-Path $prod ($p.out + $sfx)
    if (-not (Test-Path $file)) { Write-Host "  missing $file"; continue }

    # ---- lift the cards out of each brand hub, tagging them with their brand
    $cards = ''
    $brandOpts = @()
    foreach ($src in $p.from) {
      $hubFile = Join-Path $prod ($src.hub + $sfx)
      if (-not (Test-Path $hubFile)) { Write-Host "  missing hub $hubFile"; continue }
      $hub = [IO.File]::ReadAllText($hubFile)
      $n = 0
      foreach ($m in [regex]::Matches($hub, '(?s)<a class="pcard" href="[^"]*".*?</a>')) {
        $card = $m.Value -replace '\s+$',''
        if ($card -notmatch 'data-brand=') {
          $card = $card -replace '(<a class="pcard" href="[^"]*")', ('$1 data-brand="' + $src.brand + '"')
        }
        $cards += (($card -split "`r?`n" | ForEach-Object { '        ' + $_.TrimStart() }) -join "`r`n") + "`r`n"
        $n++
      }
      $brandOpts += ,@($src.brand, $src.ka, $src.en)
      Write-Host ("  {0,-18} <- {1,2} cards from {2}" -f ($p.out + $sfx), $n, ($src.hub + $sfx))
    }

    $head = if ($lang -eq 'ka') { $p.headKa } else { $p.headEn }
    $eyebrow = if ($lang -eq 'ka') { $p.eyebrowKa } else { $p.eyebrowEn }
    $crumb = if ($lang -eq 'ka') { $p.crumbKa } else { $p.crumbEn }
    $seriesLbl = if ($lang -eq 'ka') { $p.seriesKa } else { $p.seriesEn }
    $typeLbl = if ($lang -eq 'ka') { $p.typeKa } else { $p.typeEn }
    $extraLbl = if ($lang -eq 'ka') { $p.extraKa } else { $p.extraEn }

    $body = @"
<!-- ===================== CATEGORY LISTING ===================== -->
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../index.html#products">$($t.products)</a><span class="sep">/</span>
      <b>$crumb</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">$eyebrow</span>
      <h2>$head</h2>
    </div>
  </div>
</section>

<section class="section" style="padding-top:26px">
  <div class="container" data-plist>
    <div class="plist">
      <aside class="pfilter">
        <div class="pfilter__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
          <input type="search" placeholder="$($t.search)">
        </div>
        <div class="pfilter__head"><span>$($t.filter)</span><a data-clear>$($t.clear)</a></div>
$(FilterGroup $t.brand 'brand' $brandOpts $lang)$(FilterGroup $seriesLbl 'cat' $p.series $lang)$(FilterGroup $typeLbl 'type' $p.types $lang)$(FilterGroup $extraLbl $p.extraName $p.extras $lang)      </aside>

      <div class="pgrid">
$cards        <div class="pgrid__empty" style="display:none">$($t.empty)</div>
      </div>
    </div>
  </div>
</section>

"@
    $txt = [IO.File]::ReadAllText($file)
    $i = $txt.IndexOf('<!-- ===================== BRAND PICKER')
    if ($i -lt 0) { $i = $txt.IndexOf('<!-- ===================== CATEGORY LISTING') }
    $j = $txt.IndexOf('<!-- ===================== FOOTER')
    if ($i -lt 0 -or $j -lt 0) { Write-Host "  markers not found in $file"; continue }
    $txt = $txt.Substring(0, $i) + $body + $txt.Substring($j)
    [IO.File]::WriteAllText($file, $txt, (New-Object Text.UTF8Encoding($false)))
  }
}
Write-Host 'category listings rebuilt'
