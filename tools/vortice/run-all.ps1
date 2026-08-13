# Run the Vortice pipeline end to end, in order.
#
# The steps are separate scripts because each is independently re-runnable --
# regenerating pages after a copy tweak does not need the spreadsheet parsed
# again. This runs the lot, which is what you want after the source library or
# the price list has changed. See README.md.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$steps = @(
  @{ n = '1/7 price list -> models';      f = 'vortice-sheet2.ps1'  },
  @{ n = '2/7 library scan';              f = 'vortice-build.ps1'   },
  @{ n = '3/7 assign models to pages';    f = 'vortice-assign.ps1'  },
  @{ n = '4/7 pooled galleries';          f = 'vortice-images.ps1'  },
  @{ n = '5/7 per-model galleries';       f = 'vortice-images2.ps1' },
  @{ n = '6/7 product pages';             f = 'vortice-gen.ps1'     },
  @{ n = '7/7 hub + category pages';      f = 'vortice-hub.ps1'     }
)
foreach ($s in $steps) {
  Write-Host ''
  Write-Host ('=== ' + $s.n) -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot $s.f)
}

Write-Host ''
Write-Host '=== search index' -ForegroundColor Cyan
& (Join-Path $repo 'build-search-index.ps1')

Write-Host ''
Write-Host '=== link check' -ForegroundColor Cyan
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'linkcheck.ps1')
