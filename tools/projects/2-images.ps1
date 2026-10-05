# Project heroes, logos and galleries.
#
# Two sources, per picture, as for the news (tools/news/1-images.ps1):
#
#  * Uploaded in the editor (/admin, Decap CMS). The original sits in
#    assets/img/uploads/ and is converted here into the project's own names:
#    the hero (proj-<slug>.jpg, cropped to 16:9, with a full-size AVIF twin
#    and a 1400px card copy), the logo (clients/<slug>.svg as it is, or
#    clients/<slug>.png from any other picture) and the gallery
#    (assets/img/<slug>-gallery/<slug>-<n>.avif). What was made from what is
#    kept in assets/img/uploads/_processed.json, shared with the news, so a
#    picture is converted again only when it is replaced. Removing every
#    uploaded gallery photo removes the gallery.
#
#  * The project folders under "Projects files" (the original workflow, on the
#    office computer only). "src" in the project file names the folder:
#    "thumbnail.*" is the hero, "Main gallery" the gallery, and "DO NOT USE"
#    is never read. A picture is made again only when its source is newer than
#    what it made. Without the folder - as on GitHub's build machine - the
#    project's pictures are left as they are.
#
# -UploadsOnly converts the editor's uploads and leaves the folders alone (the
# GitHub build uses it).
param([switch]$UploadsOnly)
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$SRC  = Join-Path $repo 'Projects files'
$IMG  = Join-Path $repo 'assets\img'
$MAGICK = 'magick'
. (Join-Path $sp 'load-projects.ps1')

# The hero matches the other project heroes at 1600x900; the gallery the
# Terminal and PASHA sets at 1600px wide, which lands each shot around 45 KB.
#
# Since 2026-10-05 (the Tsre photos looked visibly smoothed at that setting):
# a gallery photo is 2400px at quality 75 - next to the original at 100% it
# keeps the concrete texture and the grilles' edges - and opens only in the
# lightbox (data-full); the strip under the hero shows a ~600px copy from
# <slug>-gallery/thumb/ (see build-projects.ps1). The hero's AVIF is made from
# the source at quality 72 instead of re-encoding the JPEG at 55.
$HERO_W = 1600; $HERO_H = 900; $HERO_Q = 72
$GAL_W = 2400; $GAL_H = 1800; $GAL_Q = 75; $THUMB_H = 280; $THUMB_Q = 60

$DATA = Get-ProjectItems

$RECFILE = Join-Path $repo 'assets\img\uploads\_processed.json'
$REC = @{}
if (Test-Path $RECFILE) {
  $r = [IO.File]::ReadAllText($RECFILE) | ConvertFrom-Json
  foreach ($q in $r.PSObject.Properties) { $REC[$q.Name] = [string]$q.Value }
}
$sha = [Security.Cryptography.SHA1]::Create()
function Stamp([string[]]$files) {
  $all = New-Object System.Collections.Generic.List[byte]
  foreach ($f in $files) { $all.AddRange([Text.Encoding]::UTF8.GetBytes($f)); $all.AddRange([IO.File]::ReadAllBytes((Join-Path $repo $f))) }
  return ([BitConverter]::ToString($sha.ComputeHash($all.ToArray())) -replace '-', '').Substring(0, 16)
}

function MakeHero([string]$source, [string]$name) {
  $dst = Join-Path $IMG $name
  # Every hero on the site is 16:9 - cropped to that at the source's own width
  # when it is smaller than the target, rather than upscaled: ORO's thumbnail
  # is a 1440x1920 portrait, and blowing it up adds pixels, not detail.
  $w  = [int](& $MAGICK identify -format '%w' ($source + '[0]'))
  $tw = [Math]::Min($w, $HERO_W)
  $th = [int][Math]::Round($tw * $HERO_H / $HERO_W)
  $crop = @('-auto-orient', '-resize', ($tw.ToString() + 'x' + $th + '^'), '-gravity', 'center', '-extent', ($tw.ToString() + 'x' + $th))
  & $MAGICK ($source + '[0]') @crop -quality 82 $dst
  # The homepage and projects.html show the hero as a card background: an AVIF
  # copy at 1400px, about a third of the JPEG. The JPEG stays for the lightbox.
  & $MAGICK ($source + '[0]') @crop -resize '1400x>' -quality 55 ($dst -replace '\.jpg$', '-card.avif')
  # full-size AVIF twin for the project page's own hero (build-projects.ps1),
  # made from the source rather than from the JPEG, so it is compressed once
  & $MAGICK ($source + '[0]') @crop -quality $HERO_Q ($dst -replace '\.jpg$', '.avif')
  return ('' + $tw + 'x' + $th)
}
function MakeLogo([string]$source, [string]$name) {
  $dst = Join-Path $IMG $name
  if ($name -like '*.svg') { Copy-Item -LiteralPath $source $dst -Force; return }
  # a chip shows the logo at most 42px tall; 300px keeps it sharp on any screen
  & $MAGICK ($source + '[0]') -auto-orient -trim +repage -resize '1200x300>' $dst
}
function MakeGallery([string]$slug, [string[]]$sources) {
  $gdir = Join-Path $IMG ($slug + '-gallery')
  New-Item -ItemType Directory -Force $gdir | Out-Null
  # Clear every image, not just the .avif this writes, so a photo taken out of
  # the set leaves the site rather than lingering as an orphan.
  Get-ChildItem $gdir -File | Where-Object { $_.Extension -match '^\.(avif|webp|png|jpe?g)$' } | Remove-Item -Force
  $tdir = Join-Path $gdir 'thumb'
  if (Test-Path $tdir) { Remove-Item -LiteralPath $tdir -Recurse -Force }
  New-Item -ItemType Directory -Force $tdir | Out-Null
  $n = 0
  foreach ($s in $sources) {
    $n++
    $full = Join-Path $gdir ($slug + '-' + $n + '.avif')
    # Fit inside 2400x1800 rather than capping the width alone, so a portrait
    # is not given three times a landscape shot's pixels. '>' only shrinks.
    & $MAGICK ($s + '[0]') -auto-orient -resize ($GAL_W.ToString() + 'x' + $GAL_H + '>') -quality $GAL_Q $full
    # the strip's copy: it shows 132x88 (cropped), so 280px tall covers 3x screens
    & $MAGICK ($s + '[0]') -auto-orient -resize ('x' + $THUMB_H + '>') -quality $THUMB_Q (Join-Path $tdir ($slug + '-' + $n + '.avif'))
  }
  return $n
}
function Fresh([string]$source, [string]$name) {
  $dst = Join-Path $IMG $name
  return ((Test-Path -LiteralPath $dst) -and (Get-Item -LiteralPath $dst).LastWriteTime -ge (Get-Item -LiteralPath $source).LastWriteTime)
}

