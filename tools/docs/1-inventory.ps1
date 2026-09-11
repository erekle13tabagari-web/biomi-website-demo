# Find every product document in the source libraries and work out which page
# each one belongs to.
#
# Reads folder->page mappings from the generators that already have them
# (tools/boilers, tools/water-heaters, tools/vortice families.json) and from
# map.json for the air-conditioner library, which has no generator.
#
# Nothing is copied or published here. This only writes docs.json plus a report,
# so the mapping can be checked before 1.9 GB of PDFs is touched.
$sp   = $PSScriptRoot
$repo = Split-Path (Split-Path $sp -Parent) -Parent
$LIB  = 'C:\Users\Designer\Desktop\2026\პროდუქტები'
$local = Join-Path $sp 'paths.local.ps1'
if (Test-Path $local) { . $local }
if (-not (Test-Path -LiteralPath $LIB)) { throw "Product library not found:`n  $LIB" }

# Folders the user has marked off-limits, plus the pictogram sheets (dimension
# line-drawings, excluded by choice) and the image-only folders.
$SKIPDIR = 'DO NOT TOUCH|DONT TOUCH|პიქტოგრამები|საიმიჯო'
# Anything commercial must never be published. "Untitled" and " copy" are the
# designer's working files sitting beside the real brochure -- the 54.7 MB
# Untitled-2.pdf is a duplicate of a 4.8 MB range brochure.
$SKIPFILE = 'price|pricelist|прайс|ფასი|ფასები|^Untitled| copy\.pdf$'
# Two files in the library were downloaded from manualslib.com and carry that
# site's branding on every page. They are third-party re-hosts of the
# manufacturer's manual, so they are not ours to republish -- get the originals
# from Riello and Beretta instead.
$SCRAPES = @('Riello Start kis.pdf', 'idra_bv_2001000.pdf')
# Not buyer documentation: Riello's spare-parts catalogue for the Gulliver BS
# burners, part numbers for service engineers, sitting beside the manual.
$NOTDOCS = @('BS1-2-3-4_2908117-4.pdf')

$CATS = @{
  'ქვაბები'        = 'boilers'
  'ბოილერები'      = 'water-heaters'
  'ვენტილაცია'     = 'vortice'
  'კონდინციონერები' = 'ac'
  'რადიატორები'    = 'radiators'
}

