# The water-supply page: DAB and Wilo pumping stations.
#
# There is no model list behind this. What was supplied is one photograph per
# brand and a sentence saying Biomi installs both, so it is one page with the
# two installations side by side -- not a listing with a card and a product
# page each saying the same thing. When models arrive, they become a listing
# like the boilers and this page becomes its category.
#
# Every word is in water.json, Georgian included, so this file stays ASCII:
# PowerShell 5.1 reads a BOM-less script as ANSI and would mangle a Georgian
# literal, and the drop folder's name is one.
#
# Pictures: the shots are photographs of a plant room, not renders on white,
# so they are only resized -- AVIF like the product pages -- and one of them is
# cropped to the catalogue card's 4:3 as a JPEG (products-page.ps1 draws a
# photo there, covering the card, where it finds no cut-out). Only missing
# files are written; -Force redoes them.
#
# The same page serves underfloor heating (2026-09-21): one photograph of a
# TIEMME installation and the supplied sentence, so it is the same shape with
# one card instead of two. Its words are in underfloor-heating.json, and -Data
# picks the file. Two fields there that water.json leaves at their defaults:
# "chapter", the catalogue chapter its card photo is filed under (water), and
# "imgdir", the folder under assets/img its photographs go to (water). Its
# catalogue card shows a cut-out of the manifold rather than this photo - see
# tools/cutout.ps1 - so the card photo written here is only a fallback.
#
# Run:  powershell -ExecutionPolicy Bypass -File tools\water\build-water.ps1
#       powershell -ExecutionPolicy Bypass -File tools\water\build-water.ps1 -Data underfloor-heating.json
param([string]$Data = 'water.json', [switch]$Force)
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$UTF8 = New-Object Text.UTF8Encoding($true)
$CRLF = [string][char]13 + [char]10

$D = Get-Content (Join-Path $sp $Data) -Raw -Encoding UTF8 | ConvertFrom-Json
$CHAPTER = if ($D.chapter) { [string]$D.chapter } else { 'water' }
$IMG     = if ($D.imgdir)  { [string]$D.imgdir }  else { 'water' }

function Esc([string]$s) { ($s -replace '&(?!(amp|lt|gt|quot|#\d+);)','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;') }

