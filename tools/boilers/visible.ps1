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
function BoilerKw($name) {
  $m = [regex]::Match($name, '\b(\d{2,3})\b')
  if ($m.Success) { return [int]$m.Groups[1].Value }
  return 0
}
