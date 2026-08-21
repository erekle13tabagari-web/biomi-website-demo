# Where the water-heater source material lives. Same pattern as tools/boilers
# and tools/vortice: drop a paths.local.ps1 beside this file to override on
# another machine. That file is gitignored, so each machine keeps its own.
$LIBRARY = 'C:\Users\Designer\Desktop\2026\პროდუქტები\ბოილერები'
$local = Join-Path $PSScriptRoot 'paths.local.ps1'
if (Test-Path $local) { . $local }
if (-not (Test-Path -LiteralPath $LIBRARY)) { throw "Water-heater photo library not found:`n  $LIBRARY" }
