# Social, canonical and structured-data tags for every page, plus sitemap.xml
# and robots.txt.
#
# Before this the site had none of it: pasting a product link into Messenger or
# WhatsApp -- the way a distributor's links actually travel -- produced a bare
# URL with no title, image or description, and nothing told search engines that
# the Georgian and English pages are translations of one another.
#
# Re-runnable: the block is fenced by markers and replaced wholesale, so this
# can be run again after any page changes.
$repo = Split-Path $PSScriptRoot -Parent
$BASE = 'https://biomi.ge'   # live on ProService since 2026-09-18; was https://erekle13tabagari-web.github.io/biomi-website-demo
$OGDIR = Join-Path $repo 'assets\img\og'
New-Item -ItemType Directory -Force -Path $OGDIR | Out-Null

$ORG = @{
  ka = @{ name='ბიომი ჰოლდინგი'; addr='აკაკი ბელიაშვილის 124'; city='თბილისი' }
  en = @{ name='Biomi Holding';  addr='Akaki Beliashvili 124'; city='Tbilisi' }
}
$SAMEAS = @(
  'https://www.facebook.com/p/Biomi-Holding-ბიომი-ჰოლდინგი-61579642613208/',
  # Percent-encoded, and www rather than the ge. locale host: the short
  # "biomi-holding" slug 404s, and sameAs is what Google reads to tie the
  # company's profiles together -- a dead URL in here is worse than no URL.
  'https://www.linkedin.com/company/biomi-holding-%E2%80%A2-%E1%83%91%E1%83%98%E1%83%9D%E1%83%9B%E1%83%98-%E1%83%B0%E1%83%9D%E1%83%9A%E1%83%93%E1%83%98%E1%83%9C%E1%83%92%E1%83%98',
  'https://www.instagram.com/biomi.holding/',
  # The handle, matching the button in the floating stack rather than adding a
  # second address for one channel. Its permanent id, should the handle ever be
  # renamed, is UCujeFl7hb813mSmb5JG4KtQ.
  'https://www.youtube.com/@BiomiHolding'
)

function Esc($s) { if ($null -eq $s) { return '' }; ($s -replace '&(?!(amp|lt|gt|quot|#\d+);)','&amp;' -replace '"','&quot;') }
function J($s)   { if ($null -eq $s) { return '' }; ($s -replace '\\','\\' -replace '"','\"' -replace '\s+',' ').Trim() }
# The Georgian homepage's address is the domain itself: https://biomi.ge/ is
# what people type and link, so it is the one search engines are told about.
function PageUrl($rel) { if ($rel -eq 'index.html') { return "$BASE/" }; return "$BASE/$rel" }

$files = Get-ChildItem $repo -Filter '*.html' -Recurse -File |
         Where-Object { $_.Name -ne 'Launch Biomi Website.html' -and $_.FullName -notmatch '\\(backup|_files|\.git|\.claude|tools|admin)' } |
         Sort-Object FullName

