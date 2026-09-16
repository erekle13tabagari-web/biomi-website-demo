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

# Lowest boiler output, read from the boiler data rather than typed into the
# table above: the "from N kW" band label must match the cards, and the cards
# are generated from this same file.
$KWMIN = ''
$bp = Join-Path $repo 'tools\boilers\boilers-pages.json'
if (Test-Path $bp) {
  $bm = Get-Content $bp -Raw -Encoding UTF8 | ConvertFrom-Json
  # Held-back outputs must not set the label either: see tools/boilers/visible.ps1.
  . (Join-Path $repo 'tools\boilers\visible.ps1')
  # The burners share that file but are not boilers and have no band here.
  $bm = @($bm | Where-Object { (Visible $_) -and $_.cat -ne 'burners' })
  $vals = @($bm | ForEach-Object { BoilerKw $_ } | Where-Object { $_ -gt 0 })
  if ($vals.Count) { $KWMIN = ($vals | Measure-Object -Minimum).Minimum }
}

$PAGES = @(
  @{ out='vrf-vrv'; from=@(
       @{ hub='samsung';             brand='samsung';    ka='Samsung';             en='Samsung' },
       @{ hub='mitsubishi-electric'; brand='mitsubishi'; ka='Mitsubishi Electric'; en='Mitsubishi Electric' })
     eyebrowKa='გაგრილება'; eyebrowEn='Cooling'
     headKa='Multisplit / VRV / VRF'; headEn='Multisplit / VRV / VRF'
     crumbKa='გაგრილება'; crumbEn='Cooling'
     titleKa='გაგრილება - ბიომი'; titleEn='Cooling - Biomi'
     ledeKa='ერთი გარე ბლოკი ამარაგებს რამდენიმე შიდა ბლოკს. VRF და VRV სისტემები მაცივარაგენტის ხარჯს თითოეული ოთახის საჭიროებაზე არეგულირებს.'; ledeEn='One outdoor unit serves several indoor units. VRF and VRV systems vary the refrigerant flow to match what each room actually needs.'
     pdescKa='Multisplit, VRV და VRF სისტემები Samsung-ისა და Mitsubishi Electric-ისგან.'; pdescEn='Multisplit, VRV and VRF systems from Samsung and Mitsubishi Electric.'
     # Plain names in the filter. What each range is and how it differs from the
     # others is explained under the filter instead (notes), at a length a
     # one-line gloss under a checkbox could not hold.
     series=@(
       @('dvm','DVM','DVM'),
       @('cac','CAC','CAC'),
       @('fjm','FJM','FJM'),
       @('m-series','M Series','M Series'),
       @('mr-slim','Mr Slim','Mr Slim'),
       @('citymulti','City Multi','City Multi'))
     seriesKa='სერია'; seriesEn='Series'
     # What each series is and how it differs, shown from the "!" beside its name
     # in the filter (hover, or a click/tap). Name, make and kind of system, and
     # the explanation. The Georgian is Biomi's own wording (martivi axsna.docx,
     # 2026-09-15), kept as written apart from long dashes; the English follows
     # it. There is no separate guide section: it was taken off on request, the
     # "!" carries it alone.
     notes=@(
       @('DVM', 'Samsung · VRF', 'Samsung · VRF',
         'DVM (Digital Variable Multi) არის VRF მრავალზონიანი კონდიცირების სისტემა, სადაც ცვლადი წარმადობის კომპრესორებისა და მაცივარაგენტის ნაკადის ელექტრონული მართვის საშუალებით ერთი გარე სისტემა მრავალ შიდა ზონას ემსახურება და თითოეულ ზონას მოთხოვნის შესაბამისად აწვდის საჭირო სიმძლავრეს.',
         'DVM (Digital Variable Multi) is a VRF multi-zone air-conditioning system: with variable-capacity compressors and electronic control of the refrigerant flow, one outdoor system serves many indoor zones and gives each zone the capacity it needs.'),
       @('CAC', 'Samsung · მსუბუქი კომერციული', 'Samsung · light commercial',
         'CAC (Commercial Air Conditioner) - კომერციული დანიშნულების კონდიცირების სისტემების კატეგორიაა, რომელიც გამოიყენება ძირითადად ოფისებში, მაღაზიებში, რესტორნებსა და სხვა კომერციულ ობიექტებში.',
         'CAC (Commercial Air Conditioner) - a category of air-conditioning systems for commercial use, mainly in offices, shops, restaurants and other commercial premises.'),
       @('FJM', 'Samsung · მულტი-სპლიტი', 'Samsung · multi-split',
         'FJM (Free Joint Multi) - Samsung-ის მრავალბლოკიანი კონდიცირების სისტემაა, სადაც ერთი გარე ბლოკი რამდენიმე შიდა ბლოკს დამოუკიდებლად ემსახურება, რაც საშუალებას იძლევა სხვადასხვა ოთახში ინდივიდუალური ტემპერატურის კონტროლი.',
         'FJM (Free Joint Multi) - Samsung''s multi-unit air-conditioning system, in which one outdoor unit serves several indoor units independently, so every room can have its own temperature.'),
       @('M Series', 'Mitsubishi Electric · საყოფაცხოვრებო', 'Mitsubishi Electric · residential',
         'M Series (Mitsubishi Electric) - Mitsubishi Electric-ის საყოფაცხოვრებო და მცირე სივრცეებისთვის განკუთვნილი ინვერტერული კონდიციონერების სერიაა, რომელიც გამოიყენება როგორც ერთ-კომბინაციაში, ისე Multi-Split MXZ სისტემებთან; გათვლილია გათბობა-გაგრილებაზე.',
         'M Series (Mitsubishi Electric) - Mitsubishi Electric''s range of inverter air conditioners for homes and small spaces, used both as a single split and with MXZ multi-split systems; built for heating and cooling.'),
       @('Mr Slim', 'Mitsubishi Electric · მსუბუქი კომერციული', 'Mitsubishi Electric · light commercial',
         'Mr. Slim - Mitsubishi Electric-ის კომერციული დანიშნულების ინვერტერული კონდიცირების სისტემების სერიაა, რომელიც განკუთვნილია მცირე და საშუალო კომერციული სივრცეების გათბობა-გაგრილებისთვის.',
         'Mr. Slim - Mitsubishi Electric''s range of inverter air-conditioning systems for commercial use, made for heating and cooling small and medium-sized commercial spaces.'),
       @('City Multi', 'Mitsubishi Electric · VRF', 'Mitsubishi Electric · VRF',
         'City Multi - Mitsubishi Electric-ის VRF/VRF2 ტიპის მრავალზონიანი კომერციული კონდიცირების სისტემების სერიაა, რომელიც ერთი გარე სისტემით მრავალი შიდა ბლოკის დამოუკიდებელ გათბობასა და გაგრილებას უზრუნველყოფს.',
         'City Multi - Mitsubishi Electric''s range of VRF/VRF2 multi-zone commercial air-conditioning systems, in which one outdoor system provides independent heating and cooling for many indoor units.'))
     typeKa='ტიპი'; typeEn='Type'
     types=@(@('wall','კედლის','Wall'),@('cassette','კასეტური','Cassette'),@('duct','არხული','Duct'),
             @('ceiling','ჭერის','Ceiling'),@('outdoor','გარე ბლოკი','Outdoor unit'))
     extraKa='მაცივარაგენტი'; extraEn='Refrigerant'; extraName='ref'
     extras=@(@('r32','R32','R32'),@('r410a','R410A','R410A')) },

  @{ out='boilers'; from=@(
       @{ hub='beretta';  brand='beretta';  ka='Beretta';  en='Beretta'  },
       @{ hub='riello';   brand='riello';   ka='Riello';   en='Riello'   },
       @{ hub='warmhaus'; brand='warmhaus'; ka='Warmhaus'; en='Warmhaus' })
     eyebrowKa='გათბობა'; eyebrowEn='Heating'
     headKa='გათბობის ქვაბი'; headEn='Heating boilers'
     crumbKa='ქვაბი'; crumbEn='Boilers'
     titleKa='გათბობის ქვაბი - ბიომი'; titleEn='Heating boilers - Biomi'
     # Commercial only while the wall-hung ranges are held back: the old copy
     # promised flats, private houses and wall-hung boilers, none of which the
     # page can still show. The description is what a search result prints, so
     # leaving it would have advertised products and delivered none of them.
     # Both lines go back when tools/boilers/visible.ps1 opens the range again.
     # "Gas" came off when RTQ 3S arrived: it takes a separate burner, and the
     # burner can be an oil one.
     ledeKa='ქვაბები კომერციული ობიექტისთვის - კასკადური სერიები და ფოლადის ქვაბი ცალკე სანთურასთან სამუშაოდ.'; ledeEn='Boilers for commercial buildings - cascade ranges, and a steel boiler that takes a separate burner.'
     pdescKa='გათბობის ქვაბები Beretta-ს, Riello-სა და Warmhaus-ისგან - კომერციული კასკადური სერიები და ფოლადის ქვაბები სანთურისთვის.'; pdescEn='Heating boilers from Beretta, Riello and Warmhaus - commercial cascade ranges and steel boilers for a separate burner.'
     # the hub cards carry data-cat="<brand slug>", so the second group would just
     # repeat the brand filter -- output band is the useful second axis here
     # Bands follow the published range, the same way the brand hubs build
     # theirs: with the small outputs held back (tools/boilers/visible.ps1) the
     # first band has nothing in it and is dropped, and the middle one starts at
     # the smallest boiler on sale rather than at a typed 36.
     series=$(if ($KWMIN -and $KWMIN -gt 35) {
                @(@('k2',"$KWMIN-99 kW","$KWMIN-99 kW"),@('k3','100 kW და მეტი','100 kW and above'))
              } else {
                @(@('k1','{kwmin}-35 kW','{kwmin}-35 kW'),@('k2','36-99 kW','36-99 kW'),@('k3','100 kW და მეტი','100 kW and above'))
              })
     seriesKa='სიმძლავრე'; seriesEn='Output'; seriesName='kw'
     typeKa='წარმოშობა'; typeEn='Origin'
     types=@(@('it','იტალია','Italy'),@('tr','თურქეთი','Turkey'))
     extraKa=''; extraEn=''; extraName=''; extras=@() },

  # Burners, the other half of RTQ 3S. One brand today, so the brand group
  # holds a single box; the fuel is the axis worth filtering on, and the hub
  # carries it on data-type.
  @{ out='burners'; from=@(
       @{ hub='riello-burners'; brand='riello'; ka='Riello'; en='Riello' })
     eyebrowKa='გათბობა'; eyebrowEn='Heating'
     headKa='სანთურები'; headEn='Burners'
     crumbKa='სანთურები'; crumbEn='Burners'
     titleKa='სანთურები - ბიომი'; titleEn='Burners - Biomi'
     ledeKa='ვენტილატორიანი სანთურები ქვაბისთვის - ბუნებრივ აირზე და დიზელის საწვავზე.'; ledeEn='Forced-draught burners for boilers - natural gas and light oil.'
     pdescKa='Riello-ს სანთურები ქვაბისთვის - ბუნებრივ აირზე და დიზელის საწვავზე.'; pdescEn='Riello burners for boilers - natural gas and light oil.'
     series=@(); seriesKa=''; seriesEn=''
     typeKa='საწვავი'; typeEn='Fuel'
     types=@(@('gas','ბუნებრივი აირი','Natural gas'),@('oil','დიზელის საწვავი','Light oil'))
     extraKa=''; extraEn=''; extraName=''; extras=@() },

  @{ out='ventilation'; from=@(
       @{ hub='vortice'; brand='vortice'; ka='Vortice'; en='Vortice' })
     eyebrowKa='ვენტილაცია'; eyebrowEn='Ventilation'
     headKa='სავენტილაციო სისტემები'; headEn='Ventilation systems'
     crumbKa='ვენტილაცია'; crumbEn='Ventilation'
     titleKa='ვენტილაცია - ბიომი'; titleEn='Ventilation - Biomi'
     ledeKa='აბაზანის, არხული და სამრეწველო ვენტილატორები, აგრეთვე რეკუპერაციის სისტემები.'; ledeEn='Bathroom, in-line and commercial fans, plus heat-recovery units.'
     pdescKa='სავენტილაციო სისტემები და ტექნიკა Vortice-ისგან.'; pdescEn='Ventilation systems and equipment from Vortice.'
     series=@(@('home','საყოფაცხოვრებო','Residential'),@('duct','არხული','In-line'),
              @('ind','სამრეწველო','Commercial'),@('hrv','რეკუპერაცია','Heat recovery'))
     # Sections rather than a facet: these four are the parts the range divides
     # into, so they lead the panel and the filters follow.
     seriesKa='კატეგორია'; seriesEn='Category'; seriesFirst=$true
     typeKa='ტიპი'; typeEn='Type'
     types=@(@('wall','კედლის','Wall'),@('ceiling','ჭერის','Ceiling'),@('duct','არხული','In-duct'),
             @('window','ფანჯრის','Window'),@('roof','სახურავის','Roof'),@('centrifugal','ცენტრიდანული','Centrifugal'))
     extraKa='ჰაერის ხარჯი'; extraEn='Airflow'; extraName='air'
     extras=@(@('low','500 მ³/სთ-მდე','Up to 500 m³/h'),@('mid','500-2000 მ³/სთ','500-2000 m³/h'),
              @('high','2000 მ³/სთ-ზე მეტი','Over 2000 m³/h')) },

  # A whole chapter on one page, which the chapter name in the menu and on
  # products.html opens. Its sources are the category listings rather than
  # brand hubs, so a "sec" on each: every card is stamped data-sec with it, the
  # sections become the first filter, and the brands are read off the cards
  # (one listing holds several makes). Keep it after boilers and burners in
  # this list -- it reads what they have just written. water-heaters.html comes
  # from tools/boilers/4-hubs.ps1. No type axis: origin, fuel and tank type mean
  # different things in each section.
  @{ out='heating'; from=@(
       @{ hub='boilers';       sec='boilers';       ka='ქვაბი';     en='Boilers' },
       @{ hub='burners';       sec='burners';       ka='სანთურები'; en='Burners' },
       @{ hub='water-heaters'; sec='water-heaters'; ka='ბოილერები'; en='Water heaters' })
     eyebrowKa='გათბობა'; eyebrowEn='Heating'
     headKa='გათბობის ტექნიკა'; headEn='Heating equipment'
     crumbKa='გათბობა'; crumbEn='Heating'
     titleKa='გათბობა - ბიომი'; titleEn='Heating - Biomi'
     ledeKa='გათბობის ქვაბები, სანთურები და ბოილერები - ყველა ერთ ადგილას.'; ledeEn='Heating boilers, burners and water heaters - all in one place.'
     pdescKa='გათბობის ქვაბები, სანთურები და ბოილერები - Beretta, Riello, Warmhaus, Omega.'; pdescEn='Heating boilers, burners and water heaters - Beretta, Riello, Warmhaus, Omega.'
     series=@(); seriesKa='კატეგორია'; seriesEn='Category'; seriesName='sec'; seriesFirst=$true
     typeKa=''; typeEn=''; types=@()
     extraKa=''; extraEn=''; extraName=''; extras=@() }
)
# The make as the brand filter prints it, where that is more than the slug with
# a capital letter.
$BRANDNAME = @{ mitsubishi='Mitsubishi Electric' }
$L = @{
  ka = @{ sfx='.html'; home='მთავარი'; products='პროდუქტი'; search='ძებნა...'
          filter='ფილტრი'; clear='გასუფთავება'; brand='ბრენდი'
          empty='პროდუქტი ვერ მოიძებნა.' }
  en = @{ sfx='-en.html'; home='Home'; products='Products'; search='Search...'
          filter='Filter'; clear='Clear'; brand='Brand'
          empty='No products found.' }
}
$CARET = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 9 6 6 6-6"/></svg>'