# ---- pictures
$IMGDIR   = Join-Path $repo ('assets\img\' + $IMG)
$PHOTODIR = Join-Path $repo 'assets\img\cat-photo'
# $dir, not $d: names are case-insensitive, and $d would be $D, the data
foreach ($dir in $IMGDIR, $PHOTODIR) { if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null } }
$SIZE = @{}
foreach ($it in $D.items) {
  $src = Join-Path $D.drop $it.src
  $dst = Join-Path $IMGDIR ($it.slug + '.avif')
  if (-not (Test-Path -LiteralPath $src)) { throw ('source not found: ' + $src) }
  if ($Force -or -not (Test-Path $dst)) {
    & magick $src -resize '1600x>' -quality 55 $dst
    Write-Host ('  ' + ($IMG + '\' + $it.slug + '.avif').PadRight(30) + [math]::Round((Get-Item $dst).Length / 1kb) + ' KB')
  }
  $wh = (& magick identify -format '%w %h' $dst) -split ' '
  $SIZE[$it.slug] = $wh
  # With more than one installation the catalogue shows a card for each
  # (menu-tree.json "split"), cut the same way as the chapter card below.
  if (@($D.items).Count -gt 1) {
    $own = Join-Path $PHOTODIR ($CHAPTER + '-' + $it.slug + '.jpg')
    if ($Force -or -not (Test-Path $own)) {
      & magick $src -resize '640x480^' -gravity center -extent 640x480 -quality 80 $own
      Write-Host ('  ' + ('cat-photo\' + $CHAPTER + '-' + $it.slug + '.jpg').PadRight(30) + [math]::Round((Get-Item $own).Length / 1kb) + ' KB')
    }
  }
}
# The catalogue card: the first station, cut to the card's shape.
$card = Join-Path $PHOTODIR ($CHAPTER + '-' + $D.slug + '.jpg')
if ($Force -or -not (Test-Path $card)) {
  & magick (Join-Path $D.drop $D.items[0].src) -resize '640x480^' -gravity center -extent 640x480 -quality 80 $card
  Write-Host ('  ' + ('cat-photo\' + $CHAPTER + '-' + $D.slug + '.jpg').PadRight(30) + [math]::Round((Get-Item $card).Length / 1kb) + ' KB')
}

# ---- the page furniture, off a product page that already carries it -- same
# approach as tools/ducting/build-ducting.ps1, with the donor's meta block,
# title, description and language switch replaced
function Shell([string]$sfx, [string]$title, [string]$desc) {
  $donor = 'ventilation' + $sfx
  $tpl = [IO.File]::ReadAllText((Join-Path $repo ('products\' + $donor)))
  $i = $tpl.IndexOf('<section class="page-hero')
  $j = $tpl.IndexOf('<!-- ===================== FOOTER')
  if ($i -lt 0 -or $j -lt 0) { throw ('markers not found in ' + $donor) }
  $head = $tpl.Substring(0, $i); $tail = $tpl.Substring($j)
  $head = [regex]::Replace($head, '(?s)<!-- meta:start.*?<!-- meta:end[^>]*-->\s*', '')
  $head = [regex]::Replace($head, '(?s)<title>.*?</title>', ('<title>' + $title + '</title>'))
  $head = [regex]::Replace($head, '<meta name="description" content="[^"]*"',
                           ('<meta name="description" content="' + (Esc $desc) + '"'))
  foreach ($pair in @(@('href="ventilation.html">GEO<',    ('href="' + $D.slug + '.html">GEO<')),
                      @('href="ventilation-en.html">ENG<', ('href="' + $D.slug + '-en.html">ENG<')))) {
    $head = $head.Replace($pair[0], $pair[1]); $tail = $tail.Replace($pair[0], $pair[1])
  }
  return @($head, $tail)
}

$ARROW = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'

foreach ($lang in 'ka','en') {
  $t = $D.$lang
  $sfx = if ($lang -eq 'ka') { '.html' } else { '-en.html' }
  $shell = Shell $sfx $t.title $t.desc

  $rows = New-Object System.Collections.Generic.List[string]
  foreach ($it in $D.items) {
    $sub = $it.$lang.sub
    $wh = $SIZE[$it.slug]
    # not $host: that is PowerShell's own read-only automatic variable
    $siteHost = ([uri]$it.url).Host -replace '^www\.',''
    # id="dab", id="wilo": somewhere to point a link at one of the two
    $rows.Add('      <figure class="pstation" id="' + $it.slug + '">')
    # data-lightbox: the photograph is the whole card, and the arrows step to
    # the other station from there
    # "focus" moves the 16:9 crop off centre: the TIEMME shot is a manifold
    # cabinet over pipe loops, and centred the crop cut the manifold's top row
    # off. The lightbox still opens the whole photograph.
    $pos = if ($it.focus) { ' style="object-position:' + $it.focus + '"' } else { '' }
    $rows.Add('        <span class="pstation__shot"><img src="../assets/img/' + $IMG + '/' + $it.slug + '.avif" alt="' +
              (Esc ($it.brand + ' - ' + $sub)) + '" width="' + $wh[0] + '" height="' + $wh[1] + '"' + $pos + ' loading="lazy" data-lightbox></span>')
    $rows.Add('        <figcaption>')
    $rows.Add('          <img class="pstation__logo" src="../assets/img/partners/' + $it.logo + '" alt="' + (Esc $it.brand) + '">')
    $rows.Add('          <span class="pstation__txt"><b>' + (Esc $it.brand) + '</b><small>' + (Esc $sub) + '</small></span>')
    $rows.Add('          <a class="pstation__site" href="' + $it.url + '" target="_blank" rel="noopener" title="' + (Esc $t.site) + '">' + $siteHost + '</a>')
    $rows.Add('        </figcaption>')
    $rows.Add('      </figure>')
  }

  $body = @'
<section class="page-hero page-hero--brand">
  <div class="container">
    <nav class="crumbs" aria-label="breadcrumb">
      <a href="../index{SFX}">{HOME}</a><span class="sep">/</span>
      <a href="../products{SFX}">{PROD}</a><span class="sep">/</span>
      <b>{CRUMB}</b>
    </nav>
    <div class="section__head" style="margin-bottom:0">
      <span class="eyebrow">{EYEBROW}</span>
      <h1>{H2}</h1>
      <p class="page-lede">{LEDE}</p>
    </div>
  </div>
</section>

<section class="section" style="padding-top:26px">
  <div class="container">
    <div class="pstations">
{ROWS}
    </div>

    <p class="duct__note">{NOTE}
      <a class="btn btn--outline" href="../index{SFX}#contact">{CTA}
        {ARROW}</a></p>
  </div>
</section>

'@
  $body = $body.Replace('{SFX}', $sfx).Replace('{HOME}', $t.home).Replace('{PROD}', $t.prod).
                Replace('{CRUMB}', $t.crumb).Replace('{EYEBROW}', $t.eyebrow).Replace('{H2}', $t.h2).
                Replace('{LEDE}', (Esc $t.lede)).Replace('{NOTE}', $t.note).Replace('{CTA}', $t.cta).
                Replace('{ARROW}', $ARROW).Replace('{ROWS}', ($rows -join $CRLF))
  $out = $shell[0] + $body + $shell[1]
  $out = [regex]::Replace($out, "`r`n|`n", $CRLF)
  $file = 'products\' + $D.slug + $sfx
  [IO.File]::WriteAllText((Join-Path $repo $file), $out, $UTF8)
  Write-Host ('  wrote ' + $file + ' : ' + $D.items.Count + ' stations')
}
