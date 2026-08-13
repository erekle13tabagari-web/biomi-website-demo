# Where the Vortice source material lives.
#
# These two paths are the only thing about this pipeline that is specific to
# one machine. The photo library is ~1.7 GB and the price list is a working
# document, so neither is in the repo -- they are synced separately (OneDrive,
# a external drive, whatever) and can sit anywhere.
#
# To run this on a second machine, do NOT edit the defaults below: drop a
# paths.local.ps1 next to this file and set them there. That file is
# gitignored, so each machine keeps its own without ever showing up as a diff.
# See paths.local.example.ps1.

$LIBRARY   = 'C:\Users\Designer\Desktop\2026\პროდუქტები\ვენტილაცია\Vortice'
$PRICELIST = 'C:\Users\Designer\Desktop\Vortiche Tecnical Price.xlsx'

$local = Join-Path $PSScriptRoot 'paths.local.ps1'
if (Test-Path $local) { . $local }

# Fail loudly and early. A missing library used to surface as "0 images" three
# steps later, which reads like a data problem rather than a setup one.
if (-not (Test-Path -LiteralPath $LIBRARY)) {
  throw "Vortice photo library not found:`n  $LIBRARY`nSet `$LIBRARY in tools/vortice/paths.local.ps1 (see paths.local.example.ps1)."
}