function FilterGroup($label, $name, $opts, $li, $cls) {
  # a group with nothing in it renders as a dead heading, so drop it entirely.
  # Not every category has four useful axes.
  if (-not $opts -or -not @($opts).Count -or -not $name) { return '' }
  $extra = if ($cls) { ' ' + $cls } else { '' }
  $s = "        <div class=`"pfilter__group$extra`">`r`n          <h4>$label $CARET</h4>`r`n          <div class=`"pfilter__opts`">`r`n"
  foreach ($o in $opts) {
    $txt = if ($li -eq 'ka') { $o[1] } else { $o[2] }
    if ($KWMIN) { $txt = $txt.Replace('{kwmin}', [string]$KWMIN) }
    # A 5-element option carries a one-line gloss. The series names are trade
    # abbreviations -- DVM, FJM, Mr Slim -- that tell a visitor nothing on their
    # own, so the filter explains itself rather than sending them elsewhere.
    $hint = ''
    if (@($o).Count -ge 5) { $hint = if ($li -eq 'ka') { $o[3] } else { $o[4] } }
    if ($hint) {
      $s += "            <label class=`"has-hint`"><input type=`"checkbox`" name=`"$name`" value=`"$($o[0])`"><span class=`"opt`">$txt<small>$hint</small></span></label>`r`n"
    } else {
      $s += "            <label><input type=`"checkbox`" name=`"$name`" value=`"$($o[0])`">$txt</label>`r`n"
    }
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
    $secOpts = @()
    $secSubs = @{}
    $brandSeen = [ordered]@{}
    foreach ($src in $p.from) {
      $hubFile = Join-Path $prod ($src.hub + $sfx)
      if (-not (Test-Path $hubFile)) { Write-Host "  missing hub $hubFile"; continue }
      $hub = [IO.File]::ReadAllText($hubFile)
      $n = 0
      foreach ($m in [regex]::Matches($hub, '(?s)<a class="pcard" href="[^"]*".*?</a>')) {
        $card = $m.Value -replace '\s+$',''
        if ($card -notmatch 'data-brand=' -and $src.brand) {
          $card = $card -replace '(<a class="pcard" href="[^"]*")', ('$1 data-brand="' + $src.brand + '"')
        }
        if ($src.sec) {
          $card = $card -replace '(<a class="pcard" href="[^"]*")', ('$1 data-sec="' + $src.sec + '"')
          $bm2 = [regex]::Match($card, 'data-brand="([^"]+)"')
          if ($bm2.Success) { $brandSeen[$bm2.Groups[1].Value] = $true }
        }
        $cards += (($card -split "`r?`n" | ForEach-Object { '        ' + $_.TrimStart() }) -join "`r`n") + "`r`n"
        $n++
      }
      if ($src.sec) {
        $secOpts += ,@($src.sec, $src.ka, $src.en)
        # That listing's own filters, apart from brand (the chapter page has one
        # brand filter for everything), go under its category box, each input
        # scoped to the section: main.js applies a scoped box to that section's
        # cards only, which matters because every listing files something
        # different under data-type -- origin, fuel, tank.
        $subHtml = ''
        $aside = [regex]::Match($hub, '(?s)<aside class="pfilter">.*?</aside>').Value
        foreach ($g in [regex]::Matches($aside, '(?s)<div class="pfilter__group[^"]*">\s*<h4>(.*?)\s*<svg.*?</h4>\s*<div class="pfilter__opts">(.*?)</div>\s*</div>')) {
          $labels = @([regex]::Matches($g.Groups[2].Value, '(?s)<label[^>]*>.*?</label>') | ForEach-Object { $_.Value })
          if (-not $labels.Count -or $labels[0] -match 'name="brand"') { continue }
          $subHtml += "              <div class=`"pfilter__subgroup`">`r`n                <h5>" + $g.Groups[1].Value.Trim() + "</h5>`r`n"
          foreach ($lb in $labels) {
            $subHtml += '                ' + ($lb -replace '(<input [^>]*?)(>)', ('$1 data-scope="' + $src.sec + '"$2')) + "`r`n"
          }
          $subHtml += "              </div>`r`n"
        }
        $secSubs[$src.sec] = $subHtml
      }
      else { $brandOpts += ,@($src.brand, $src.ka, $src.en) }
      Write-Host ("  {0,-18} <- {1,2} cards from {2}" -f ($p.out + $sfx), $n, ($src.hub + $sfx))
    }
    foreach ($bslug in ($brandSeen.Keys | Sort-Object)) {
      $bname = if ($BRANDNAME[$bslug]) { $BRANDNAME[$bslug] } else { $bslug.Substring(0,1).ToUpper() + $bslug.Substring(1) }
      $brandOpts += ,@($bslug, $bname, $bname)
    }
    $series = if ($secOpts.Count) { $secOpts } else { $p.series }

    $head = if ($lang -eq 'ka') { $p.headKa } else { $p.headEn }
    $eyebrow = if ($lang -eq 'ka') { $p.eyebrowKa } else { $p.eyebrowEn }
    $crumb = if ($lang -eq 'ka') { $p.crumbKa } else { $p.crumbEn }
    # The lede sits inside the heading block, so it is built with the markup
    # rather than passed in empty: a page without one must emit no <p> at all.
    $ledeTxt = if ($lang -eq 'ka') { $p.ledeKa } else { $p.ledeEn }
    $lede = ''
    if ($ledeTxt) { $lede = "`r`n      <p class=`"page-lede`">" + $ledeTxt + "</p>" }
    $seriesLbl = if ($lang -eq 'ka') { $p.seriesKa } else { $p.seriesEn }
    $typeLbl = if ($lang -eq 'ka') { $p.typeKa } else { $p.typeEn }
    $extraLbl = if ($lang -eq 'ka') { $p.extraKa } else { $p.extraEn }
    # Checkboxes like every other group -- the sections are set apart by coming
    # first and by the wider rule under them (.pfilter__group--cats), not by a
    # control of their own. Ticking none means all, so there is no "all" option:
    # a box that only undoes the others is one more thing to read past.
    $seriesCls = if ($p.seriesFirst) { 'pfilter__group--cats' } else { '' }
    $seriesGrp = FilterGroup $seriesLbl $(if ($p.seriesName) { $p.seriesName } else { 'cat' }) $series $lang $seriesCls
    # A series with a note gets a small "!" after its name: hovering it shows the
    # explanation (CSS, from data-tip), and a click or tap pins it open (main.js).
    # Inside the label, so the click handler has to stop it ticking the box.
    if ($p.notes) {
      $infoLbl = if ($lang -eq 'ka') { 'სერიის განმარტება' } else { 'About this series' }
      foreach ($nt in $p.notes) {
        $hit = @($p.series | Where-Object { $_[1] -eq $nt[0] } | Select-Object -First 1)
        if (-not $hit.Count) { continue }
        $tip = $(if ($lang -eq 'ka') { $nt[3] } else { $nt[4] }) -replace '"', '&quot;'
        $optEnd = 'value="' + $hit[0][0] + '">' + $nt[0] + '</label>'
        $seriesGrp = $seriesGrp.Replace($optEnd, ('value="' + $hit[0][0] + '">' + $nt[0] +
          ' <button type="button" class="pfilter__info" aria-expanded="false" data-tip="' + $tip +
          '" aria-label="' + $infoLbl + ': ' + $nt[0] + '">!</button></label>'))
      }
    }
    # On a chapter page each category box is followed by its own filters,
    # closed until the box is ticked (main.js opens them).
    if ($secOpts.Count) {
      foreach ($o in $secOpts) {
        if (-not $secSubs[$o[0]]) { continue }
        $optTxt = if ($lang -eq 'ka') { $o[1] } else { $o[2] }
        $lblLine = '<label><input type="checkbox" name="' + $p.seriesName + '" value="' + $o[0] + '">' + $optTxt + '</label>'
        $subBlock = $lblLine + "`r`n            <div class=`"pfilter__sub`" data-for=`"" + $o[0] + "`" hidden>`r`n" + $secSubs[$o[0]] + '            </div>'
        $seriesGrp = $seriesGrp.Replace($lblLine, $subBlock)
      }
    }
    # You pick the part of the catalogue first, then narrow what is in it, so the
    # sections lead. vrf-vrv's series are ranges rather than sections -- DVM, CAC,
    # Mr Slim -- and stay where they were, after the brand.
    $grpBrand = FilterGroup $t.brand 'brand' $brandOpts $lang
    $grpTop = if ($p.seriesFirst) { $seriesGrp + $grpBrand } else { $grpBrand + $seriesGrp }

    $body = @"
<!-- ===================== CATEGORY LISTING ===================== -->
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index.html">$($t.home)</a><span class="sep">/</span>
      <a href="../products$($t.sfx)">$($t.products)</a><span class="sep">/</span>
      <b>$crumb</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">$eyebrow</span>
      <h2>$head</h2>$lede
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
$grpTop$(FilterGroup $typeLbl 'type' $p.types $lang)$(FilterGroup $extraLbl $p.extraName $p.extras $lang)      </aside>

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

    # the page may have been seeded by copying another category page, so its
    # title, description and GEO/ENG switcher still point at that one
    $ttl = if ($lang -eq 'ka') { $p.titleKa } else { $p.titleEn }
    $dsc = if ($lang -eq 'ka') { $p.pdescKa } else { $p.pdescEn }
    if ($ttl) { $txt = [regex]::Replace($txt,'(?s)<title>.*?</title>', ('<title>' + $ttl + '</title>')) }
    if ($dsc) { $txt = [regex]::Replace($txt,'(?s)(<meta name="description" content=").*?(">)', ('${1}' + $dsc + '${2}')) }
    foreach ($rx in '(?s)<div class="lang"[^>]*>.*?</div>','(?s)<div class="drawer__langs">.*?</div>') {
      $txt = [regex]::Replace($txt, $rx, {
        param($m) ($m.Value -replace 'href="[^"]*-en\.html"', ('href="' + $p.out + '-en.html"') `
                             -replace 'href="(?!.*-en\.html)[^"]*\.html"', ('href="' + $p.out + '.html"')) })
    }
    # With the BOM: every other page on the site carries one, and writing these
    # six without it stripped theirs on every run -- a diff in six files that had
    # nothing to do with whatever was being rebuilt.
    [IO.File]::WriteAllText($file, $txt, (New-Object Text.UTF8Encoding($true)))
  }
}
Write-Host 'category listings rebuilt'
