# Turn the pictures dropped in the menu-images folder into the catalogue page's
# product cut-outs: trimmed to the product, sized for the page, one PNG per
# chapter at assets/img/cutouts/<icon>.png.
#
# The drop folder holds one sub-folder per chapter, named after the chapter, and
# whatever picture belongs there. Nothing else has to be told about it: the
# sub-folder is matched to menu-tree.json by name, and the chapter's own icon
# slug becomes the output filename -- which is what products-page.ps1 already
# points at. Drop a new picture in and re-run.
#
# Two kinds of source, decided per file rather than declared:
#
#  * Already cut out. Anything with an alpha channel is trusted as it is and
#    only trimmed. The pictures supplied for the menu are all of this kind.
#
#  * Shot on white. Every product render on the site is, and saved opaque -- a
#    corner pixel of all of them reads 255,255,255 at alpha 255 -- so laid over
#    a photograph each one arrives as a white rectangle. Those are keyed:
#
#      - Flood fill from the border, not a colour key. Half these products are
#        white themselves, and keying every white pixel punches holes through
#        them. Only white connected to the edge of the frame is background.
#      - The anti-aliased outline gets partial alpha from how pale it is, which
#        is what stops the cut-out reading as a sticker.
#      - The colour under that band is recovered: a pixel there is
#        observed = a*C + (1-a)*255, so C = (observed - (1-a)*255)/a. Keep the
#        observed value and every edge carries a white fringe, which is exactly
#        what shows against a dark photograph.
#
# WPF imaging rather than System.Drawing: sources include AVIF and WebP, and
# GDI+ decodes neither -- new Bitmap(path) throws "Parameter is not valid" on
# both. WIC, which is what BitmapDecoder sits on, reads them on this machine.
#
# Run:  powershell -ExecutionPolicy Bypass -File tools\cutout.ps1
param(
  # The drop folder. Found rather than named, because its name is Georgian and a
  # .ps1 has to carry a BOM for PowerShell 5.1 to read that as anything but
  # ANSI -- one save through the wrong editor and the literal is mojibake and
  # the path silently misses. A codepoint range in a regex cannot rot that way.
  [string]$Drop
)
$sp   = $PSScriptRoot
$repo = Split-Path $sp -Parent
$OUTDIR = Join-Path $repo 'assets\img\cutouts'

$BGOUT    = Join-Path $repo 'assets\img\cat-bg'
# The sub-folder of the drop that holds the chapter backgrounds rather than a
# chapter's products.
$BGFOLDER = 'Backgrounds'

$MARGIN  = 4
# The cut-out is never drawn wider than about 300 CSS pixels, so this is a
# little over 2x. PNG is the only alpha format every browser reads and it is a
# poor container for photographed metal -- the duct is the one to watch.
$MAXEDGE = 700
# The wash spans the window, so it is sized for a large screen rather than for
# the element. A blurred gradient survives being stretched, which is why this
# can be well under a 2x retina width.
$BGEDGE  = 1600

if (-not $Drop) {
  # Escapes, not the letters themselves: the point is that this line survives
  # being read as ANSI, and a literal Georgian character class would not.
  $cands = @(Get-ChildItem -LiteralPath $repo -Directory |
             Where-Object { $_.Name -match '[\u10A0-\u10FF\u1C90-\u1CBF]' })
  if ($cands.Count -ne 1) {
    throw ("expected one Georgian-named folder in the repo root, found " + $cands.Count +
           " -- pass -Drop <path>")
  }
  $Drop = $cands[0].FullName
}
if (-not (Test-Path -LiteralPath $Drop)) { throw ("drop folder not found: " + $Drop) }

$TREE = Get-Content (Join-Path $sp 'menu-tree.json') -Raw -Encoding UTF8 | ConvertFrom-Json

Add-Type -AssemblyName PresentationCore, WindowsBase

# C# for the pixel work: the boiler is 2109x3508, and a per-pixel loop in
# PowerShell over 7 million pixels takes minutes. Compiled it is instant.
$cs = @'
using System;
using System.Collections.Generic;

public class Cutout {
  // A pixel counts as background only if it is this close to white and this
  // close to neutral. Near-neutral matters: a pale blue wall in a photograph is
  // bright but not grey, and should never be eaten.
  static int BG_LUM = 250;
  const int BG_SPREAD = 8;
  // Where the anti-aliased edge is taken to run from: 255 is fully background,
  // EDGE_LUM and below is fully product.
  const int EDGE_LUM = 228;
  // Below this a pixel is too faint to be worth keeping in the crop -- the
  // outermost ring of a soft shadow, mostly.
  const int BOX_ALPHA = 8;

