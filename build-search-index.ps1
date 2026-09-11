# Build the site search index, one file per language.
#
# Products come straight out of the hub pages' .pcard markup, which already
# carries everything a result needs: the link, the display name, the model code,
# a thumbnail and the searchable data-name. Regenerating from the hubs (rather
# than hand-maintaining a list) means adding a product to a hub is the only step
# needed for it to become findable.
#
# Paths are stored root-relative; the runtime works out the "../" prefix from
# the page's own stylesheet href.
# Runs from the repo root, wherever that is (called by Update Website.bat).
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$enc  = New-Object Text.UTF8Encoding($false)

# Static pages, per language: path, title, kind label
$staticKa = @(
  @{ url = 'index.html';                    title = 'მთავარი';               kind = 'გვერდი' },
  @{ url = 'about.html';                    title = 'ჩვენ შესახებ';          kind = 'გვერდი' },
  @{ url = 'projects.html'; title = 'ჩვენი პროექტები'; kind = 'გვერდი' },
  # hidden for now: @{ url = 'service.html';                  title = 'სერვისი და ტექნიკური მხარდაჭერა'; kind = 'გვერდი' },
  @{ url = 'products/vrf-vrv.html';         title = 'VRF / VRV სისტემა';     kind = 'კატეგორია' },
  @{ url = 'products/samsung.html';         title = 'Samsung';               kind = 'ბრენდი' },
  @{ url = 'products/mitsubishi-electric.html'; title = 'Mitsubishi Electric'; kind = 'ბრენდი' },
  @{ url = 'products/boilers.html';         title = 'ქვაბი';                 kind = 'კატეგორია' },
  @{ url = 'products/burners.html';         title = 'სანთურები';             kind = 'კატეგორია' },
  @{ url = 'products/water-heaters.html';    title = 'ბოილერი';               kind = 'კატეგორია' },
  @{ url = 'products/ventilation.html';     title = 'ვენტილაცია';            kind = 'კატეგორია' },
  @{ url = 'products/vortice.html';         title = 'Vortice';               kind = 'ბრენდი' },
  @{ url = 'news/duct-production.html'; title = '„ბიომი ჰოლდინგმა“ ჰაერსატარების წარმოების შესაძლებლობები გაზარდა'; kind = 'სიახლე' },
  @{ url = 'news/team-expansion.html'; title = '„ბიომი ჰოლდინგმა“ საინჟინრო და საპროექტო გუნდები გააფართოვა'; kind = 'სიახლე' }
)
$staticEn = @(
  @{ url = 'index-en.html';                 title = 'Home';                  kind = 'Page' },
  @{ url = 'about-en.html';                 title = 'About us';              kind = 'Page' },
  @{ url = 'projects-en.html'; title = 'Our projects'; kind = 'Page' },
  # hidden for now: @{ url = 'service-en.html';               title = 'Service and technical support'; kind = 'Page' },
  @{ url = 'products/vrf-vrv-en.html';      title = 'VRF / VRV system';      kind = 'Category' },
  @{ url = 'products/samsung-en.html';      title = 'Samsung';               kind = 'Brand' },
  @{ url = 'products/mitsubishi-electric-en.html'; title = 'Mitsubishi Electric'; kind = 'Brand' },
  @{ url = 'products/boilers-en.html';      title = 'Boilers';               kind = 'Category' },
  @{ url = 'products/burners-en.html';      title = 'Burners';               kind = 'Category' },
  @{ url = 'products/water-heaters-en.html'; title = 'Water heaters';         kind = 'Category' },
  @{ url = 'products/ventilation-en.html';  title = 'Ventilation';           kind = 'Category' },
  @{ url = 'products/vortice-en.html';      title = 'Vortice';               kind = 'Brand' },
  @{ url = 'news/duct-production-en.html'; title = 'Biomi Holding has increased its ductwork production capacity'; kind = 'News' },
  @{ url = 'news/team-expansion-en.html'; title = 'Biomi Holding has expanded its engineering and design teams'; kind = 'News' }
)

# Project pages are read off disk rather than listed here. The hand-kept list
# had only ORO in it while PASHA Bank and Terminal Towers were live and
# unsearchable, so the pages themselves are now the source: the h1 gives the
# name, the subtitle beside it gives the descriptor, and the hero gives a
# thumbnail.
$rxH1     = [regex]'(?s)<h1>(.*?)(?:<span class="article__sub">(.*?)</span>)?</h1>'
$rxHero   = [regex]'(?s)<figure class="article__img">\s*<img src="([^"]+)"'
function Projects($en, $kind) {
  $out = @()
  $files = Get-ChildItem (Join-Path $root 'projects') -Filter '*.html' -File |
           Where-Object { $en -eq ($_.Name -match '-en\.html$') } | Sort-Object Name
  foreach ($f in $files) {
    $html = [IO.File]::ReadAllText($f.FullName)
    $m = $rxH1.Match($html)
    if (-not $m.Success) { Write-Host ("no h1: " + $f.Name); continue }
    $out += [pscustomobject]@{
      url   = 'projects/' + $f.Name
      title = Esc($m.Groups[1].Value)
      sub   = Esc($m.Groups[2].Value)
      kind  = $kind
      img   = ($rxHero.Match($html).Groups[1].Value -replace '^\.\./', '')
    }
  }
  return $out
}