# ---- folder -> slug table, assembled from the existing generators
# Entries are emitted to the pipeline rather than appended to a variable: `+=`
# inside a function writes a function-local copy, so the additions never reach
# the caller.
$MAP = New-Object System.Collections.ArrayList
function Fam($cat, $file, $prefix) {
  $p = Join-Path $repo $file
  if (-not (Test-Path $p)) { throw "missing $file" }
  foreach ($f in (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json)) {
    foreach ($d in $f.imgdirs) {
      [void]$MAP.Add(@{ cat = $cat; dir = ($prefix + ($d -replace '/', '\')); slugs = @($f.slug); ord = $MAP.Count })
    }
  }
}
Fam 'ქვაბები'    'tools\boilers\families.json'        ''
Fam 'ბოილერები'  'tools\water-heaters\families.json'  ''
# Vortice imgdirs are prefixes of folders directly under ვენტილაცია\Vortice
Fam 'ვენტილაცია' 'tools\vortice\vortice-families.json' 'Vortice\'
$m = Get-Content (Join-Path $sp 'map.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($cat in ($m.PSObject.Properties.Name | Where-Object { -not $_.StartsWith('_') })) {
  foreach ($e in $m.$cat) {
    [void]$MAP.Add(@{ cat = $cat; dir = $e.dir; slugs = @($e.slugs); ord = $MAP.Count; pinned = $true })
  }
}
# Longest folder first, so "…კედლის WindFree" wins over "…კედლის".
#
# Two families can also claim the very same folder -- LINEO and LINEO QUIET both
# list LINEO_Q -- and the folder cannot say which page its documents are for.
# Each such folder is pinned to one page in map.json, and the pin wins the tie.
# An unpinned one falls back to the family declared first and is reported below.
# The tie has to be broken explicitly: Sort-Object in Windows PowerShell is not
# stable, so on length alone the winner depended on how many entries the table
# held, and adding two burners to boilers/families.json moved the LINEO_Q
# documents from LINEO QUIET to LINEO.
$MAP = @($MAP | Sort-Object @{ e = { -($_.dir.Length) } }, @{ e = { if ($_.pinned) { 0 } else { 1 } } }, @{ e = { $_.ord } })
foreach ($shared in ($MAP | Group-Object { $_.cat + '\' + $_.dir } | Where-Object { $_.Count -gt 1 })) {
  $winner = $shared.Group[0]
  if ($winner.pinned) {
    Write-Host ('shared folder {0}: pinned to {1} in map.json' -f $shared.Name, ($winner.slugs -join ','))
  } else {
    Write-Host ('WARNING shared folder {0} is claimed by {1} -- pin it in map.json; {2} wins for now, as the one declared first' -f
                $shared.Name, (($shared.Group | ForEach-Object { $_.slugs -join ',' }) -join ' and '), ($winner.slugs -join ','))
  }
}

# ---- Vortice: the article code beats the folder
# The Vortice library files each model in a folder of its own, named for its
# article code ("17170 LINEO 100 QUIET ES ..."), inside a range folder that can
# feed several pages -- LINEO_Q holds LINEO, LINEO Q, LINEO QUIET, QUIET ES and
# T QUIET. The code in the path is the more specific of the two, so where the
# priced list knows it, the page that code's model is on gets the document; the
# folder table above only decides for files outside a model folder (range
# brochures) and for codes nobody prices.
$VCODE = @{}
foreach ($vm in (Get-Content (Join-Path $repo 'tools\vortice\vortice-pages.json') -Raw -Encoding UTF8 | ConvertFrom-Json)) {
  if ($vm.slug) { $VCODE[[string]$vm.code] = [string]$vm.slug }
}
function CodeSlug($rel) {
  foreach ($seg in ($rel -split '\\')) {
    $cm = [regex]::Match($seg, '^(\d{4,6}) ')
    if ($cm.Success -and $VCODE.ContainsKey($cm.Groups[1].Value)) { return $VCODE[$cm.Groups[1].Value] }
  }
  return ''
}

# ---- classify by filename. Order matters: a Vortice safety leaflet is called
#      "…Libretti_Istruzioni_838-Avvertenze_Sicurezza…", so safety is tested
#      before the instruction booklet it is named after.
function Classify($name) {
  if ($name -match 'Avvertenze_Sicurezza|safety')                  { return 'safety'    }
  if ($name -match 'Schemi|_Sch\.pdf|кривая|Пульт')                { return 'wiring'    }
  # Vortice files named for the bare article code are its Technical Data Sheet,
  # and the "de-" prefix is not German but "dati energetici" -- page one reads
  # "ENERGY DATA / CODE 12001 / ARIETT HABITAT 20/75 LL". Both checked by
  # reading the files, not inferred from the names.
  if ($name -match '^de-0+\d+')                                    { return 'energy'    }
  if ($name -match '^0+\d+( \(\d+\))?\.pdf$|scheda-tecnica')       { return 'datasheet' }
  if ($name -match 'Doc_Pubblicita|brochure|flyer|depliant|catalog|katalog|каталог|commercial sheet|Guide-|_guide_') { return 'brochure' }
  if ($name -match 'Libret|Istruzioni')                            { return 'booklet'   }
  if ($name -match '_IM_|Installation|Installer|montaj')           { return 'install'   }
  if ($name -match '(^|_)OM_|_IB_|User.Manual|kullanim')           { return 'user'      }
  return 'other'
}

$rows = New-Object System.Collections.ArrayList
$unmapped = New-Object System.Collections.ArrayList
$hashes = @{}

foreach ($catName in $CATS.Keys) {
  $catRoot = Join-Path $LIB $catName
  if (-not (Test-Path -LiteralPath $catRoot)) { continue }
  $pdfs = Get-ChildItem -LiteralPath $catRoot -Recurse -File -Filter '*.pdf' -EA SilentlyContinue |
          Where-Object { $_.FullName -notmatch $SKIPDIR -and $_.Name -notmatch $SKIPFILE -and
                         $SCRAPES -notcontains $_.Name -and $NOTDOCS -notcontains $_.Name }
  foreach ($pdf in $pdfs) {
    # path below the category folder, which is what the map matches against
    $rel = $pdf.FullName.Substring($catRoot.Length).TrimStart('\')
    $hit = $MAP | Where-Object { $_.cat -eq $catName -and $rel.StartsWith($_.dir) } | Select-Object -First 1
    if ($catName -eq 'ვენტილაცია') {
      $cs = CodeSlug $rel
      if ($cs) { $hit = @{ slugs = @($cs) } }
    }
    $h = (Get-FileHash -LiteralPath $pdf.FullName -Algorithm MD5).Hash
    if (-not $hit) {
      [void]$unmapped.Add([pscustomobject]@{ cat = $catName; rel = $rel; mb = [math]::Round($pdf.Length/1MB,1) })
      continue
    }
    [void]$rows.Add([pscustomobject]@{
      hash  = $h
      src   = $pdf.FullName
      name  = $pdf.Name
      mb    = [math]::Round($pdf.Length/1MB, 2)
      class = Classify $pdf.Name
      cat   = $CATS[$catName]
      slugs = $hit.slugs
    })
    if (-not $hashes.ContainsKey($h)) { $hashes[$h] = $pdf.Length }
  }
}

# ---- report
Write-Host ''
Write-Host ('mapped   : {0} document references, {1} distinct files, {2:N0} MB of distinct files' -f
            $rows.Count, $hashes.Keys.Count, (($hashes.Values | Measure-Object -Sum).Sum / 1MB))
Write-Host ('unmapped : {0} files, {1:N0} MB' -f $unmapped.Count, (($unmapped | Measure-Object -Property mb -Sum).Sum))
Write-Host ''
Write-Host 'by class (distinct files):'
$rows | Group-Object hash | ForEach-Object { $_.Group[0] } | Group-Object class |
  Sort-Object Count -Descending |
  ForEach-Object { '  {0,-9} {1,4} files  {2,7:N1} MB' -f $_.Name, $_.Count,
                   (($_.Group | Measure-Object -Property mb -Sum).Sum) }
Write-Host ''
Write-Host 'pages with at least one document:'
$bySlug = @{}
foreach ($r in $rows) { foreach ($s in $r.slugs) { if (-not $bySlug[$s]) { $bySlug[$s] = 0 }; $bySlug[$s]++ } }
Write-Host ('  {0} of 75 product pages' -f $bySlug.Keys.Count)
Write-Host ''
Write-Host 'too big to host comfortably (>8 MB before compression):'
$rows | Group-Object hash | ForEach-Object { $_.Group[0] } | Where-Object { $_.mb -gt 8 } |
  Sort-Object mb -Descending |
  ForEach-Object { '  {0,6:N1} MB  {1}' -f $_.mb, $_.name }

$rows     | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $sp 'docs.json')     -Encoding UTF8
$unmapped | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $sp 'unmapped.json') -Encoding UTF8
Write-Host ''
Write-Host 'wrote tools/docs/docs.json and tools/docs/unmapped.json'