  // BGRA in memory, so index 0 is blue and 2 is red.
  static int Lum(byte[] p, int o) { return (p[o + 2] * 299 + p[o + 1] * 587 + p[o] * 114) / 1000; }

  static int Spread(byte[] p, int o) {
    int mx = Math.Max(p[o], Math.Max(p[o + 1], p[o + 2]));
    int mn = Math.Min(p[o], Math.Min(p[o + 1], p[o + 2]));
    return mx - mn;
  }

  static void White(byte[] p, int stride, int x, int y) {
    int o = y * stride + x * 4;
    p[o] = 255; p[o + 1] = 255; p[o + 2] = 255; p[o + 3] = 255;
  }

  static void Seed(byte[] px, int stride, bool[] bg, Queue<int> q, int w, int x, int y) {
    int i = y * w + x, o = y * stride + x * 4;
    if (bg[i]) return;
    if (Lum(px, o) < BG_LUM || Spread(px, o) > BG_SPREAD) return;
    bg[i] = true; q.Enqueue(i);
  }

  static bool Touches(bool[] bg, int w, int h, int x, int y) {
    for (int j = -1; j <= 1; j++)
      for (int i = -1; i <= 1; i++) {
        int nx = x + i, ny = y + j;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (bg[ny * w + nx]) return true;
      }
    return false;
  }

  // True if anything in the picture is not fully opaque.
  public static bool HasAlpha(byte[] px, int w, int h, int stride) {
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
        if (px[y * stride + x * 4 + 3] < 250) return true;
    return false;
  }

  // The box around everything worth keeping, as {minX, minY, maxX, maxY}.
  public static int[] Box(byte[] px, int w, int h, int stride) {
    int minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
        if (px[y * stride + x * 4 + 3] > BOX_ALPHA) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
    return new int[] { minX, minY, maxX, maxY };
  }

  // Rewrites px in place, cutting the white background away.
  public static void Key(byte[] px, int w, int h, int stride, int bgLum) {
    BG_LUM = bgLum;
    // Whiten the outermost ring first. Several of these AVIFs decode with a
    // black final row -- warmhaus-viwa/main is one -- and one bad row is enough
    // to seed nothing, keep the whole frame and leave a hairline across the
    // bottom of the cut-out. A product that genuinely reaches the edge loses a
    // pixel, which is nothing next to that.
    for (int x = 0; x < w; x++) { White(px, stride, x, 0); White(px, stride, x, h - 1); }
    for (int y = 0; y < h; y++) { White(px, stride, 0, y); White(px, stride, w - 1, y); }

    bool[] bg = new bool[w * h];
    Queue<int> q = new Queue<int>();
    for (int x = 0; x < w; x++) { Seed(px, stride, bg, q, w, x, 0); Seed(px, stride, bg, q, w, x, h - 1); }
    for (int y = 0; y < h; y++) { Seed(px, stride, bg, q, w, 0, y); Seed(px, stride, bg, q, w, w - 1, y); }

    int[] dx = { 1, -1, 0, 0 };
    int[] dy = { 0, 0, 1, -1 };
    while (q.Count > 0) {
      int i = q.Dequeue();
      int x = i % w, y = i / w;
      for (int k = 0; k < 4; k++) {
        int nx = x + dx[k], ny = y + dy[k];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        int ni = ny * w + nx;
        if (bg[ni]) continue;
        int o = ny * stride + nx * 4;
        if (Lum(px, o) < BG_LUM || Spread(px, o) > BG_SPREAD) continue;
        bg[ni] = true; q.Enqueue(ni);
      }
    }

    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++) {
        int i = y * w + x, o = y * stride + x * 4;
        if (bg[i]) { px[o] = 0; px[o + 1] = 0; px[o + 2] = 0; px[o + 3] = 0; continue; }
        int a = 255;
        if (Touches(bg, w, h, x, y)) {
          int l = Lum(px, o);
          if (l > EDGE_LUM) {
            a = (int)Math.Round(255.0 * (255 - l) / (255 - EDGE_LUM));
            if (a < 0) a = 0;
            if (a > 255) a = 255;
            if (a > 0) {
              double af = a / 255.0;
              for (int c = 0; c < 3; c++) {
                double v = (px[o + c] - (1 - af) * 255.0) / af;
                if (v < 0) v = 0;
                if (v > 255) v = 255;
                px[o + c] = (byte)Math.Round(v);
              }
            }
          }
        }
        px[o + 3] = (byte)a;
      }
  }
}
'@

