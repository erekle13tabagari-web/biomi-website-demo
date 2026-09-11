# Which boilers the site publishes.
#
# The domestic wall-hung ranges are held back for now: only outputs of
# $BOILER_KWMIN and above are built. This file is the only place that decides
# it. Three generators need the rule and none of them may keep its own copy:
#
#   3-pages.ps1              builds the family pages
#   4-hubs.ps1               builds the brand hubs, one card per family
#   build-category-pages.ps1 builds products/boilers.html by scraping the
#                            cards back out of those hubs, and prints the
#                            "from N kW" label on the output filter
#
# A second copy of the threshold would drift, and the drift would show up as a
# filter offering a band with nothing behind it.
#
# To publish the full range again: set $BOILER_KWMIN to 0 and re-run, in order,
#   tools/boilers/3-pages.ps1
#   tools/boilers/4-hubs.ps1
#   tools/build-category-pages.ps1
#   tools/build-meta.ps1
#   build-search-index.ps1
# then delete nothing -- 3-pages.ps1 writes the family pages back.
#
# One thing does NOT follow automatically: the boilers lede and meta description
# in build-category-pages.ps1 were rewritten to say "commercial, cascade", since
# the old copy promised flats and wall-hung boilers the page can no longer show.
# Put those two lines back at the same time, or the category will undersell the
# range it is once again carrying.
$BOILER_KWMIN = 50

# The output is the number in the model name, the same reading the kW chips and
# the filter bands already use: CITY 24 -> 24, VIWA S 150 -> 150. The six-digit
# manufacturer codes that lead some names cannot match, since \b(\d{2,3})\b
# needs a boundary on both sides.
#
# Some names carry no output at all -- "RTQ 3S", "GULLIVER BS2" -- and their
# family states it instead, as a range, which 2-images.ps1 copies onto the
# model as .kw. The top of that range is what counts here: RTQ 3S runs from 35
# to 4000 kW, and it is a commercial boiler, not one of the small ones held back.
function BoilerKw($rec) {
  if ($rec.kw) { return [int](([string]$rec.kw -split '-')[-1]) }
  $m = [regex]::Match([string]$rec.name, '\b(\d{2,3})\b')
  if ($m.Success) { return [int]$m.Groups[1].Value }
  return 0
}

# The threshold is about the domestic wall-hung boilers. A burner is not one,
# whatever its output, so it is always published.
function Visible($rec) {
  if ($rec.cat -eq 'burners') { return $true }
  return (BoilerKw $rec) -ge $BOILER_KWMIN
}
