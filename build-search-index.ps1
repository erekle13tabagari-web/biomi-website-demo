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
  @{ url = 'products/vrf-vrv.html';         title = 'VRF / VRV სისტემა';     kind = 'კატეგორია' },
  @{ url = 'products/samsung.html';         title = 'Samsung';               kind = 'ბრენდი' },
  @{ url = 'products/mitsubishi-electric.html'; title = 'Mitsubishi Electric'; kind = 'ბრენდი' },
  @{ url = 'news/vrf-project.html';         title = 'VRF სისტემის დანერგვა მრავალფუნქციურ ცენტრში'; kind = 'სიახლე' },
  @{ url = 'projects/oro.html';             title = 'ORO — კომერციული კომპლექსის კლიმატიზაცია';     kind = 'პროექტი' }
)
$staticEn = @(
  @{ url = 'index-en.html';                 title = 'Home';                  kind = 'Page' },
  @{ url = 'about-en.html';                 title = 'About us';              kind = 'Page' },
  @{ url = 'products/vrf-vrv-en.html';      title = 'VRF / VRV system';      kind = 'Category' },
  @{ url = 'products/samsung-en.html';      title = 'Samsung';               kind = 'Brand' },
  @{ url = 'products/mitsubishi-electric-en.html'; title = 'Mitsubishi Electric'; kind = 'Brand' },
  @{ url = 'news/vrf-project-en.html';      title = 'VRF system rollout in a multi-purpose centre'; kind = 'News' },
  @{ url = 'projects/oro-en.html';          title = 'ORO — climate control for a commercial complex'; kind = 'Project' }
)

# hub file -> brand label shown next to a product result
$hubsKa = @{ 'samsung.html' = 'Samsung'; 'mitsubishi-electric.html' = 'Mitsubishi Electric' }
$hubsEn = @{ 'samsung-en.html' = 'Samsung'; 'mitsubishi-electric-en.html' = 'Mitsubishi Electric' }

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

function Build($hubs, $static, $outFile) {
  $items = New-Object System.Collections.ArrayList
  foreach ($s in $static) {
    [void]$items.Add([pscustomobject]@{ url = $s.url; title = $s.title; sub = ''; kind = $s.kind; img = ''; q = ($s.title + ' ' + $s.kind).ToLower() })
  }
  $seen = @{}
  foreach ($hubFile in $hubs.Keys) {
    $path = Join-Path $root "products\$hubFile"
    if (-not (Test-Path $path)) { Write-Host "missing hub: $hubFile"; continue }
    $html = [IO.File]::ReadAllText($path)
    $brand = $hubs[$hubFile]
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
      $q     = (($m.Groups[2].Value + ' ' + $title + ' ' + $sub + ' ' + $brand + ' ' + $badge)).ToLower()
      [void]$items.Add([pscustomobject]@{ url = $href; title = $title; sub = $sub; kind = $brand; img = $img; q = $q })
    }
  }
  $json = $items | ConvertTo-Json -Depth 4 -Compress
  [IO.File]::WriteAllText((Join-Path $root $outFile), $json, $enc)
  Write-Host ("{0,-34} {1} entries" -f $outFile, $items.Count)
}

Build $hubsKa $staticKa 'assets/search-ka.json'
Build $hubsEn $staticEn 'assets/search-en.json'
