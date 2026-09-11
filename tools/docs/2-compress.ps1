# Compress every mapped document into assets/downloads/.
#
# The source library is 750+ MB of mapped PDFs, which will not fit a GitHub
# Pages site (1 GB published cap). Most of the weight is print-resolution
# imagery in scanned booklets, so images are converted to RGB and downsampled to
# 110 dpi -- readable on screen, printable at a pinch, a fraction of the size.
#
# Two details that cost an afternoon to find:
#   * The images in these PDFs are mostly CMYK, and Ghostscript's downsample
#     filter refuses CMYK ("Failed to initialise downsample filter"). The RGB
#     conversion is not cosmetic -- without it nothing downsamples at all.
#   * Arguments must be built as an array and splatted. Built inline, PowerShell
#     mangles -sOutputFile and Ghostscript reports "requires an output file".
#
# A file that comes out no smaller is copied across untouched, so a
# well-optimised original is never made worse.
#
# A document already published under the same name from the same source file
# is kept as it is, not compressed again: Ghostscript stamps fresh dates and IDs
# on every run, so recompressing all 244 turned each run into 244 changed PDFs
# with nothing in them changed. -Force redoes every file -- for new settings,
# or a source that was replaced under the same name.
param([switch]$Force)
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$GS   = 'C:\Program Files\gs\gs10.03.1\bin\gswin64c.exe'
$PT   = 'C:\Users\Designer\AppData\Local\Microsoft\WinGet\Packages\oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe\poppler-25.07.0\Library\bin\pdftotext.exe'
$PU   = Join-Path (Split-Path $PT) 'pdfunite.exe'
if (-not (Test-Path $GS)) { throw "Ghostscript not found at`n  $GS" }
$out = Join-Path $repo 'assets\downloads'
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path $env:TEMP 'biomi-docs'
New-Item -ItemType Directory -Force $tmp | Out-Null

# Names already published under the old hand-built documents blocks. Keeping
# them off-limits stops a generated file overwriting a different document that
# 30-odd pages still point at.
$RESERVED = @('mitsubishi-msz-ln-brochure', 'samsung-technical-catalogue')

$GSARGS = @(
  '-sDEVICE=pdfwrite', '-dCompatibilityLevel=1.5', '-dNOPAUSE', '-dBATCH', '-dQUIET',
  '-sColorConversionStrategy=RGB', '-dProcessColorModel=/DeviceRGB',
  '-dDownsampleColorImages=true', '-dColorImageDownsampleType=/Bicubic', '-dColorImageResolution=110',
  '-dDownsampleGrayImages=true',  '-dGrayImageDownsampleType=/Bicubic',  '-dGrayImageResolution=110',
  '-dDownsampleMonoImages=true',  '-dMonoImageDownsampleType=/Subsample', '-dMonoImageResolution=300',
  '-dAutoFilterColorImages=false', '-dColorImageFilter=/DCTEncode',
  '-dAutoFilterGrayImages=false',  '-dGrayImageFilter=/DCTEncode',
  '-dJPEGQ=70', '-dSubsetFonts=true', '-dCompressFonts=true'
)

$docs = Get-Content (Join-Path $sp 'docs.json')      -Raw -Encoding UTF8 | ConvertFrom-Json
# published file -> the source it was made from, to know when one can be kept
$WAS = @{}
$pubPath = Join-Path $sp 'published.json'
if (Test-Path $pubPath) {
  foreach ($e in (Get-Content $pubPath -Raw -Encoding UTF8 | ConvertFrom-Json)) { $WAS[[string]$e.file] = [string]$e.name }
}
$ovr  = Get-Content (Join-Path $sp 'overrides.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Slug($s) {
  $s = $s -replace '[^A-Za-z0-9]+', '-'
  return $s.Trim('-').ToLower()
}

# Every Vortice document is named for the article code it belongs to -- either
# bare (0000016039.pdf, de-0000012001.pdf) or embedded (70_EN_16039_Libretti…).
# Without resolving that code to a model name, a page ends up listing six
# identical "Instruction booklet" links with nothing to tell them apart.
#
# The code -> model table is built from two sources: the priced model list, and
# the data sheets themselves, whose first page reads "CODE 16039 / CA 250 V0 E".
# The second source matters because the library holds documents for codes Biomi
# does not stock, which are therefore absent from the priced list.
function DocCode($name) {
  if ($name -match '^(?:de-)?0*(\d{4,6})( \(\d+\))?\.pdf$') { return $Matches[1] }
  if ($name -match '^70_[A-Z]{2}_(\d{4,6})')                { return $Matches[1] }
  return ''
}
function SheetModel($src) {
  $t = & $PT -enc UTF-8 -f 1 -l 1 -q $src - 2>$null
  for ($i = 0; $i -lt $t.Count; $i++) {
    if ($t[$i] -match '^\s*CODE\s+\d+') {
      for ($j = $i + 1; $j -lt [Math]::Min($i + 4, $t.Count); $j++) {
        $line = $t[$j].Trim()
        if ($line -and $line.Length -lt 48) { return $line }
      }
    }
  }
  return ''
}

