# Build the Vortice brand hub and the Ventilation category page, both languages.
#
# Same splice technique as the family pages: chrome comes from a page that
# already has the shape we want -- the Mitsubishi hub for the listing, the
# VRF/VRV page for the brand picker -- and only the middle is written here.
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'vortice-families.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'vortice-pages.json')    -Raw -Encoding UTF8 | ConvertFrom-Json

# Listing order: biggest first. The range runs from an 85 m3/h bathroom fan to
# an 18,152 m3/h industrial unit, and airflow is the one measure that spans all
# of it, so it sorts on each family's highest-rated model.
#
# families.json keeps its own order untouched: that file drives generation and
# model-to-page matching, where sequence is load-bearing -- LINEO QUIET has to
# be tested before LINEO or every QUIET model lands on the wrong page.
$ordered = @($fams | Sort-Object -Descending -Property @{ e = {
  $slug = $_.slug
  ($mods | Where-Object { $_.slug -eq $slug } | ForEach-Object { [double]$_.airflow } |
    Measure-Object -Maximum).Maximum
}})

# page -> listing group and filter facets
$CAT = @{
  'vortice-me'=@{g='home';t='wall'};         'vortice-mf'=@{g='home';t='wall,ceiling'}
  'vortice-mfo'=@{g='home';t='wall,ceiling'};'vortice-mg'=@{g='home';t='duct'}
  'vortice-qe'=@{g='home';t='wall'};         'vortice-ariett'=@{g='home';t='wall'}
  'vortice-ar-p'=@{g='home';t='window'}
  'vortice-ca-v0'=@{g='duct';t='duct'};      'vortice-ca-md'=@{g='duct';t='duct'}
  'vortice-ca-il'=@{g='duct';t='duct'};      'vortice-lineo'=@{g='duct';t='duct'}
  # LINEO QUIET was missing here, so it carried no category and no type and fell
  # out of every filter -- visible only with nothing ticked. It is the acoustically
  # jacketed LINEO, named "LINEO QUIET duct fan" in vortice-families.json, so it
  # takes the same pair as the LINEO beside it.
  'vortice-lineo-quiet'=@{g='duct';t='duct'}
  # The ranges split out of CA IL, LINEO, LINEO QUIET and VORT HR / HRI take
  # the pair of the page they left; the HR 300 is a wall or floor unit.
  'vortice-ca-rm-es'=@{g='duct';t='duct'};   'vortice-lineo-q'=@{g='duct';t='duct'}
  'vortice-lineo-quiet-es'=@{g='duct';t='duct'}; 'vortice-lineo-t-quiet'=@{g='duct';t='duct'}
  'vortice-hr-neti'=@{g='hrv';t='wall'}
  'vortice-qbk'=@{g='ind';t='centrifugal'};  'vortice-qbk-sal'=@{g='ind';t='centrifugal'}
  'vortice-cms'=@{g='ind';t='centrifugal'};  'vortice-roof'=@{g='ind';t='roof'}
  'vortice-hri'=@{g='hrv';t='ceiling'}
}
$L = @{
  ka = @{ file='.html'; hubTpl='mitsubishi-electric.html'; catTpl='vrf-vrv.html'
    home='მთავარი'; products='პროდუქტი'; vent='ვენტილაცია'
    tabAll='ყველა'; tabHome='საყოფაცხოვრებო'; tabDuct='არხული'; tabInd='სამრეწველო'; tabHrv='რეკუპერაცია'
    search='ძებნა...'; filter='ფილტრი'; clear='გასუფთავება'
    fType='ტიპი'; fAir='ჰაერის ხარჯი'; fCat='კატეგორია'
    tWall='კედლის'; tCeil='ჭერის'; tDuct='არხული'; tWin='ფანჯრის'; tRoof='სახურავის'; tCent='ცენტრიდანული'
    aLow='500 მ³/სთ-მდე'; aMid='500-2000 მ³/სთ'; aHigh='2000 მ³/სთ-ზე მეტი'
    empty='პროდუქტი ვერ მოიძებნა.'
    catEyebrow='ვენტილაცია'; catH='აირჩიეთ ბრენდი'
    catP='ჩვენი სავენტილაციო პარტნიორი ბრენდები - დააჭირეთ ლოგოს პროდუქტების სანახავად.'
    goto='პროდუქტები'
    hubTitle='Vortice - ბიომი'; hubDesc='Vortice-ის სავენტილაციო ტექნიკა - აბაზანის, არხული, სამრეწველო ვენტილატორები და რეკუპერატორები.'
    catTitle='ვენტილაცია - ბიომი'; catDesc='სავენტილაციო სისტემები და ტექნიკა - აირჩიეთ ბრენდი პროდუქტების სანახავად.' }
  en = @{ file='-en.html'; hubTpl='mitsubishi-electric-en.html'; catTpl='vrf-vrv-en.html'
    home='Home'; products='Products'; vent='Ventilation'
    tabAll='All'; tabHome='Residential'; tabDuct='In-line'; tabInd='Commercial'; tabHrv='Heat recovery'
    search='Search...'; filter='Filter'; clear='Clear'
    fType='Type'; fAir='Airflow'; fCat='Category'
    tWall='Wall'; tCeil='Ceiling'; tDuct='In-duct'; tWin='Window'; tRoof='Roof'; tCent='Centrifugal'
    aLow='Up to 500 m³/h'; aMid='500-2000 m³/h'; aHigh='Over 2000 m³/h'
    empty='No products found.'
    catEyebrow='Ventilation'; catH='Choose a brand'
    catP='Our ventilation partner brands - click a logo to see the products.'
    goto='Products'
    hubTitle='Vortice - Biomi'; hubDesc='Vortice ventilation equipment - bathroom, in-line and commercial fans, and heat recovery units.'
    catTitle='Ventilation - Biomi'; catDesc='Ventilation systems and equipment - choose a brand to see the products.' }
}
function HtmlEnc($s) { $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }

function Splice($tplPath, $startMark, $newBody, $title, $desc, $file, $selfFrom) {
  $tpl = Get-Content $tplPath -Raw -Encoding UTF8
  $i = $tpl.IndexOf($startMark); $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw "markers not found in $tplPath" }
  $h = $tpl.Substring(0,$i); $tl = $tpl.Substring($j)
  # see vortice-gen.ps1: the meta block belongs to tools/build-meta.ps1, and
  # inheriting the template's would point this page's canonical and og: tags at
  # the page it was cloned from
  $h = [regex]::Replace($h, '(?s)[ \t]*<!-- meta:start.*?<!-- meta:end -->\r?\n', '')
  # Repoint the GEO/ENG switcher at this page -- and ONLY the switcher. The
  # template's own filename also appears in the nav and drawer as a genuine
  # link to that product ("Mitsubishi Electric", "VRF / VRV"), so a blanket
  # replace silently rewires those to the wrong page.
  # $file is already language-suffixed, so strip it back to the base before
  # rebuilding the pair -- otherwise the English pass produces "-en-en.html".
  $base = $file -replace '(-en)?\.html$', ''
  $swap = {
    param($block)
    $r = $block
    foreach ($s in ($selfFrom + '-en.html'), ($selfFrom + '.html')) {
      $to = if ($s -like '*-en.html') { $base + '-en.html' } else { $base + '.html' }
      $r = $r.Replace($s, $to)
    }
    return $r
  }
  foreach ($rx in '(?s)<div class="lang"[^>]*>.*?</div>', '(?s)<div class="drawer__langs">.*?</div>') {
    $h  = [regex]::Replace($h,  $rx, { param($m) & $swap $m.Value })
    $tl = [regex]::Replace($tl, $rx, { param($m) & $swap $m.Value })
  }
  $h = [regex]::Replace($h,'(?s)<title>.*?</title>', ('<title>' + (HtmlEnc $title) + '</title>'))
  $h = [regex]::Replace($h,'(?s)(<meta name="description" content=").*?(">)', ('${1}' + (HtmlEnc $desc) + '${2}'))
  return $h + $newBody + $tl
}

