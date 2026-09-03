# Build products/water-heaters.html, the category listing.
#
# The boiler category page is built by tools/build-category-pages.ps1, which
# lifts cards out of per-brand hub pages. Water heaters have no brand hubs and
# do not warrant any: Beretta and Riello already own beretta.html and
# riello.html for their boilers, and a second hub per brand would be three more
# thin pages nobody links to. So the cards are written straight from the family
# list here, and boilers.html supplies the surrounding chrome.
. (Join-Path $PSScriptRoot 'config.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sp   = $PSScriptRoot
$fams = Get-Content (Join-Path $sp 'families.json')  -Raw -Encoding UTF8 | ConvertFrom-Json
$mods = Get-Content (Join-Path $sp 'wh-pages.json')  -Raw -Encoding UTF8 | ConvertFrom-Json
function HtmlEnc($s){ if($null -eq $s){return ''}; $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') }

$L = @{
  ka = @{ sfx='.html'; tpl='boilers.html'
    home='მთავარი'; products='პროდუქტი'; crumb='ბოილერი'
    eyebrow='გათბობა'; head='ბოილერები'
    lede='ირიბი გაცხელების ბოილერები და ავზები - 100-დან 2000 ლიტრამდე, ერთი და ორი თბომცვლელით.'
    title='ბოილერები - ბიომი'; desc='ბოილერები და ავზები Beretta-ს, Riello-სა და Omega-სგან.'
    fBrand='ბრენდი'; fType='ტიპი'; filter='ფილტრი'; clear='გასუფთავება'; empty='პროდუქტი ვერ მოიძებნა'
    search='ძებნა...' }
  en = @{ sfx='-en.html'; tpl='boilers-en.html'
    home='Home'; products='Products'; crumb='Water heaters'
    eyebrow='Heating'; head='Water heaters'
    lede='Indirect cylinders and tanks - from 100 to 2000 litres, with one or two coils.'
    title='Water heaters - Biomi'; desc='Cylinders and tanks from Beretta, Riello and Omega.'
    fBrand='Brand'; fType='Type'; filter='Filter'; clear='Clear'; empty='No products found.'
    search='Search...' }
}
# the third axis: what the vessel actually is, which is the real choice a buyer
# makes here -- one coil, two coils, or a tank with no coil at all
$TYPES = @(
  @('single','ერთი თბომცვლელი','Single coil'),
  @('twin','ორი თბომცვლელი','Twin coil'),
  @('tank','ავზი','Tank')
)
$TYPEOF = @{ 'beretta-idra-bv'='single'; 'riello-7200v'='single'; 'omega-esb'='single'
             'omega-ecsb'='twin'; 'omega-akm'='tank'; 'omega-obf'='tank' }
$CARET = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg>'

foreach ($lang in 'ka','en') {
  $t = $L[$lang]; $sfx = $t.sfx
  $tplPath = Join-Path $repo ('products' + [IO.Path]::DirectorySeparatorChar + $t.tpl)
  $tpl = Get-Content $tplPath -Raw -Encoding UTF8
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw "markers not found in $tplPath" }
  $head = $tpl.Substring(0,$i); $tail = $tpl.Substring($j)
  # the meta block belongs to tools/build-meta.ps1; drop the template's copy so
  # this page does not inherit boilers.html's canonical and Product schema
  $head = [regex]::Replace($head,'(?s)<!-- meta:start -->.*?<!-- meta:end -->\s*','')
  $head = [regex]::Replace($head,'(?s)<title>.*?</title>', ('<title>' + (HtmlEnc $t.title) + '</title>'))

  $brands = @()
  $cards = ''
  foreach ($f in $fams) {
    $name = if ($lang -eq 'ka') { $f.nameKa } else { $f.nameEn }
    $g = @($mods | Where-Object { $_.slug -eq $f.slug })
    $terms = ($name + ' ' + (($g | ForEach-Object { $_.name + ' ' + $_.code + ' ' + $_.mfr }) -join ' '))
    $bslug = $f.brand.ToLower()
    if ($brands -notcontains $bslug) { $brands += $bslug }
    $cards += @"
        <a class="pcard" href="$($f.slug)$sfx" data-brand="$bslug" data-cat="$($TYPEOF[$f.slug])" data-type="$($TYPEOF[$f.slug])" data-name="$(HtmlEnc $terms)">
          <span class="pcard__img"><img src="../assets/img/products/$($f.slug)/main.avif" alt="$(HtmlEnc $name)" loading="lazy"></span>
          <span class="pcard__body"><h4>$(HtmlEnc $name)</h4></span>
        </a>

"@
  }
  $bOpts = ''
  foreach ($b in $brands) {
    $lbl = ($fams | Where-Object { $_.brand.ToLower() -eq $b } | Select-Object -First 1).brand
    $bOpts += "            <label><input type=`"checkbox`" name=`"brand`" value=`"$b`">$lbl</label>`r`n"
  }
  $tOpts = ''
  foreach ($ty in $TYPES) {
    $lbl = if ($lang -eq 'ka') { $ty[1] } else { $ty[2] }
    $tOpts += "            <label><input type=`"checkbox`" name=`"type`" value=`"$($ty[0])`">$lbl</label>`r`n"
  }

  $body = @"
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../index.html#products">$($t.products)</a><span class="sep">/</span>
      <b>$($t.crumb)</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">$($t.eyebrow)</span>
      <h2>$($t.head)</h2>
      <p class="page-lede">$($t.lede)</p>
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
        <div class="pfilter__group">
          <h4>$($t.fBrand) $CARET</h4>
          <div class="pfilter__opts">
$bOpts          </div>
        </div>
        <div class="pfilter__group">
          <h4>$($t.fType) $CARET</h4>
          <div class="pfilter__opts">
$tOpts          </div>
        </div>
      </aside>
      <div>
        <div class="pgrid">
$cards        </div>
        <p class="pgrid__empty" style="display:none">$($t.empty)</p>
      </div>
    </div>
  </div>
</section>

"@
  $out = Join-Path $repo ('products' + [IO.Path]::DirectorySeparatorChar + 'water-heaters' + $sfx)
  [IO.File]::WriteAllText($out, ($head + $body + $tail), (New-Object Text.UTF8Encoding($false)))
  Write-Host ("  wrote water-heaters" + $sfx + "  (" + $fams.Count + " cards, " + $brands.Count + " brands)")
}