# "4-2.png" sorts between 4 and 5, and "10.png" after "9.png" -- plain string
# ordering gets both wrong, so sort on the leading number then the remainder.
function NaturalKey($name) {
  if ($name -match '^(\d+)(?:-(\d+))?') {
    return [double]$Matches[1] + ([double]($Matches[2] | ForEach-Object { if ($_) { $_ } else { 0 } }) / 100)
  }
  return [double]::MaxValue
}

foreach ($p in $DATA) {
  $heroNote = '-'; $logoNote = '-'; $galNote = '-'
  $galKey = 'proj:' + $p.slug + '-gallery'

  # ---------------------------------------------------------------- uploads
  if ($p.heroUpload) {
    $st = Stamp @($p.heroUpload)
    if ($REC[$p.hero] -ne $st -or -not (Test-Path (Join-Path $IMG $p.hero))) {
      $heroNote = 'upload ' + (MakeHero (Join-Path $repo $p.heroUpload) $p.hero)
      $REC[$p.hero] = $st
    } else { $heroNote = 'upload (current)' }
  }
  if ($p.logoUpload) {
    $st = Stamp @($p.logoUpload)
    if ($REC[$p.logo] -ne $st -or -not (Test-Path (Join-Path $IMG $p.logo))) {
      MakeLogo (Join-Path $repo $p.logoUpload) $p.logo
      $REC[$p.logo] = $st; $logoNote = 'upload ' + $p.logo
    } else { $logoNote = 'upload (current)' }
  }
  if (@($p.gallery).Count) {
    $st = Stamp @($p.gallery)
    if ($REC[$galKey] -ne $st) {
      $galNote = '' + (MakeGallery $p.slug @($p.gallery | ForEach-Object { Join-Path $repo $_ })) + ' uploaded images'
      $REC[$galKey] = $st
    } else { $galNote = 'upload (current)' }
  } elseif ($REC.ContainsKey($galKey)) {
    # every uploaded photo was removed in the editor: so is the gallery
    $gdir = Join-Path $IMG ($p.slug + '-gallery')
    if (Test-Path $gdir) { Remove-Item -LiteralPath $gdir -Recurse -Force }
    $REC.Remove($galKey); $galNote = 'removed'
  }

  # ------------------------------------------------ the office project folder
  if ($p.src -and -not $UploadsOnly) {
    $folder = Join-Path $SRC $p.src
    if (Test-Path -LiteralPath $folder) {
      if (-not $p.heroUpload) {
        $thumb = Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.BaseName -eq 'thumbnail' } | Select-Object -First 1
        if ($thumb -and $p.hero -eq ('proj-' + $p.slug + '.jpg')) {
          if (Fresh $thumb.FullName $p.hero) { $heroNote = 'folder (current)' }
          else { $heroNote = 'folder ' + (MakeHero $thumb.FullName $p.hero) }
        }
      }
      $main = Join-Path $folder 'Main gallery'
      if (-not @($p.gallery).Count -and (Test-Path -LiteralPath $main)) {
        $shots = @(Get-ChildItem -LiteralPath $main -File |
                   Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' } | Sort-Object { NaturalKey $_.Name })
        $gdir = Join-Path $IMG ($p.slug + '-gallery')
        $made = @(Get-ChildItem $gdir -Filter '*.avif' -File -ErrorAction SilentlyContinue)
        $newestSrc = ($shots | Measure-Object LastWriteTime -Maximum).Maximum
        $oldestOut = ($made | Measure-Object LastWriteTime -Minimum).Minimum
        # Made again only when a photo in the folder is newer than the gallery,
        # not when the counts differ: Chateau's folder holds 10 photos and its
        # page has shown 7 since it was made (2026-09-03), which may well be a
        # choice - counting would quietly have added the other 3.
        if ($made.Count -and $oldestOut -ge $newestSrc) { $galNote = 'folder (current)' }
        else { $galNote = '' + (MakeGallery $p.slug @($shots | ForEach-Object { $_.FullName })) + ' folder images' }
      }
    } else { Write-Host ('  ! no folder for ' + $p.slug) }
  }
  Write-Host ('  {0,-10} hero {1,-22} logo {2,-22} gallery {3}' -f $p.slug, $heroNote, $logoNote, $galNote)
}

if ($REC.Count) {
  New-Item -ItemType Directory -Force (Split-Path $RECFILE) | Out-Null
  $o = [ordered]@{}; foreach ($k in ($REC.Keys | Sort-Object)) { $o[$k] = $REC[$k] }
  [IO.File]::WriteAllText($RECFILE, ($o | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}
