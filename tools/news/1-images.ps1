# News heroes, galleries and inline figures.
#
# Two sources, per picture:
#
#  * Uploaded in the editor (/admin, Decap CMS). The original sits in
#    assets/img/uploads/ and is converted here into the article's own names:
#    the hero (news-<slug>.jpg, cropped to 16:9, with a full-size AVIF twin and
#    a 900px card copy), each captioned figure (news-<slug>-fig<n>.jpg + AVIF)
#    and the gallery (assets/img/<slug>-gallery/<slug>-<n>.avif). What was made
#    from what is kept in assets/img/uploads/_processed.json, so a picture is
#    converted again only when it is replaced - this runs on every save.
#
#  * The article folders under "Biomi Web NEWS" (the original workflow, on the
#    office computer only). "src" in the article names the folder:
#    "thumbnail.*" is the hero, "Main gallery" is the gallery strip, and
#    "DO NOT USE" is never read. A figure names its own source: a file in the
#    folder, or "docx:imageN", the Nth picture inside the Word file, where the
#    author placed it against its caption. Where the folder is missing - as it
#    is on GitHub's build machine - that article is left as it is.
#
# -UploadsOnly converts the editor's uploads and leaves every folder-built
# article alone (the GitHub build uses it; so does a test run here).
param([switch]$UploadsOnly)
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$SRC  = Join-Path $repo 'Biomi Web NEWS'
$IMG  = Join-Path $repo 'assets\img'
$MAGICK = 'magick'
. (Join-Path $sp 'load-news.ps1')

# The hero is a 16:9 card image; the gallery matches the project galleries.
$HERO_W = 1600; $HERO_H = 900; $GAL_W = 1600; $GAL_H = 1200; $GAL_Q = 48

$DATA = Get-NewsItems

$RECFILE = Join-Path $repo 'assets\img\uploads\_processed.json'
$REC = @{}
if (Test-Path $RECFILE) {
  $r = [IO.File]::ReadAllText($RECFILE) | ConvertFrom-Json
  foreach ($p in $r.PSObject.Properties) { $REC[$p.Name] = [string]$p.Value }
}
$sha = [Security.Cryptography.SHA1]::Create()
function Stamp([string[]]$files) {
  $all = New-Object System.Collections.Generic.List[byte]
  foreach ($f in $files) { $all.AddRange([Text.Encoding]::UTF8.GetBytes($f)); $all.AddRange([IO.File]::ReadAllBytes((Join-Path $repo $f))) }
  return ([BitConverter]::ToString($sha.ComputeHash($all.ToArray())) -replace '-', '').Substring(0, 16)
}

function MakeHero([string]$source, [string]$name) {
  $dst = Join-Path $IMG $name
  # cropped to 16:9 at the source's own width when it is smaller than the
  # target, rather than upscaled to it
  $w  = [int](& $MAGICK identify -format '%w' ($source + '[0]'))
  $tw = [Math]::Min($w, $HERO_W)
  $th = [int][Math]::Round($tw * $HERO_H / $HERO_W)
  & $MAGICK ($source + '[0]') -auto-orient -resize ($tw.ToString() + 'x' + $th + '^') `
            -gravity center -extent ($tw.ToString() + 'x' + $th) -quality 82 $dst
  # the news cards (homepage rail, "other news" strip) take a 900px AVIF copy;
  # build-news.ps1 uses it when it exists and the full hero when it does not
  & $MAGICK $dst -resize '900x>' -quality 55 ($dst -replace '\.jpe?g$', '-card.avif')
  # and a full-size AVIF twin for the article page itself: about a third of the JPEG
  & $MAGICK $dst -quality 55 ($dst -replace '\.jpe?g$', '.avif')
  return ('' + $tw + 'x' + $th)
}
function MakeFigure([string]$source, [string]$name) {
  $dst = Join-Path $IMG $name
  & $MAGICK ($source + '[0]') -auto-orient -resize '1400x1400>' -quality 82 $dst
  & $MAGICK $dst -quality 55 ($dst -replace '\.jpe?g$', '.avif')   # the twin build-news.ps1 uses
}
function MakeGallery([string]$slug, [string[]]$sources) {
  $gdir = Join-Path $IMG ($slug + '-gallery')
  New-Item -ItemType Directory -Force $gdir | Out-Null
  Get-ChildItem $gdir -File | Where-Object { $_.Extension -match '^\.(avif|webp|png|jpe?g)$' } | Remove-Item -Force
  $n = 0
  foreach ($s in $sources) {
    $n++
    & $MAGICK ($s + '[0]') -auto-orient -resize ($GAL_W.ToString() + 'x' + $GAL_H + '>') -quality $GAL_Q `
              (Join-Path $gdir ($slug + '-' + $n + '.avif'))
  }
  return $n
}