# hub file -> brand label shown next to a product result
$hubsKa = @{ 'samsung.html' = 'Samsung'; 'mitsubishi-electric.html' = 'Mitsubishi Electric'; 'vortice.html' = 'Vortice'; 'beretta.html' = 'Beretta'; 'riello.html' = 'Riello'; 'riello-burners.html' = 'Riello'; 'warmhaus.html' = 'Warmhaus'; 'water-heaters.html' = '' }
$hubsEn = @{ 'samsung-en.html' = 'Samsung'; 'mitsubishi-electric-en.html' = 'Mitsubishi Electric'; 'vortice-en.html' = 'Vortice'; 'beretta-en.html' = 'Beretta'; 'riello-en.html' = 'Riello'; 'riello-burners-en.html' = 'Riello'; 'warmhaus-en.html' = 'Warmhaus'; 'water-heaters-en.html' = '' }

$rxCard = [regex]'(?s)<a class="pcard"\s+href="([^"]+)"[^>]*?data-name="([^"]*)"[^>]*>(.*?)</a>'
$rxImg  = [regex]'<img src="([^"]+)"'
$rxH4   = [regex]'(?s)<h4>(.*?)</h4>'
$rxSub  = [regex]'<span class="pcard__sub">([^<]*)</span>'
$rxBadge= [regex]'<span class="pcard__badge">([^<]*)</span>'

function Esc([string]$s) {
  if ($null -eq $s) { return '' }
  $s = $s -replace '<[^>]+>', ''            # strip any nested tags
  $s = $s -replace '&amp;', '&' -replace '&nbsp;', ' '
  return ($s -replace '\s+', ' ').Trim()
}

function Build($hubs, $static, $projects, $outFile) {
  $items = New-Object System.Collections.ArrayList
  foreach ($s in $static) {
    [void]$items.Add([pscustomobject]@{ url = $s.url; title = $s.title; sub = ''; kind = $s.kind; img = ''; q = ($s.title + ' ' + $s.kind).ToLower() })
  }
  foreach ($p in $projects) {
    [void]$items.Add([pscustomobject]@{ url = $p.url; title = $p.title; sub = $p.sub; kind = $p.kind; img = $p.img;
                                        q = ($p.title + ' ' + $p.sub + ' ' + $p.kind).ToLower() })
  }
  $seen = @{}
  # sorted: hashtable key order is not guaranteed stable between runs, and an
  # index that reshuffles itself would show up as a change on every publish
  foreach ($hubFile in ($hubs.Keys | Sort-Object)) {
    $path = Join-Path $root "products\$hubFile"
    if (-not (Test-Path $path)) { Write-Host "missing hub: $hubFile"; continue }
    $html = [IO.File]::ReadAllText($path)
    $brand = $hubs[$hubFile]
    # a listing page spans several brands, so an empty label means the brand
    # lives on the card itself
    $byCard = ($brand -eq '')
    foreach ($m in $rxCard.Matches($html)) {
      # hub links are relative to products/; some point back out of it
      $href = 'products/' + $m.Groups[1].Value -replace '^products/\.\./', ''
      if ($seen.ContainsKey($href)) { continue }
      $seen[$href] = $true
      $inner = $m.Groups[3].Value
      $title = Esc($rxH4.Match($inner).Groups[1].Value)
      $sub   = Esc($rxSub.Match($inner).Groups[1].Value)
      $badge = Esc($rxBadge.Match($inner).Groups[1].Value)
      $img   = $rxImg.Match($inner).Groups[1].Value -replace '^\.\./', ''
      if ($byCard) {
        $bm = [regex]::Match($m.Value,'data-brand="([^"]*)"')
        $brand = if ($bm.Success) { (Get-Culture).TextInfo.ToTitleCase($bm.Groups[1].Value) } else { '' }
      }
      $q     = (($m.Groups[2].Value + ' ' + $title + ' ' + $sub + ' ' + $brand + ' ' + $badge)).ToLower()
      [void]$items.Add([pscustomobject]@{ url = $href; title = $title; sub = $sub; kind = $brand; img = $img; q = $q })
    }
  }
  $json = $items | ConvertTo-Json -Depth 4 -Compress
  [IO.File]::WriteAllText((Join-Path $root $outFile), $json, $enc)
  Write-Host ("{0,-34} {1} entries" -f $outFile, $items.Count)
}

Build $hubsKa $staticKa (Projects $false 'პროექტი') 'assets/search-ka.json'
Build $hubsEn $staticEn (Projects $true  'Project')  'assets/search-en.json'
