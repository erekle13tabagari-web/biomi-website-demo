# Project heroes and galleries, from the photo folders.
#
# Reads "src" out of projects.json -- the folder name under "Projects files" --
# and rebuilds that project's hero and gallery from it. The folder is the whole
# source of truth: change which photos are in "Main gallery", or how many, and
# re-running this plus 3-pages.ps1 is all it takes. Nothing stores a count.
#
# The gallery is cleared before it is rebuilt, so removing a photo from the
# folder removes it from the site rather than leaving an orphan behind.
#
# "DO NOT USE" folders are never read -- only "Main gallery" and the thumbnail.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$SRC  = Join-Path $repo 'Projects files'
$MAGICK = 'magick'

# The hero matches proj-terminal.jpg at 1600x900; the gallery matches the
# terminal and pasha sets at 1600px wide, which lands each shot around 45 KB.
$HERO_W = 1600; $HERO_H = 900; $GAL_W = 1600; $GAL_H = 1200; $GAL_Q = 48

$DATA = Get-Content (Join-Path $sp 'projects.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# "4-2.png" sorts between 4 and 5, and "10.png" after "9.png" -- plain string
# ordering gets both wrong, so sort on the leading number then the remainder.
function NaturalKey($name) {
  if ($name -match '^(\d+)(?:-(\d+))?') {
    return [double]$Matches[1] + ([double]($Matches[2] | ForEach-Object { if ($_) { $_ } else { 0 } }) / 100)
  }
  return [double]::MaxValue
}

foreach ($proj in $DATA) {
  if (-not $proj.src) { continue }
  $folder = Join-Path $SRC $proj.src
  if (-not (Test-Path -LiteralPath $folder)) { Write-Host ('  ! no folder for ' + $proj.slug); continue }

  # ---- hero. Every hero on the site is 16:9, so crop to that -- but at the
  #      source's own width when it is smaller than the target rather than
  #      upscaling to it. ORO's thumbnail is a 1440x1920 portrait and the
  #      chateau's is 1024x576; blowing either up to 1600 adds pixels, not
  #      detail, and 1440x810 is still twice the width the hero displays at.
  $thumb = Get-ChildItem -LiteralPath $folder -File |
           Where-Object { $_.BaseName -eq 'thumbnail' } | Select-Object -First 1
  $heroNote = 'no thumbnail'
  if ($thumb) {
    $dst = Join-Path $repo ('assets\img\proj-' + $proj.slug + '.jpg')
    $w  = [int](& $MAGICK identify -format '%w' $thumb.FullName)
    $tw = [Math]::Min($w, $HERO_W)
    $th = [int][Math]::Round($tw * $HERO_H / $HERO_W)
    & $MAGICK $thumb.FullName -resize ($tw.ToString() + 'x' + $th + '^') `
              -gravity center -extent ($tw.ToString() + 'x' + $th) -quality 82 $dst
    $heroNote = 'rebuilt ' + $tw + 'x' + $th
  }

  # ---- gallery
  $gdir = Join-Path $repo ('assets\img\' + $proj.slug + '-gallery')
  $main = Join-Path $folder 'Main gallery'
  $n = 0
  if (Test-Path -LiteralPath $main) {
    New-Item -ItemType Directory -Force $gdir | Out-Null
    # Clear every image, not just the .avif this writes: ORO's gallery was
    # hand-built from .webp and .jpg, and leaving those behind would keep
    # 800 KB of files nothing references any more.
    Get-ChildItem $gdir -File |
      Where-Object { $_.Extension -match '^\.(avif|webp|png|jpe?g)$' } | Remove-Item -Force
    $shots = Get-ChildItem -LiteralPath $main -File |
             Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' } |
             Sort-Object { NaturalKey $_.Name }
    # Fit inside 1600x1200 rather than capping the width alone: ORO's shots
    # are 1440x1920 portraits, and holding them to 1600 wide would give each
    # one 2.8 megapixels against a landscape shot's 1.1, which is how nine
    # photos came to 1.3 MB. '>' only ever shrinks, so a small source is
    # left at its own size.
    foreach ($shot in $shots) {
      $n++
      & $MAGICK $shot.FullName -resize ($GAL_W.ToString() + 'x' + $GAL_H + '>') -quality $GAL_Q `
                (Join-Path $gdir ($proj.slug + '-' + $n + '.avif'))
    }
  }
  $size = if ($n) { ' (' + [math]::Round((Get-ChildItem $gdir -File | Measure-Object Length -Sum).Sum / 1KB) + ' KB)' } else { '' }
  Write-Host ('  {0,-10} hero {1,-32} gallery {2,2} images{3}' -f $proj.slug, $heroNote, $n, $size)
}
