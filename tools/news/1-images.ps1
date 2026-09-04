# News heroes, galleries and inline figures, from the article folders.
#
# Reads "src" out of news.json -- the folder name under "Biomi Web NEWS" -- and
# rebuilds that article's images from it. Same convention as the project folders:
# "thumbnail.*" is the hero, "Main gallery" is the gallery strip, and "DO NOT USE"
# is never read.
#
# The inline figure is the exception: it is a specific photo the author paired
# with a specific caption, so it is named in news.json rather than picked up by
# position, and it comes from the .docx itself -- see the note by $FIGSRC.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$SRC  = Join-Path $repo 'Biomi Web NEWS'
$IMG  = Join-Path $repo 'assets\img'
$MAGICK = 'magick'

# The hero is a 16:9 card image; the gallery matches the project galleries.
$HERO_W = 1600; $HERO_H = 900; $GAL_W = 1600; $GAL_H = 1200; $GAL_Q = 48

$DATA = Get-Content (Join-Path $sp 'news.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# "4-2.png" sorts between 4 and 5, and "10.png" after "9.png" -- plain string
# ordering gets both wrong, so sort on the leading number then the remainder.
function NaturalKey($name) {
  if ($name -match '^(\d+)(?:-(\d+))?') {
    return [double]$Matches[1] + ([double]($Matches[2] | ForEach-Object { if ($_) { $_ } else { 0 } }) / 100)
  }
  return [double]::MaxValue
}

foreach ($item in $DATA) {
  if (-not $item.src) { continue }
  $folder = Join-Path $SRC $item.src
  if (-not (Test-Path -LiteralPath $folder)) { Write-Host ('  ! no folder for ' + $item.slug); continue }

  # ---- hero, cropped to 16:9 at the source's own width when it is smaller
  #      than the target rather than upscaled to it
  $thumb = Get-ChildItem -LiteralPath $folder -File |
           Where-Object { $_.BaseName -eq 'thumbnail' } | Select-Object -First 1
  $heroNote = 'no thumbnail'
  if ($thumb) {
    $dst = Join-Path $IMG $item.hero
    $w  = [int](& $MAGICK identify -format '%w' $thumb.FullName)
    $tw = [Math]::Min($w, $HERO_W)
    $th = [int][Math]::Round($tw * $HERO_H / $HERO_W)
    & $MAGICK $thumb.FullName -resize ($tw.ToString() + 'x' + $th + '^') `
              -gravity center -extent ($tw.ToString() + 'x' + $th) -quality 82 $dst
    $heroNote = 'rebuilt ' + $tw + 'x' + $th
  }

  # ---- gallery
  $gdir = Join-Path $IMG ($item.slug + '-gallery')
  $main = Join-Path $folder 'Main gallery'
  $n = 0
  if (Test-Path -LiteralPath $main) {
    New-Item -ItemType Directory -Force $gdir | Out-Null
    Get-ChildItem $gdir -File |
      Where-Object { $_.Extension -match '^\.(avif|webp|png|jpe?g)$' } | Remove-Item -Force
    $shots = Get-ChildItem -LiteralPath $main -File |
             Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' } |
             Sort-Object { NaturalKey $_.Name }
    foreach ($shot in $shots) {
      $n++
      & $MAGICK $shot.FullName -resize ($GAL_W.ToString() + 'x' + $GAL_H + '>') -quality $GAL_Q `
                (Join-Path $gdir ($item.slug + '-' + $n + '.avif'))
    }
  }

  # ---- the inline figure, pulled out of the .docx
  #
  # The captioned photos live inside the Word file, not in the folder: the
  # author placed each one against its own caption there. Taking it from the
  # .docx is what guarantees the caption still describes the photo above it.
  # A .docx is a zip, so word/media holds them in document order.
  $figNote = 'none'
  if ($item.ka.figure) {
    $doc = Get-ChildItem -LiteralPath $folder -Filter '*.docx' -File | Select-Object -First 1
    if ($doc) {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $tmp = Join-Path $env:TEMP ('news-' + $item.slug + '.zip')
      Copy-Item $doc.FullName $tmp -Force
      $zip = [IO.Compression.ZipFile]::OpenRead($tmp)
      # image2 is the second inline shape: the first is the hero, the third is
      # the shot that was later moved to "DO NOT USE" and must not be published.
      $entry = $zip.Entries | Where-Object { $_.FullName -like 'word/media/image2.*' } | Select-Object -First 1
      if ($entry) {
        $raw = Join-Path $env:TEMP ('news-fig-' + $item.slug + [IO.Path]::GetExtension($entry.FullName))
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $raw, $true)
        & $MAGICK $raw -resize '1400x>' -quality 82 (Join-Path $IMG $item.ka.figure.img)
        $figNote = $item.ka.figure.img
        Remove-Item $raw -Force
      }
      $zip.Dispose(); Remove-Item $tmp -Force
    }
  }

  $size = if ($n) { ' (' + [math]::Round((Get-ChildItem $gdir -File | Measure-Object Length -Sum).Sum / 1KB) + ' KB)' } else { '' }
  Write-Host ('  {0,-16} hero {1,-22} gallery {2} images{3}  figure {4}' -f $item.slug, $heroNote, $n, $size, $figNote)
}