# ---------------------------------------------------------------- OG images
# Social scrapers do not render AVIF, so every card image is baked to JPEG at
# the 1.91:1 ratio Facebook and LinkedIn crop to.
$ogFor = @{}
$made = @{}
# Each share image is rebuilt only when its source picture changes, judged by
# the source's MD5 in og-sources.json. Rebuilding all of them every run was
# harmless here, where ImageMagick gives the same bytes each time, but GitHub's
# news build encodes them slightly differently and committed ~70 changed JPGs
# per editor save (2026-09-24). An image already present with no recorded
# fingerprint is trusted as current and fingerprinted, not rebuilt.
$ogIdxPath = Join-Path $PSScriptRoot 'og-sources.json'
$ogIdx = @{}
if (Test-Path $ogIdxPath) {
  (Get-Content $ogIdxPath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ogIdx[$_.Name] = $_.Value }
}
function OgStale([string]$key, [string]$src, [string]$out) {
  $h = (Get-FileHash -LiteralPath $src -Algorithm MD5).Hash
  $stale = -not (Test-Path -LiteralPath $out) -or ($ogIdx.ContainsKey($key) -and $ogIdx[$key] -ne $h)
  $script:ogIdx[$key] = $h
  return $stale
}
foreach ($f in $files) {
  $txt = [IO.File]::ReadAllText($f.FullName)
  $m = [regex]::Match($txt, '(?s)<div class="pgal__main">.*?<img src="([^"]+)"')
  if (-not $m.Success) { $ogFor[$f.FullName] = 'default'; continue }
  $rel = $m.Groups[1].Value -replace '^\.\./',''
  $src = Join-Path $repo ($rel -replace '/','\')
  if (-not (Test-Path -LiteralPath $src)) { $ogFor[$f.FullName] = 'default'; continue }
  $key = (Split-Path (Split-Path $src -Parent) -Leaf) + '-' + [IO.Path]::GetFileNameWithoutExtension($src)
  $ogFor[$f.FullName] = $key
  if (-not $made.ContainsKey($key)) {
    $made[$key] = $true
    $ogOut = Join-Path $OGDIR ($key + '.jpg')
    if (OgStale $key $src $ogOut) {
      & magick $src -resize 1000x520 -background white -alpha remove -alpha off `
               -gravity center -extent 1200x630 -quality 82 $ogOut
    }
  }
}
$def = Join-Path $OGDIR 'default.jpg'
$defSrc = Join-Path $repo 'assets\img\about-us.webp'
if ((Test-Path $defSrc) -and (OgStale 'default' $defSrc $def)) { & magick $defSrc -resize 1200x630^ -gravity center -extent 1200x630 -quality 82 $def }
$ogSorted = [ordered]@{}; foreach ($k in ($ogIdx.Keys | Sort-Object)) { $ogSorted[$k] = $ogIdx[$k] }
[IO.File]::WriteAllText($ogIdxPath, ($ogSorted | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))

# ------------------------------------------------------------------- pages
# Pages that still exist and still work on their own URL, but are not offered
# anywhere: nothing links to them, they carry robots noindex, and they are kept
# out of sitemap.xml. Take a name out of this list to publish it again.
$HIDDEN = 'service.html', 'service-en.html'
# The "page not found" pages: noindex and out of the sitemap like the hidden
# ones, but kept apart from $HIDDEN because deploy-site.ps1 reads that line and
# skips uploading those pages, and the server needs these two to exist.
$ERRORPAGES = '404.html', '404-en.html'
# Uploaded and reachable, but not for search: the holding page a menu entry
# without a listing points at. Nothing links to it now that underfloor heating
# has a page, and a "coming soon" page in the index is thin content (SEO
# audit, 2026-09-21). Not in $HIDDEN, which would stop it being uploaded.
$NOINDEX = 'soon.html', 'soon-en.html'
. (Join-Path $PSScriptRoot 'boilers\visible.ps1')   # IsPreviewSlug

$urls = New-Object System.Collections.ArrayList
foreach ($f in $files) {
  $txt = [IO.File]::ReadAllText($f.FullName)
  $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\','/'
  $en  = $f.Name -like '*-en.html'
  $lang = if ($en) { 'en' } else { 'ka' }
  $kaRel = if ($en) { $rel -replace '-en\.html$','.html' } else { $rel }
  $enRel = if ($en) { $rel } else { $rel -replace '\.html$','-en.html' }
  $hasPair = Test-Path (Join-Path $repo (($(if ($en) { $kaRel } else { $enRel })) -replace '/','\'))

  $title = ([regex]::Match($txt,'(?s)<title>(.*?)</title>')).Groups[1].Value.Trim()
  $desc  = ([regex]::Match($txt,'<meta name="description" content="([^"]*)"')).Groups[1].Value.Trim()
  $og    = $ogFor[$f.FullName]; if (-not (Test-Path (Join-Path $OGDIR ($og + '.jpg')))) { $og = 'default' }
  $canon = PageUrl $rel

  $b = New-Object System.Text.StringBuilder
  [void]$b.AppendLine('<!-- meta:start (generated by tools/build-meta.ps1 - do not edit by hand) -->')
  [void]$b.AppendLine('<link rel="canonical" href="' + $canon + '">')
  # Not $hidden: PowerShell variable names are case-insensitive, so assigning
  # to that would overwrite $HIDDEN with a boolean on the first page and every
  # test after it would be false.
  # a preview brand's pages (boilers/visible.ps1) exist on the test site only,
  # so they must not be in the sitemap the live site serves
  $isHidden = ($HIDDEN -contains $f.Name) -or ($ERRORPAGES -contains $f.Name) -or ($NOINDEX -contains $f.Name) -or
              ($rel -like 'products/*' -and (IsPreviewSlug $f.BaseName))
  if ($isHidden) { [void]$b.AppendLine('<meta name="robots" content="noindex,nofollow">') }
  if ($hasPair) {
    [void]$b.AppendLine('<link rel="alternate" hreflang="ka" href="' + (PageUrl $kaRel) + '">')
    [void]$b.AppendLine('<link rel="alternate" hreflang="en" href="' + (PageUrl $enRel) + '">')
    [void]$b.AppendLine('<link rel="alternate" hreflang="x-default" href="' + (PageUrl $kaRel) + '">')
  }
  [void]$b.AppendLine('<meta property="og:type" content="website">')
  [void]$b.AppendLine('<meta property="og:site_name" content="' + (Esc $ORG[$lang].name) + '">')
  [void]$b.AppendLine('<meta property="og:locale" content="' + $(if ($en) { 'en_US' } else { 'ka_GE' }) + '">')
  [void]$b.AppendLine('<meta property="og:title" content="' + (Esc $title) + '">')
  [void]$b.AppendLine('<meta property="og:description" content="' + (Esc $desc) + '">')
  [void]$b.AppendLine('<meta property="og:url" content="' + $canon + '">')
  [void]$b.AppendLine('<meta property="og:image" content="' + "$BASE/assets/img/og/$og.jpg" + '">')
  [void]$b.AppendLine('<meta property="og:image:width" content="1200">')
  [void]$b.AppendLine('<meta property="og:image:height" content="630">')
  [void]$b.AppendLine('<meta name="twitter:card" content="summary_large_image">')
  [void]$b.AppendLine('<meta name="twitter:title" content="' + (Esc $title) + '">')
  [void]$b.AppendLine('<meta name="twitter:description" content="' + (Esc $desc) + '">')
  [void]$b.AppendLine('<meta name="twitter:image" content="' + "$BASE/assets/img/og/$og.jpg" + '">')

  # ---- structured data
  # a datasheet as a table, or as the grid of cells the Emtaş pages use
  $isProduct = $txt -match 'class="(spec-table|spec-grid)' -and $txt -match 'class="pgal__main"'
  if ($isProduct) {
    # Every make the catalogue carries. Beretta, Riello, Warmhaus and Omega were
    # missing, so their 30-odd product pages told Google the maker was Biomi.
    $brand = switch -Regex ($f.Name) {
      '^samsung'    { 'Samsung' }
      '^mitsubishi' { 'Mitsubishi Electric' }
      '^vortice'    { 'Vortice' }
      '^beretta'    { 'Beretta' }
      '^riello'     { 'Riello' }
      '^warmhaus'   { 'Warmhaus' }
      '^omega'      { 'Omega' }
      '^emtas'      { 'Emta' + [char]0x15F }   # "Emtaş"
      default       { $ORG[$lang].name }
    }
    $h1 = ([regex]::Match($txt,'(?s)<h1>(.*?)</h1>')).Groups[1].Value -replace '<[^>]+>',''
    [void]$b.AppendLine('<script type="application/ld+json">{"@context":"https://schema.org","@type":"Product",' +
      '"name":"' + (J $h1) + '","description":"' + (J $desc) + '",' +
      '"image":"' + "$BASE/assets/img/og/$og.jpg" + '",' +
      '"brand":{"@type":"Brand","name":"' + (J $brand) + '"},' +
      '"url":"' + $canon + '"}</script>')
  }
  if ($f.Name -like 'index*') {
    # Who Biomi is, for search engines (reworked 2026-09-19). The old WordPress
    # site asked search engines not to index it (blog_public = 0), so the domain
    # arrived with no history and a brand search showed only the Facebook page.
    # - one entity for both languages: the same @id and the domain root as url
    # - HVACBusiness (a schema.org LocalBusiness) with the office's map point
    # - every spelling people search by: Biomi / Biomi Holding / ბიომი / ბიომი ჰოლდინგი
    # - a WebSite record, which is where Google takes the site name shown in results
    $o = $ORG[$lang]
    $alt = @('Biomi', 'Biomi Holding', 'ბიომი', 'ბიომი ჰოლდინგი') | Where-Object { $_ -ne $o.name }
    $altJ = ($alt | ForEach-Object { '"' + (J $_) + '"' }) -join ','
    [void]$b.AppendLine('<script type="application/ld+json">{"@context":"https://schema.org","@type":"HVACBusiness",' +
      '"@id":"' + $BASE + '/#organization",' +
      '"name":"' + (J $o.name) + '","alternateName":[' + $altJ + '],"url":"' + $BASE + '/",' +
      '"logo":"' + $BASE + '/assets/img/logo-geo.svg",' +
      '"image":"' + $BASE + '/assets/img/og/default.jpg",' +
      '"telephone":"+995322151115","email":"info@biomi.ge",' +
      '"address":{"@type":"PostalAddress","streetAddress":"' + (J $o.addr) + '","addressLocality":"' + (J $o.city) + '","postalCode":"0159","addressCountry":"GE"},' +
      '"geo":{"@type":"GeoCoordinates","latitude":41.7831796,"longitude":44.7816816},' +
      '"areaServed":{"@type":"Country","name":"Georgia"},' +
      '"sameAs":[' + (($SAMEAS | ForEach-Object { '"' + (J $_) + '"' }) -join ',') + ']}</script>')
    [void]$b.AppendLine('<script type="application/ld+json">{"@context":"https://schema.org","@type":"WebSite",' +
      '"@id":"' + $BASE + '/#website","url":"' + $BASE + '/","name":"Biomi",' +
      '"alternateName":["ბიომი","Biomi Holding","ბიომი ჰოლდინგი"],"inLanguage":"' + $lang + '",' +
      '"publisher":{"@id":"' + $BASE + '/#organization"}}</script>')
  }

  # Breadcrumbs (SEO audit, 2026-09-21): read off the trail the page already
  # shows, so the two cannot disagree. Filter queries are dropped - they are not
  # pages of their own (the listing's canonical has none) - and a crumb that
  # then repeats the one before it goes, as "VRF / Samsung" does on a product.
  # Google shows the trail in place of the bare URL under a result.
  $trail = [regex]::Match($txt, '(?s)<nav class="crumbs"[^>]*>(.*?)</nav>')
  if ($trail.Success -and -not $isHidden) {
    $crumbs = New-Object System.Collections.ArrayList
    $last = ''
    foreach ($m in [regex]::Matches($trail.Groups[1].Value, '(?s)<a href="([^"]+)"[^>]*>(.*?)</a>|<b>(.*?)</b>')) {
      if ($m.Groups[1].Success) {
        $href = $m.Groups[1].Value -replace '[?#].*$', ''
        $url = (New-Object Uri((New-Object Uri("$BASE/$rel")), $href)).AbsoluteUri -replace '(?<=biomi\.ge)/index\.html$', '/'
        $name = $m.Groups[2].Value
      } else {
        $url = $canon; $name = $m.Groups[3].Value
      }
      $name = [Net.WebUtility]::HtmlDecode(($name -replace '<[^>]+>', ''))
      if ($url -eq $last -or -not $name.Trim()) { continue }
      [void]$crumbs.Add('{"@type":"ListItem","position":' + ($crumbs.Count + 1) + ',"name":"' + (J $name) + '","item":"' + $url + '"}')
      $last = $url
    }
    if ($crumbs.Count -ge 2) {
      [void]$b.AppendLine('<script type="application/ld+json">{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[' +
        ($crumbs -join ',') + ']}</script>')
    }
  }

  # News posts as articles: headline, date and picture, published by Biomi.
  if ($rel -like 'news/*' -and -not $isHidden) {
    $head1 = [Net.WebUtility]::HtmlDecode((([regex]::Match($txt, '(?s)<h1[^>]*>(.*?)</h1>')).Groups[1].Value -replace '<[^>]+>', ''))
    $date = ([regex]::Match($txt, '<time[^>]*datetime="([^"]+)"')).Groups[1].Value
    if ($head1 -and $date) {
      [void]$b.AppendLine('<script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle",' +
        '"headline":"' + (J $head1) + '","datePublished":"' + $date + '","inLanguage":"' + $lang + '",' +
        '"image":["' + "$BASE/assets/img/og/$og.jpg" + '"],"mainEntityOfPage":"' + $canon + '",' +
        '"author":{"@type":"Organization","name":"' + (J $ORG[$lang].name) + '","url":"' + $BASE + '/"},' +
        '"publisher":{"@type":"Organization","name":"' + (J $ORG[$lang].name) + '","url":"' + $BASE + '/",' +
        '"logo":{"@type":"ImageObject","url":"' + $BASE + '/apple-touch-icon.png"}}}</script>')
    }
  }
  [void]$b.AppendLine('<!-- meta:end -->')

  # replace any previous block, then insert before </head>
  $txt = [regex]::Replace($txt, '(?s)[ \t]*<!-- meta:start.*?<!-- meta:end -->\r?\n', '')
  $txt = $txt -replace '(?=</head>)', $b.ToString()
  # With the BOM: every HTML file in the repo carries one, and writing these
  # without it rewrote all 176 pages for nothing every time this ran.
  # sitemap.xml and robots.txt below stay BOM-less, which is correct for them.
  [IO.File]::WriteAllText($f.FullName, $txt, (New-Object Text.UTF8Encoding($true)))
  if (-not $isHidden) { [void]$urls.Add(@{ loc = $canon; ka = (PageUrl $kaRel); en = (PageUrl $enRel); pair = $hasPair }) }
}

# ----------------------------------------------------------------- sitemap
$today = (Get-Item (Join-Path $repo 'index.html')).LastWriteTime.ToString('yyyy-MM-dd')
$sm = New-Object System.Text.StringBuilder
[void]$sm.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sm.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">')
foreach ($u in $urls) {
  [void]$sm.AppendLine('  <url>')
  [void]$sm.AppendLine('    <loc>' + $u.loc + '</loc>')
  if ($u.pair) {
    [void]$sm.AppendLine('    <xhtml:link rel="alternate" hreflang="ka" href="' + $u.ka + '"/>')
    [void]$sm.AppendLine('    <xhtml:link rel="alternate" hreflang="en" href="' + $u.en + '"/>')
  }
  [void]$sm.AppendLine('    <lastmod>' + $today + '</lastmod>')
  [void]$sm.AppendLine('  </url>')
}
[void]$sm.AppendLine('</urlset>')
[IO.File]::WriteAllText((Join-Path $repo 'sitemap.xml'), $sm.ToString(), (New-Object Text.UTF8Encoding($false)))

[IO.File]::WriteAllText((Join-Path $repo 'robots.txt'),
  "User-agent: *`nAllow: /`n`nSitemap: $BASE/sitemap.xml`n", (New-Object Text.UTF8Encoding($false)))

Write-Host ("pages tagged   : " + $files.Count)
Write-Host ("og images      : " + (Get-ChildItem $OGDIR -Filter '*.jpg').Count)
Write-Host ("sitemap urls   : " + $urls.Count)
Write-Host ("product schema : " + @($files | Where-Object { [IO.File]::ReadAllText($_.FullName) -match '"@type":"Product"' }).Count)
