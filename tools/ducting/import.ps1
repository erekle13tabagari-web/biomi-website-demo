# Bring the supplied product shots into the site as web pictures.
#
# The drop folder is outside the repo -- it is the product photography tree on
# the Desktop -- so its path is a parameter, with the current one as the
# default. Nothing about which file becomes which picture is written here:
# every item in ducting.json that carries a "src" names its own source file,
# and its group names the sub-folder holding it. Drop a picture in, add the
# item, run this.
#
# JPEG, not WebP. There is no WebP encoder on this machine -- WIC reads them
# and will not write them -- and these are photographs of galvanised metal on
# white with no transparency, which is what JPEG is for. The .webp files
# already in assets stay as they are: build-ducting.ps1 takes whichever of the
# two extensions is on disk, so the two can live side by side.
#
# The source shots are 1448px and 1-2MB each. They are drawn onto a 900x600
# white canvas, fitted inside it and centred, which is the shape and the ground
# the card already draws them on -- so every part on the page is the same
# optical size whatever its own picture measured.
param(
  [string]$Drop = 'C:\Users\Designer\Desktop\2026\პროდუქტები\ჰაერსატარები',
  # Only missing pictures are written. Pass -Force to redo one that changed.
  [switch]$Force
)

$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$OUT  = Join-Path $repo 'assets\img\ducting'

$W = 900
$H = 600
$QUALITY = 88

$DATA = Get-Content (Join-Path $sp 'ducting.json') -Raw -Encoding UTF8 | ConvertFrom-Json

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Decoded from a stream rather than a Uri: these filenames are Georgian and
# carry spaces, and a file:// Uri wants every one of those escaped.
function Shot([string]$src, [string]$dst) {
  $in = [IO.File]::OpenRead($src)
  $frame = ([System.Windows.Media.Imaging.BitmapDecoder]::Create(
              $in, 'None', 'OnLoad')).Frames[0]
  $in.Close()

  $k = [Math]::Min($W / $frame.PixelWidth, $H / $frame.PixelHeight)
  $w = [Math]::Round($frame.PixelWidth * $k)
  $h = [Math]::Round($frame.PixelHeight * $k)

  $dv = New-Object System.Windows.Media.DrawingVisual
  # The default scaling mode is a fast one, and these come down from 1448px;
  # without this the mesh of a grille turns into moire.
  [System.Windows.Media.RenderOptions]::SetBitmapScalingMode(
    $dv, [System.Windows.Media.BitmapScalingMode]::HighQuality)
  $dc = $dv.RenderOpen()
  $dc.DrawRectangle([System.Windows.Media.Brushes]::White, $null,
                    (New-Object System.Windows.Rect(0, 0, $W, $H)))
  $dc.DrawImage($frame, (New-Object System.Windows.Rect(
                    (($W - $w) / 2), (($H - $h) / 2), $w, $h)))
  $dc.Close()

  $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
           $W, $H, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
  $rtb.Render($dv)

  $enc = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
  $enc.QualityLevel = $QUALITY
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
  $out = [IO.File]::Open($dst, 'Create')
  $enc.Save($out)
  $out.Close()
}

if (-not (Test-Path -LiteralPath $Drop)) {
  Write-Host ('  drop folder not found: ' + $Drop)
  exit 1
}

$made = 0; $kept = 0; $missing = New-Object System.Collections.Generic.List[string]
foreach ($g in $DATA) {
  $folder = if ($g.group.src) { Join-Path $Drop $g.group.src } else { $Drop }
  foreach ($it in $g.items) {
    if (-not $it.src) { continue }
    $src = Join-Path $folder $it.src
    if (-not (Test-Path -LiteralPath $src)) { $missing.Add($it.src); continue }
    $dst = Join-Path $OUT ($it.img + '.jpg')
    if ((Test-Path -LiteralPath $dst) -and -not $Force) { $kept++; continue }
    Shot $src $dst
    $kb = [math]::Round((Get-Item -LiteralPath $dst).Length / 1kb)
    Write-Host ('  ' + ($it.img + '.jpg').PadRight(28) + $kb + ' KB')
    $made++
  }
}
Write-Host ('pictures written : ' + $made + '   already there : ' + $kept)
if ($missing.Count) {
  Write-Host ('source not found : ' + ($missing -join ', '))
}