# "4-2.png" sorts between 4 and 5, and "10.png" after "9.png" -- plain string
# ordering gets both wrong, so sort on the leading number then the remainder.
function NaturalKey($name) {
  if ($name -match '^(\d+)(?:-(\d+))?') {
    return [double]$Matches[1] + ([double]($Matches[2] | ForEach-Object { if ($_) { $_ } else { 0 } }) / 100)
  }
  return [double]::MaxValue
}

foreach ($item in $DATA) {
  $heroNote = '-'; $galNote = '-'; $figNote = '-'

  # ---------------------------------------------------------------- uploads
  if ($item.heroUpload) {
    $st = Stamp @($item.heroUpload)
    if ($REC[$item.hero] -ne $st -or -not (Test-Path (Join-Path $IMG $item.hero))) {
      $heroNote = 'upload ' + (MakeHero (Join-Path $repo $item.heroUpload) $item.hero)
      $REC[$item.hero] = $st
    } else { $heroNote = 'upload (current)' }
  }
  foreach ($fig in $item.figures) {
    if (-not $fig.upload) { continue }
    $st = Stamp @($fig.upload)
    if ($REC[$fig.img] -ne $st -or -not (Test-Path (Join-Path $IMG $fig.img))) {
      MakeFigure (Join-Path $repo $fig.upload) $fig.img
      $REC[$fig.img] = $st
      $figNote = if ($figNote -eq '-') { $fig.img } else { $figNote + ', ' + $fig.img }
    }
  }
  if (@($item.gallery).Count) {
    $key = $item.slug + '-gallery'
    $st = Stamp @($item.gallery)
    if ($REC[$key] -ne $st) {
      $galNote = '' + (MakeGallery $item.slug @($item.gallery | ForEach-Object { Join-Path $repo $_ })) + ' uploaded images'
      $REC[$key] = $st
    } else { $galNote = 'upload (current)' }
  }

  # ------------------------------------------------ the office article folder
  if ($item.src -and -not $UploadsOnly) {
    $folder = Join-Path $SRC $item.src
    if (Test-Path -LiteralPath $folder) {
      if (-not $item.heroUpload) {
        $thumb = Get-ChildItem -LiteralPath $folder -File |
                 Where-Object { $_.BaseName -eq 'thumbnail' } | Select-Object -First 1
        if ($thumb) { $heroNote = 'folder ' + (MakeHero $thumb.FullName $item.hero) }
      }
      $main = Join-Path $folder 'Main gallery'
      if (-not @($item.gallery).Count -and (Test-Path -LiteralPath $main)) {
        $shots = @(Get-ChildItem -LiteralPath $main -File |
                   Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' } |
                   Sort-Object { NaturalKey $_.Name } | ForEach-Object { $_.FullName })
        $galNote = '' + (MakeGallery $item.slug $shots) + ' folder images'
      }
      foreach ($fig in $item.figures) {
        if ($fig.upload -or -not $fig.from) { continue }
        $raw = $null; $tmpRaw = $null
        if ($fig.from -like 'docx:*') {
          $want = $fig.from.Substring(5)
          $doc = Get-ChildItem -LiteralPath $folder -Filter '*.docx' -File | Select-Object -First 1
          if ($doc) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $tmpZip = Join-Path $env:TEMP ('news-' + $item.slug + '.zip')
            Copy-Item $doc.FullName $tmpZip -Force
            $zip = [IO.Compression.ZipFile]::OpenRead($tmpZip)
            $entry = $zip.Entries | Where-Object { $_.FullName -like ('word/media/' + $want + '.*') } | Select-Object -First 1
            if ($entry) {
              $tmpRaw = Join-Path $env:TEMP ('news-fig-' + $want + [IO.Path]::GetExtension($entry.FullName))
              [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tmpRaw, $true)
              $raw = $tmpRaw
            }
            $zip.Dispose(); Remove-Item $tmpZip -Force
          }
        } else {
          $file = Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.Name -eq $fig.from } | Select-Object -First 1
          if ($file) { $raw = $file.FullName }
        }
        if (-not $raw) { Write-Host ('  ! figure source missing: ' + $fig.from); continue }
        MakeFigure $raw $fig.img
        if ($tmpRaw) { Remove-Item $tmpRaw -Force }
        $figNote = if ($figNote -eq '-') { $fig.img } else { $figNote + ', ' + $fig.img }
      }
    }
  }
  Write-Host ('  {0,-18} hero {1,-22} gallery {2,-18} figures {3}' -f $item.slug, $heroNote, $galNote, $figNote)
}

if ($REC.Count) {
  New-Item -ItemType Directory -Force (Split-Path $RECFILE) | Out-Null
  $o = [ordered]@{}; foreach ($k in ($REC.Keys | Sort-Object)) { $o[$k] = $REC[$k] }
  [IO.File]::WriteAllText($RECFILE, ($o | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}
