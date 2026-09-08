# Brand hubs for Beretta, Riello and Warmhaus.
#
# One card per series, filtered by output band. No category tabs: since the
# tabs moved into the filter panel there is nothing a second control would add
# on a hub this size.
. (Join-Path $PSScriptRoot 'config.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'families.json')      -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'boilers-pages.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# Only the published outputs get a card -- see visible.ps1 for the threshold.
# Filtering here rather than at the card loop also keeps $KWMIN below honest:
# it is measured from what is actually on the page, so the "from N kW" label
# follows the range instead of advertising a boiler nobody can reach.
. (Join-Path $sp 'visible.ps1')
$mods = @($mods | Where-Object { (BoilerKw $_.name) -ge $BOILER_KWMIN })

$BRANDS = @(
  @{ brand='Beretta';  slug='beretta';  logo='beretta.svg'  },
  @{ brand='Riello';   slug='riello';   logo='riello.svg'   },
  @{ brand='Warmhaus'; slug='warmhaus'; logo='warmhaus.svg' }
)
function Kw($n){ $m=[regex]::Match($n,'\b(\d{2,3})\b'); if($m.Success){return [int]$m.Groups[1].Value}; return 0 }
# lowest output in the range, so the "from N kW" label cannot drift from the
# products: it is the LAWA 18 today, and a typed figure would quietly lie the
# moment a smaller unit is added.
$KWMIN = ($mods | ForEach-Object { Kw $_.name } | Where-Object { $_ -gt 0 } | Measure-Object -Minimum).Minimum
# The middle band starts at the smallest output actually on sale, not at a typed
# 36: with the small ranges held back (visible.ps1) the lowest boiler is a 50,
# and a band advertising 36 would promise a size the page cannot show.
$KWLO = if ($KWMIN -gt 36) { $KWMIN } else { 36 }
$L = @{
  ka = @{ file='.html'; tpl='vortice.html'; home='მთავარი'; products='პროდუქტი'; cat='ქვაბი'
          search='ძებნა...'; filter='ფილტრი'; clear='გასუფთავება'; fKw='სიმძლავრე'
          k1="$($KWMIN)-35 kW"; k2="$($KWLO)-99 kW"; k3='100 kW და მეტი'; empty='პროდუქტი ვერ მოიძებნა.' }
  en = @{ file='-en.html'; tpl='vortice-en.html'; home='Home'; products='Products'; cat='Boilers'
          search='Search...'; filter='Filter'; clear='Clear'; fKw='Output'
          k1="$($KWMIN)-35 kW"; k2="$($KWLO)-99 kW"; k3='100 kW and above'; empty='No products found.' }
}
$CARET='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg>'
function HtmlEnc($s){ if($null -eq $s){return ''}; $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }


foreach ($b in $BRANDS) {
  foreach ($lang in 'ka','en') {
    $t = $L[$lang]; $sfx = $t.file
    $tplPath = Join-Path $repo ('products\' + $t.tpl)
    $tpl = Get-Content $tplPath -Raw -Encoding UTF8
    $i = $tpl.IndexOf('<!-- ===================== BRAND LISTING')
    $j = $tpl.IndexOf('<!-- ===================== FOOTER')
    if ($i -lt 0 -or $j -lt 0) { throw "markers not found in $($t.tpl)" }
    $h = $tpl.Substring(0,$i); $tl = $tpl.Substring($j)
    $h = [regex]::Replace($h,'(?s)[ \t]*<!-- meta:start.*?<!-- meta:end -->\r?\n','')
    foreach ($rx in '(?s)<div class="lang"[^>]*>.*?</div>','(?s)<div class="drawer__langs">.*?</div>') {
      foreach ($ref in 'vortice-en.html','vortice.html') {
        $to = if ($ref -like '*-en.html') { $b.slug + '-en.html' } else { $b.slug + '.html' }
        $h  = [regex]::Replace($h,  $rx, { param($m) $m.Value.Replace($ref,$to) })
        $tl = [regex]::Replace($tl, $rx, { param($m) $m.Value.Replace($ref,$to) })
      }
    }

    $cards = ''
    foreach ($f in ($fams | Where-Object { $_.brand -eq $b.brand })) {
      $g = @($mods | Where-Object { $_.slug -eq $f.slug })
      if (-not $g.Count) { continue }
      $name = if ($lang -eq 'ka') { $f.nameKa } else { $f.nameEn }
      $max = ($g | ForEach-Object { Kw $_.name } | Measure-Object -Maximum).Maximum
      $band = if ($max -le 35) { 'k1' } elseif ($max -lt 100) { 'k2' } else { 'k3' }
      # origin travels on data-type so the category listing can filter by it
      $ctry = ($g | Where-Object { $_.country } | Select-Object -First 1).country
      $origin = if ($ctry -eq 'თურქეთი') { 'tr' } elseif ($ctry) { 'it' } else { '' }
      $terms = $name + ' ' + (($g | ForEach-Object { ($_.name -replace '\s*გათბობის ქვაბი.*$','') + ' ' + $_.code + ' ' + $_.mfr }) -join ' ')      # The card shows the model name and its output, nothing else, so the
      # family name loses its type descriptor here: "CIAO S კედლის ქვაბი" is a
      # heading on the product page but only noise repeated across a grid where
      # every card is a boiler. The full name stays in data-name for search.
      $short = if ($lang -eq 'ka') { $name -replace '\s*(კედლის\s+)?ქვაბი\s*$','' }
               else                { $name -replace '\s*(wall-hung\s+)?boiler\s*$','' }
      # one output or a span, taken from the models actually on the page
      $kws = @($g | ForEach-Object { Kw $_.name } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
      $kwTxt = if (-not $kws.Count) { '' }
               elseif ($kws[0] -eq $kws[-1]) { "$($kws[0]) kW" }
               else { "$($kws[0])-$($kws[-1]) kW" }      $kwSpan = ''
      if ($kwTxt) { $kwSpan = '<span class="pcard__kw">' + $kwTxt + '</span>' }
      $cards += "        <a class=`"pcard`" href=`"$($f.slug)$sfx`" data-cat=`"$($b.slug)`" data-name=`"$(HtmlEnc $terms)`" data-kw=`"$band`" data-type=`"$origin`">`r`n" +
                "          <span class=`"pcard__img`"><img src=`"../assets/img/products/$($f.slug)/main.avif`" alt=`"$(HtmlEnc $name)`"></span>`r`n" +
                "          <span class=`"pcard__body`"><h4>$(HtmlEnc $short)</h4>$kwSpan</span>`r`n        </a>`r`n"
    }

    # Only offer the bands that have something behind them. Holding the small
    # ranges back empties the first one, and a checkbox that can only ever
    # return "no products found" is worse than no checkbox.
    $kwOpts = ''
    foreach ($k in 'k1','k2','k3') {
      if ($cards -notmatch ('data-kw="' + $k + '"')) { continue }
      $kwOpts += "            <label><input type=`"checkbox`" name=`"kw`" value=`"$k`">$($t.$k)</label>`r`n"
    }

    $body = @"
<!-- ===================== BRAND LISTING ===================== -->
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../index.html#products">$($t.products)</a><span class="sep">/</span>
      <a href="boilers$sfx">$($t.cat)</a><span class="sep">/</span>
      <b>$($b.brand)</b>
    </nav>
    <img class="brand-hero__logo" src="../assets/img/partners/$($b.logo)" alt="$($b.brand)">
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
        <div class="pfilter__group">
          <h4>$($t.fKw) $CARET</h4>
          <div class="pfilter__opts">
$kwOpts
          </div>
        </div>
      </aside>

      <div class="pgrid">
$cards        <div class="pgrid__empty" style="display:none">$($t.empty)</div>
      </div>
    </div>
  </div>
</section>

"@
    $title = "$($b.brand) - " + $(if ($lang -eq 'ka') { 'ბიომი' } else { 'Biomi' })
    $descr = if ($lang -eq 'ka') { "$($b.brand)-ის გათბობის ქვაბები - კედლის და კომერციული სერიები." }
             else { "$($b.brand) heating boilers - wall-hung and commercial ranges." }
    $h = [regex]::Replace($h,'(?s)<title>.*?</title>',('<title>' + (HtmlEnc $title) + '</title>'))
    $h = [regex]::Replace($h,'(?s)(<meta name="description" content=").*?(">)',('${1}' + (HtmlEnc $descr) + '${2}'))
    [IO.File]::WriteAllText((Join-Path $repo ('products\' + $b.slug + $sfx)), ($h + $body + $tl), (New-Object Text.UTF8Encoding($false)))
    Write-Host ("  wrote " + $b.slug + $sfx)
  }
}