$byCode = @{}
foreach ($m in (Get-Content (Join-Path $repo 'tools\vortice\vortice-pages.json') -Raw -Encoding UTF8 | ConvertFrom-Json)) {
  $byCode[[string]$m.code] = $m.model
}
foreach ($d in ($docs | Where-Object { $_.class -in 'datasheet', 'energy' })) {
  $c = DocCode $d.name
  if ($c -and -not $byCode.ContainsKey($c)) {
    $mm = SheetModel $d.src
    if ($mm) { $byCode[$c] = $mm }
  }
}
Write-Host ("vortice article codes resolved to a model: " + $byCode.Keys.Count)

# Run Ghostscript over one page range into its own file.
function Slice($src, $first, $last, $dst) {
  & $GS @($GSARGS + @("-dFirstPage=$first", "-dLastPage=$last", "-sOutputFile=$dst", $src)) 2>$null | Out-Null
}

$groups = $docs | Group-Object hash
$taken  = @{}
foreach ($n in $RESERVED) { $taken[$n] = $true }
$result = New-Object System.Collections.ArrayList
$i = 0
foreach ($g in $groups) {
  $i++
  $r = $g.Group[0]
  $o = $ovr.($r.name)
  if ($o -and $o.exclude) {
    Write-Host ('  [{0,3}/{1}] SKIPPED {2}' -f $i, $groups.Count, $r.name)
    continue
  }
  $model = ''
  $code  = DocCode $r.name
  if ($code -and $byCode.ContainsKey($code)) { $model = $byCode[$code] }

  # Parenthesise the call: `Slug ($x) + '-y'` passes '+' and '-y' to Slug as
  # extra arguments instead of concatenating, and the suffix silently vanishes.
  $base = if ($o -and $o.as) { $o.as }
          elseif ($model)    { (Slug ($r.cat + '-' + $model + '-' + $r.class)) }
          else               { $r.slugs[0] + '-' + $r.class }
  # An "as" override names the file deliberately, including over a reserved
  # name it is meant to replace.
  $n = $base; $k = 2
  if (-not ($o -and $o.as)) {
    while ($taken.ContainsKey($n)) { $n = ($base + '-' + $k); $k++ }
  }
  $taken[$n] = $true
  $dst = Join-Path $out ($n + '.pdf')

  # Same name, same source, already on disk: nothing to redo (see the top).
  $reuse = (-not $Force) -and (Test-Path $dst) -and ($WAS[($n + '.pdf')] -eq $r.name)
  if ($reuse) {
    # kept as published
  } elseif ($o -and $o.pages) {
    # keep only the wanted page ranges, then stitch them back together
    $parts = @()
    $p = 0
    foreach ($range in ($o.pages -split ',')) {
      $p++
      $a, $b = $range -split '-'
      if (-not $b) { $b = $a }
      $part = Join-Path $tmp ("part$p.pdf")
      Slice $r.src $a $b $part
      $parts += $part
    }
    if ($parts.Count -gt 1) { & $PU @($parts + @($dst)) 2>$null | Out-Null }
    else { Copy-Item $parts[0] $dst -Force }
    $parts | ForEach-Object { Remove-Item $_ -Force -EA SilentlyContinue }
  } else {
    & $GS @($GSARGS + @("-sOutputFile=$dst", $r.src)) 2>$null | Out-Null
  }

  $srcLen = (Get-Item -LiteralPath $r.src).Length
  if (-not $reuse -and ((-not (Test-Path $dst)) -or ((Get-Item $dst).Length -ge $srcLen -and -not $o))) {
    Copy-Item -LiteralPath $r.src -Destination $dst -Force
  }
  $mb = [math]::Round((Get-Item $dst).Length / 1MB, 2)
  $slugs = @($g.Group | ForEach-Object { $_.slugs } | Sort-Object -Unique)
  [void]$result.Add([pscustomobject]@{
    file = ($n + '.pdf'); class = $r.class; cat = $r.cat; model = $model
    name = $r.name; mb = $mb; srcmb = [math]::Round($srcLen/1MB,2); slugs = $slugs
  })
  Write-Host ('  [{0,3}/{1}] {2,-46} {3,6:N1} -> {4,5:N1} MB' -f $i, $groups.Count, $n, ($srcLen/1MB), $mb)
}

$result | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $sp 'published.json') -Encoding UTF8
Write-Host ''
Write-Host ('{0} files, {1:N0} MB source -> {2:N0} MB published' -f $result.Count,
            (($result | Measure-Object -Property srcmb -Sum).Sum),
            (($result | Measure-Object -Property mb -Sum).Sum))
Write-Host ''
Write-Host 'largest published files:'
$result | Sort-Object mb -Descending | Select-Object -First 10 |
  ForEach-Object { '  {0,6:N1} MB  {1,-44} {2}' -f $_.mb, $_.file, $_.name }
