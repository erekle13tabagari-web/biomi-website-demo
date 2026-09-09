# Cut a product render out of its white background and write a transparent PNG.
#
# Every product image on the site is shot on solid white and saved opaque -- a
# corner pixel of all of them reads 255,255,255 at alpha 255. That is right for
# a card with a white photo panel, which is what they have always sat in, but it
# cannot be laid over a photograph: the render arrives as a white rectangle.
#
# The catalogue page stands the product in front of an installation shot, so the
# white has to go. Three things make that safe here:
#
#  * Flood fill from the border, not a colour key. Half these products are white
#    themselves -- a Beretta boiler, a Samsung wall unit -- and keying every
#    white pixel punches holes straight through them. Only white that is
#    connected to the edge of the frame is background.
#
#  * A soft edge. The render is anti-aliased against white, so its outline is a
#    band of pale pixels. They are given partial alpha from how pale they are,
#    which is what stops the cut-out reading as a sticker.
#
#  * The colour under that band is recovered rather than kept. An edge pixel is
#    observed = a*C + (1-a)*255, so C = (observed - (1-a)*255)/a. Keep the
#    observed value instead and every edge carries a white fringe, which is
#    exactly what shows against a dark photograph.
#
# The result is cropped to the product with a small margin, so the PNG has no
# dead space to position around.
#
# WPF imaging rather than System.Drawing: the sources are AVIF and WebP, and
# GDI+ decodes neither -- new Bitmap(path) throws "Parameter is not valid" on
# both. WIC, which is what BitmapDecoder sits on, reads them on this machine.
#
# Run:  powershell -ExecutionPolicy Bypass -File tools\cutout.ps1
$sp   = $PSScriptRoot
$repo = Split-Path $sp -Parent
$OUT  = Join-Path $repo 'assets\img\cutouts'

# The renders the catalogue page stands in front of its chapter photographs.
# Source is whatever the listing already uses; the name is what products.html
# asks for. Add a line here and re-run -- nothing else knows about the list.
# lum is the brightness a pixel has to reach to count as background, 250 unless
# a render carries a soft grey shadow on its white -- the ducting photographs
# do, and at 250 the fill stops at the shadow and leaves a pale blob under the
# product. 236 eats it and still stops at galvanised steel.
$JOBS = @(
  @{ src = 'assets\img\products\warmhaus-viwa-50-65\main.avif';          out = 'heating.png'     }
  @{ src = 'assets\img\products\samsung-cac-outdoor\ac140bxadeh-1.avif'; out = 'cooling.png'     }
  @{ src = 'assets\img\products\vortice-lineo\main.avif';                out = 'ventilation.png' }
  @{ src = 'assets\img\ducting\elbow-round.webp';                        out = 'ducting.png'; lum = 236 }
)

Add-Type -AssemblyName PresentationCore, WindowsBase

# C# for the pixel work: the largest of these is 1100x825, and a per-pixel loop
# in PowerShell over 900,000 pixels takes minutes. Compiled it is instant.
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

  // Rewrites px in place and returns the bounding box of what survived.
  public static int[] Key(byte[] px, int w, int h, int stride, int bgLum) {
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

    int minX = w, minY = h, maxX = -1, maxY = -1;
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
        if (a > 8) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    return new int[] { minX, minY, maxX, maxY };
  }
}
'@

Add-Type -TypeDefinition $cs

if (-not (Test-Path $OUT)) { New-Item -ItemType Directory -Path $OUT | Out-Null }

$MARGIN  = 6
$MAXEDGE = 620
foreach ($j in $JOBS) {
  $in = Join-Path $repo $j.src
  if (-not (Test-Path $in)) { Write-Host ('  missing : ' + $j.src); continue }

  $uri = New-Object System.Uri((Resolve-Path $in).Path)
  $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create($uri, 'None', 'OnLoad')
  # to straight-alpha BGRA, which is both what the keying below assumes and what
  # the PNG encoder wants
  $bmp = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap(
           $dec.Frames[0], [System.Windows.Media.PixelFormats]::Bgra32, $null, 0)
  $w = $bmp.PixelWidth; $h = $bmp.PixelHeight; $stride = $w * 4
  $px = New-Object byte[] ($stride * $h)
  $bmp.CopyPixels($px, $stride, 0)

  $lum = if ($j.lum) { [int]$j.lum } else { 250 }
  $box = [Cutout]::Key($px, $w, $h, $stride, $lum)
  if ($box[2] -lt $box[0]) { Write-Host ('  ' + $j.out + ' : nothing left after keying'); continue }

  $x0 = [Math]::Max(0, $box[0] - $MARGIN); $y0 = [Math]::Max(0, $box[1] - $MARGIN)
  $x1 = [Math]::Min($w - 1, $box[2] + $MARGIN); $y1 = [Math]::Min($h - 1, $box[3] + $MARGIN)

  $src = [System.Windows.Media.Imaging.BitmapSource]::Create(
           $w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Bgra32, $null, $px, $stride)
  $rect = New-Object System.Windows.Int32Rect($x0, $y0, ($x1 - $x0 + 1), ($y1 - $y0 + 1))
  $crop = New-Object System.Windows.Media.Imaging.CroppedBitmap($src, $rect)

  # Capped at $MAXEDGE. A cut-out is a PNG -- there is no lossy option with an
  # alpha channel that every browser reads -- and PNG is a poor container for a
  # photographed metal surface: the ducting elbow came to 558 KB at its native
  # 772px. Nothing here is ever drawn wider than about 300 CSS pixels, so this
  # is still twice what a 2x screen asks for.
  if ($crop.PixelWidth -gt $MAXEDGE -or $crop.PixelHeight -gt $MAXEDGE) {
    $k = $MAXEDGE / [Math]::Max($crop.PixelWidth, $crop.PixelHeight)
    $crop = New-Object System.Windows.Media.Imaging.TransformedBitmap(
              $crop, (New-Object System.Windows.Media.ScaleTransform($k, $k)))
  }

  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($crop))
  $dst = Join-Path $OUT $j.out
  $fs = [IO.File]::Open($dst, 'Create')
  $enc.Save($fs)
  $fs.Close()

  $kb = [math]::Round((Get-Item $dst).Length / 1kb)
  Write-Host ('  ' + $j.out.PadRight(18) + $crop.PixelWidth + 'x' + $crop.PixelHeight +
              '  (from ' + $w + 'x' + $h + ')  ' + $kb + ' KB')
}