Add-Type -TypeDefinition $cs

if (-not (Test-Path $OUTDIR)) { New-Item -ItemType Directory -Path $OUTDIR | Out-Null }

# A chapter folder is matched on the name, either way round: the ducting one is
# named for the first word of a chapter called "ჰაერსატარი და მაკომპლექტებელი".
function IconFor([string]$folder) {
  foreach ($ch in $TREE) {
    if (-not $ch.icon) { continue }
    if ($ch.ka -eq $folder -or $ch.ka.StartsWith($folder) -or $folder.StartsWith($ch.ka)) {
      return [string]$ch.icon
    }
  }
  return ''
}

# A sub-folder inside a chapter is one of its categories, named in English:
# "Boiler", "water heater", "in-line". Loosely, because those are typed by hand
# and the tree says "Boilers", "Water heaters", "In-line" -- so case, spacing,
# hyphens and a trailing s are all ignored.
#
# The key that comes back is what the page asks for the file by: a category's
# own filter slug where it has one (the four ventilation categories all live on
# the same listing and are told apart by cat=), otherwise its page.
function Norm([string]$s) { ($s -replace '[^a-z0-9]', '').TrimEnd('s') }
function KeyFor($chapter, [string]$folder) {
  $want = Norm $folder.ToLower()
  foreach ($it in $chapter.items) {
    if ((Norm $it.en.ToLower()) -eq $want) {
      if ($it.cat)  { return [string]$it.cat }
      if ($it.page) { return [string]$it.page }
    }
  }
  return ''
}

# One picture out of a folder, cut out if it needs it, trimmed to what is left,
# capped, and written as a PNG. Returns the size line for the log.
function WriteCutout([IO.FileInfo]$img, [string]$name) {
  $uri = New-Object System.Uri($img.FullName)
  $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create($uri, 'None', 'OnLoad')
  # to straight-alpha BGRA, which is both what the keying assumes and what the
  # PNG encoder wants
  $bmp = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap(
           $dec.Frames[0], [System.Windows.Media.PixelFormats]::Bgra32, $null, 0)
  $w = $bmp.PixelWidth; $h = $bmp.PixelHeight; $stride = $w * 4
  $px = New-Object byte[] ($stride * $h)
  $bmp.CopyPixels($px, $stride, 0)

  $cut = [Cutout]::HasAlpha($px, $w, $h, $stride)
  if (-not $cut) { [Cutout]::Key($px, $w, $h, $stride, 250) }

  $box = [Cutout]::Box($px, $w, $h, $stride)
  if ($box[2] -lt $box[0]) { return ($name + ' : nothing left after keying') }

  $x0 = [Math]::Max(0, $box[0] - $MARGIN); $y0 = [Math]::Max(0, $box[1] - $MARGIN)
  $x1 = [Math]::Min($w - 1, $box[2] + $MARGIN); $y1 = [Math]::Min($h - 1, $box[3] + $MARGIN)

  $src = [System.Windows.Media.Imaging.BitmapSource]::Create(
           $w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Bgra32, $null, $px, $stride)
  $rect = New-Object System.Windows.Int32Rect($x0, $y0, ($x1 - $x0 + 1), ($y1 - $y0 + 1))
  $pic = New-Object System.Windows.Media.Imaging.CroppedBitmap($src, $rect)

  if ($pic.PixelWidth -gt $MAXEDGE -or $pic.PixelHeight -gt $MAXEDGE) {
    $k = $MAXEDGE / [Math]::Max($pic.PixelWidth, $pic.PixelHeight)
    $pic = New-Object System.Windows.Media.Imaging.TransformedBitmap(
             $pic, (New-Object System.Windows.Media.ScaleTransform($k, $k)))
  }

  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($pic))
  $dst = Join-Path $OUTDIR ($name + '.png')
  $fs = [IO.File]::Open($dst, 'Create')
  $enc.Save($fs)
  $fs.Close()

  $kb = [math]::Round((Get-Item $dst).Length / 1kb)
  $how = if ($cut) { 'trimmed' } else { 'keyed  ' }
  return (($name + '.png').PadRight(24) + $how + '  ' + $pic.PixelWidth + 'x' + $pic.PixelHeight +
          ' (from ' + $w + 'x' + $h + ')  ' + $kb + ' KB')
}

