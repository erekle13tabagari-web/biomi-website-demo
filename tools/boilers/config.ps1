# Where the boiler source material lives. Same pattern as tools/vortice:
# drop a paths.local.ps1 beside this file to override on another machine.
$LIBRARY = 'C:\Users\Designer\Desktop\2026\პროდუქტები\ქვაბები'
$local = Join-Path $PSScriptRoot 'paths.local.ps1'
if (Test-Path $local) { . $local }
if (-not (Test-Path -LiteralPath $LIBRARY)) { throw "Boiler photo library not found:`n  $LIBRARY" }