foreach ($lang in 'ka','en') {
  $t = $L[$lang]
  $sfx = $t.file

  # ------------------------------------------------------------------ the hub
  $cards = @()
  foreach ($f in $ordered) {
    $name = if ($lang -eq 'ka') { $f.nameKa } else { $f.nameEn }
    $c = $CAT[$f.slug]
    $g = @($mods | Where-Object { $_.slug -eq $f.slug })
    $max = ($g | ForEach-Object { [double]$_.airflow } | Measure-Object -Maximum).Maximum
    $air = if ($max -le 500) { 'low' } elseif ($max -le 2000) { 'mid' } else { 'high' }
    # data-name feeds the hub's own search box, so every model code and name goes in
    $terms = ($name + ' ' + (($g | ForEach-Object { $_.model + ' ' + $_.code }) -join ' '))
    $cards += @"
        <a class="pcard" href="$($f.slug)$sfx" data-cat="$($c.g)" data-name="$(HtmlEnc $terms)" data-type="$($c.t)" data-air="$air">
          <span class="pcard__img"><img src="../assets/img/products/$($f.slug)/main.avif" alt="$(HtmlEnc $name)"></span>
          <span class="pcard__body"><h4>$(HtmlEnc $name)</h4></span>
        </a>
"@
  }
  $hubBody = @"
<!-- ===================== BRAND LISTING ===================== -->
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../products$sfx">$($t.products)</a><span class="sep">/</span>
      <a href="ventilation$sfx">$($t.vent)</a><span class="sep">/</span>
      <b>Vortice</b>
    </nav>
    <img class="brand-hero__logo" src="../assets/img/partners/vortice.svg" alt="Vortice">
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="container" data-plist>
    <div class="plist">
      <aside class="pfilter">
        <div class="pfilter__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
          <input type="search" placeholder="$($t.search)">
        </div>
        <div class="pfilter__head"><span>$($t.filter)</span><a data-clear>$($t.clear)</a></div>
        <div class="pfilter__group pfilter__group--cats">
          <h4>$($t.fCat) <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg></h4>
          <div class="pfilter__opts">
            <div class="cattabs">
              <button class="active" type="button" data-cat="all">$($t.tabAll)</button>
              <button type="button" data-cat="home">$($t.tabHome)</button>
              <button type="button" data-cat="duct">$($t.tabDuct)</button>
              <button type="button" data-cat="ind">$($t.tabInd)</button>
              <button type="button" data-cat="hrv">$($t.tabHrv)</button>
            </div>
          </div>
        </div>
        <div class="pfilter__group">
          <h4>$($t.fType) <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg></h4>
          <div class="pfilter__opts">
            <label><input type="checkbox" name="type" value="wall">$($t.tWall)</label>
            <label><input type="checkbox" name="type" value="ceiling">$($t.tCeil)</label>
            <label><input type="checkbox" name="type" value="duct">$($t.tDuct)</label>
            <label><input type="checkbox" name="type" value="window">$($t.tWin)</label>
            <label><input type="checkbox" name="type" value="roof">$($t.tRoof)</label>
            <label><input type="checkbox" name="type" value="centrifugal">$($t.tCent)</label>
          </div>
        </div>
        <div class="pfilter__group">
          <h4>$($t.fAir) <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg></h4>
          <div class="pfilter__opts">
            <label><input type="checkbox" name="air" value="low">$($t.aLow)</label>
            <label><input type="checkbox" name="air" value="mid">$($t.aMid)</label>
            <label><input type="checkbox" name="air" value="high">$($t.aHigh)</label>
          </div>
        </div>
      </aside>

      <div class="pgrid">
$($cards -join "`r`n")
        <div class="pgrid__empty" style="display:none">$($t.empty)</div>
      </div>
    </div>
  </div>
</section>

"@
  $out = Join-Path $repo ('products\vortice' + $sfx)
  [IO.File]::WriteAllText($out, (Splice (Join-Path $repo ('products\' + $t.hubTpl)) '<!-- ===================== BRAND LISTING' $hubBody $t.hubTitle $t.hubDesc ('vortice' + $sfx) 'mitsubishi-electric'), (New-Object Text.UTF8Encoding($true)))

  # The Ventilation category page used to be built here too, as a brand picker
  # spliced off vrf-vrv.html. Both are now real product listings owned by
  # tools/build-category-pages.ps1, which reads the finished brand hubs -- so
  # run that after this script rather than expecting a picker here.
}
Write-Host 'wrote vortice.html, vortice-en.html'
Write-Host 'now run tools\build-category-pages.ps1 to refresh products\ventilation*.html'