function Pictures([string]$dir) {
  Get-ChildItem -LiteralPath $dir -File |
    Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp|avif|tif|tiff|bmp)$' } |
    Sort-Object Name
}

$done = 0
foreach ($dir in (Get-ChildItem -LiteralPath $Drop -Directory | Sort-Object Name)) {
  if ($dir.Name -eq $BGFOLDER) { continue }
  $icon = IconFor $dir.Name
  if (-not $icon) { Write-Host ('  no chapter matches folder: ' + $dir.Name); continue }
  $chapter = $TREE | Where-Object { [string]$_.icon -eq $icon } | Select-Object -First 1

  # A picture sitting loose in the chapter folder is the chapter's own product.
  # Where there is none the page falls back to the first category that has one,
  # so heating opens on its boiler without anything having to say so.
  $loose = @(Pictures $dir.FullName)
  if ($loose.Count) { Write-Host ('  ' + (WriteCutout $loose[0] $icon)); $done++ }

  # Each sub-folder is one category of that chapter.
  foreach ($sub in (Get-ChildItem -LiteralPath $dir.FullName -Directory | Sort-Object Name)) {
    $key = KeyFor $chapter $sub.Name
    if (-not $key) {
      Write-Host ('  no category in ' + $icon + ' matches sub-folder: ' + $sub.Name); continue
    }
    $pics = @(Pictures $sub.FullName)
    if (-not $pics.Count) { Write-Host ('  ' + ($icon + '-' + $key).PadRight(24) + 'no picture yet'); continue }
    Write-Host ('  ' + (WriteCutout $pics[0] ($icon + '-' + $key)))
    $done++
  }
}

# ---- the backgrounds
#
# The wash behind the catalogue band, one per chapter. Not cut-outs: these are
# full-frame gradients, so they are only resized and re-encoded.
#
# JPEG, not PNG. PNG stores a smooth gradient badly -- these arrived at 1.1 MB
# each and come out around a tenth of that as JPEG, with nothing to see in the
# difference on a gradient.
#
# Matched by filename because they are named in English and do not correspond to
# anything in the tree: "Air ducts" is the chapter the tree calls
# "Ducting & fittings". Rename a file and add a line here.
$BGMAP = @{ 'heating' = 'heating'; 'cooling' = 'cooling'; 'ventilation' = 'ventilation'
            'air ducts' = 'ducting'; 'water supply' = 'water' }
$bgDir = Join-Path $Drop $BGFOLDER
if (Test-Path -LiteralPath $bgDir) {
  if (-not (Test-Path $BGOUT)) { New-Item -ItemType Directory -Path $BGOUT | Out-Null }
  foreach ($img in (Pictures $bgDir)) {
    $key = $img.BaseName.ToLower()
    if (-not $BGMAP.ContainsKey($key)) { Write-Host ('  no chapter for background: ' + $img.Name); continue }
    $icon = $BGMAP[$key]

    $uri = New-Object System.Uri($img.FullName)
    $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create($uri, 'None', 'OnLoad')
    $pic = $dec.Frames[0]
    $w0 = $pic.PixelWidth; $h0 = $pic.PixelHeight
    if ($pic.PixelWidth -gt $BGEDGE) {
      $k = $BGEDGE / $pic.PixelWidth
      $pic = New-Object System.Windows.Media.Imaging.TransformedBitmap(
               $pic, (New-Object System.Windows.Media.ScaleTransform($k, $k)))
    }
    $enc = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
    $enc.QualityLevel = 82
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($pic))
    $dst = Join-Path $BGOUT ($icon + '.jpg')
    $fs = [IO.File]::Open($dst, 'Create')
    $enc.Save($fs)
    $fs.Close()

    $kb = [math]::Round((Get-Item $dst).Length / 1kb)
    Write-Host ('  ' + ($icon + '.jpg').PadRight(24) + 'wash     ' + $pic.PixelWidth + 'x' +
                $pic.PixelHeight + ' (from ' + $w0 + 'x' + $h0 + ')  ' + $kb + ' KB')
    $done++
  }
}

Write-Host ("pictures written : $done")
