# The projects, for 2-images.ps1 and build-projects.ps1 (dot-source this file
# after setting $repo).
#
# Since 2026-10-01 each project is one file, content/projects/<slug>.json,
# written by hand or through the editor at /admin (Decap CMS), like the news
# articles. It replaced tools/projects/projects.json, which held five of the
# eight projects; ORO, PASHA and Terminal were pages written by hand. All eight
# are built from their files now. The builders get items shaped as:
#
#   slug, order, hero, heroUpload, logo, logoUpload, lockup, logoHeight, video,
#   gallery[] (uploaded source files), src (the photo folder under "Projects files"),
#   ka/en { card, crumb, title, desc, h1, sub, cat, alt, cap, lead, body[] }
#
# - body is the same simple Markdown as the news (tools/markdown.ps1). A quote's
#   attribution keeps the "- " the project pages have always printed.
# - Pictures uploaded in the editor land in assets/img/uploads/. They get the
#   project's own names, which 2-images.ps1 produces: proj-<slug>.jpg (hero),
#   clients/<slug>.svg|png (logo), <slug>-gallery/ (gallery). A picture already
#   in assets/img keeps its name.
# - Left empty, the optional texts default to: crumb = headline, card = crumb,
#   title = headline + " - ბიომი", description = lead, photo description =
#   headline.
# - Ordered by "order" (1 comes first on the homepage), then by slug.

$PROJDIR   = Join-Path $repo 'content\projects'
$UPLOADPFX = '/assets/img/uploads/'
. (Join-Path $repo 'tools\markdown.ps1')

function ProjImgName([string]$p) { return ($p -replace '^/?assets/img/', '') }
function IsUpload([string]$p) { return ($p -and $p.StartsWith($UPLOADPFX)) }

# A YouTube link in any of its shapes, or the bare 11-character id
function YouTubeId([string]$v) {
  $v = $v.Trim()
  if (-not $v) { return '' }
  if ($v -match '^[A-Za-z0-9_-]{11}$') { return $v }
  $m = [regex]::Match($v, '(?:youtu\.be/|[?&]v=|/embed/|/shorts/|/live/)([A-Za-z0-9_-]{11})')
  if ($m.Success) { return $m.Groups[1].Value }
  throw ('not a YouTube link: ' + $v)
}

function Get-ProjectItems {
  $items = @()
  foreach ($f in (Get-ChildItem $PROJDIR -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
    $j = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $slug = [string]$j.slug
    if (-not $slug) { $slug = $f.BaseName }
    if ($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw ('bad slug "' + $slug + '" in ' + $f.Name) }
    # a project and a news article would share assets/img/<slug>-gallery
    if (Test-Path (Join-Path $repo ('content\news\' + $slug + '.json'))) {
      throw ('project "' + $slug + '" has the same address as a news article - give one of them another')
    }

    $heroRaw = [string]$j.hero
    $logoRaw = [string]$j.logo
    $it = [ordered]@{
      slug       = $slug
      order      = $(if ($j.order) { [int]$j.order } else { 999 })
      hero       = $(if (IsUpload $heroRaw) { 'proj-' + $slug + '.jpg' } else { ProjImgName $heroRaw })
      heroUpload = $(if (IsUpload $heroRaw) { $heroRaw.TrimStart('/') } else { '' })
      # an uploaded SVG stays a vector; any other picture becomes a PNG
      logo       = $(if (IsUpload $logoRaw) { 'clients/' + $slug + $(if ($logoRaw -match '\.svg$') { '.svg' } else { '.png' }) }
                     elseif ($logoRaw) { ProjImgName $logoRaw } else { '' })
      logoUpload = $(if (IsUpload $logoRaw) { $logoRaw.TrimStart('/') } else { '' })
      # a stacked logo (mark over text) needs the taller chip; logoHeight sets
      # the height in px when neither of the two standard ones suits the mark
      lockup     = [bool]$j.lockup
      logoHeight = $(if ($j.logoHeight) { [int]$j.logoHeight } else { 0 })
      video      = (YouTubeId ([string]$j.video))
      gallery    = @(@($j.gallery) | Where-Object { $_ } | ForEach-Object { ([string]$_).TrimStart('/') })
      src        = [string]$j.src
    }
    if (-not $it.hero) { throw ('no main photo in ' + $f.Name) }
    foreach ($lang in 'ka', 'en') {
      $t = $j.$lang
      if (-not $t -or -not $t.h1) { throw ('no ' + $lang + ' headline in ' + $f.Name) }
      $suffix = if ($lang -eq 'ka') { ' - ბიომი' } else { ' - Biomi' }
      $h1    = ([string]$t.h1).Trim()
      $crumb = $(if ($t.crumb) { [string]$t.crumb } else { $h1 })
      $it[$lang] = [pscustomobject]@{
        h1    = $h1
        sub   = [string]$t.sub
        cat   = [string]$t.cat
        crumb = $crumb
        # the name on the homepage card and the projects page
        card  = $(if ($t.card) { [string]$t.card } else { $crumb })
        title = $(if ($t.title) { [string]$t.title } else { $h1 + $suffix })
        desc  = $(if ($t.desc) { [string]$t.desc } else { ([string]$t.lead -replace '\s+', ' ').Trim() })
        alt   = $(if ($t.alt) { [string]$t.alt } else { $h1 })
        cap   = [string]$t.cap
        lead  = [string]$t.lead
        body  = (ConvertFrom-NewsMarkdown ([string]$t.body) -CiteDash)
      }
    }
    $items += [pscustomobject]$it
  }
  return @($items | Sort-Object @{ e = { $_.order } }, @{ e = { $_.slug } })
}
