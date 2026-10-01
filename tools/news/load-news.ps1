# The news articles, for 1-images.ps1 and build-news.ps1 (dot-source this file
# after setting $repo).
#
# Since 2026-09-22 each article is one file, content/news/<slug>.json, written
# by hand or through the editor at /admin (Decap CMS). This replaced
# tools/news/news.json, whose list the editor could not open. The builders
# still get items shaped the way they always used them:
#
#   slug, date, hero, figures[] { img, from, upload, ka{alt,cap}, en{alt,cap} },
#   gallery[] (uploaded source files), src (legacy source folder), heroUpload,
#   ka/en { cat, crumb, title, desc, h1, dateText, alt, cap, lead, body[] }
#
# - body is written as simple Markdown in the file (paragraphs, ## / ###
#   headings, bold, italic, links, lists) and handed on as HTML lines. A
#   paragraph that is exactly FIGURE stays FIGURE: the next captioned photo.
# - Pictures uploaded in the editor land in assets/img/uploads/. Those get the
#   article's own names (news-<slug>.jpg, news-<slug>-fig<n>.jpg, the gallery
#   folder), which 1-images.ps1 produces; a picture already in assets/img keeps
#   its name.
# - The fields an editor may leave empty get the defaults the old list always
#   spelled out: title = headline + " - ბიომი", description = lead, crumb =
#   headline, date text from the date.
# - Newest first, by date.

$NEWSDIR    = Join-Path $repo 'content\news'
$UPLOADPFX  = '/assets/img/uploads/'
$KA_MONTHS  = @('იანვარი','თებერვალი','მარტი','აპრილი','მაისი','ივნისი','ივლისი','აგვისტო','სექტემბერი','ოქტომბერი','ნოემბერი','დეკემბერი')
$EN_MONTHS  = @('January','February','March','April','May','June','July','August','September','October','November','December')

# ---- Markdown: MdInline and ConvertFrom-NewsMarkdown live in tools\markdown.ps1,
#      shared with the project pages (2026-10-01)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'markdown.ps1')

# A headline's line breaks: a new line breaks on every screen, {pc} only on a
# computer, {phone} only on a phone. H1Plain is the one-line text for the tab
# title, cards and breadcrumb; H1Html the article's own heading, where each
# break is " <br>" so a hidden one still leaves a space between the words.
function H1Plain([string]$s) {
  return (($s -replace '\{(pc|phone)\}', ' ' -replace '\s*\r?\n\s*', ' ') -replace '\s{2,}', ' ').Trim()
}
function H1Html([string]$s) {
  $lines = @(($s.Trim() -split '\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $h = ($lines -join ' <br>')
  $h = $h -replace '\s*\{pc\}\s*', ' <br class="br-pc">' -replace '\s*\{phone\}\s*', ' <br class="br-phone">'
  return ($h -replace '[ ]{2,}', ' ').Trim()
}

# "/assets/img/x.jpg" -> "x.jpg"; an upload keeps its full repo path
function NewsImgName([string]$p) { return ($p -replace '^/?assets/img/', '') }
function IsUpload([string]$p) { return ($p -and $p.StartsWith($UPLOADPFX)) }

function DateText([string]$date, [string]$lang) {
  $d = [datetime]::ParseExact($date.Substring(0, 10), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  if ($lang -eq 'ka') { return ('' + $d.Day + ' ' + $KA_MONTHS[$d.Month - 1] + ', ' + $d.Year) }
  return ('' + $d.Day + ' ' + $EN_MONTHS[$d.Month - 1] + ' ' + $d.Year)   # "15 March 2025", as the articles write it
}

function Get-NewsItems {
  $items = @()
  foreach ($f in (Get-ChildItem $NEWSDIR -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
    $j = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $slug = [string]$j.slug
    if (-not $slug) { $slug = $f.BaseName }
    if ($slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw ('bad slug "' + $slug + '" in ' + $f.Name) }
    $date = ([string]$j.date).Substring(0, 10)

    $heroRaw = [string]$j.hero
    $it = [ordered]@{
      slug = $slug; date = $date; src = [string]$j.src
      hero = $(if (IsUpload $heroRaw) { 'news-' + $slug + '.jpg' } else { NewsImgName $heroRaw })
      heroUpload = $(if (IsUpload $heroRaw) { $heroRaw.TrimStart('/') } else { '' })
      gallery = @(@($j.gallery) | Where-Object { $_ } | ForEach-Object { ([string]$_).TrimStart('/') })
      # where the story was first published: a link in the article's closing row
      source = [string]$j.source
      # an office folder's "Main gallery" is used unless the file says false
      folderGallery = -not ($j.PSObject.Properties['folderGallery'] -and $j.folderGallery -eq $false)
      figures = @()
    }
    $n = 0
    foreach ($fg in @($j.figures)) {
      if (-not $fg) { continue }
      $n++
      $raw = [string]$fg.image
      $it.figures += [pscustomobject]@{
        img    = $(if (IsUpload $raw) { 'news-' + $slug + '-fig' + $n + '.jpg' } else { NewsImgName $raw })
        upload = $(if (IsUpload $raw) { $raw.TrimStart('/') } else { '' })
        from   = [string]$fg.from
        # a tall picture (a portrait) sits beside the text instead of across it
        portrait = [bool]$fg.portrait
        ka     = $fg.ka
        en     = $fg.en
      }
    }
    foreach ($lang in 'ka', 'en') {
      $t = $j.$lang
      if (-not $t) { throw ('no ' + $lang + ' text in ' + $f.Name) }
      $suffix = if ($lang -eq 'ka') { ' - ბიომი' } else { ' - Biomi' }
      $it[$lang] = [pscustomobject]@{
        cat      = [string]$t.cat
        # A line break typed into the headline is kept for the article's own
        # heading (h1Lines) and read as a space everywhere else: tab title,
        # breadcrumb, news cards (2026-09-30, the rebrand headline's 3 lines).
        # {pc} and {phone} are breaks for one screen size only (the rebrand
        # headline wraps differently on a phone); both read as spaces here.
        h1       = (H1Plain ([string]$t.h1))
        h1Html   = (H1Html ([string]$t.h1))
        crumb    = $(if ($t.crumb) { [string]$t.crumb } else { H1Plain ([string]$t.h1) })
        title    = $(if ($t.title) { [string]$t.title } else { (H1Plain ([string]$t.h1)) + $suffix })
        desc     = $(if ($t.desc) { [string]$t.desc } else { ([string]$t.lead -replace '\s+', ' ').Trim() })
        dateText = $(if ($t.dateText) { [string]$t.dateText } else { DateText $date $lang })
        alt      = [string]$t.alt
        cap      = [string]$t.cap
        lead     = [string]$t.lead
        body     = (ConvertFrom-NewsMarkdown ([string]$t.body))
      }
    }
    $items += [pscustomobject]$it
  }
  # newest first; the slug breaks a tie so the order is stable
  return @($items | Sort-Object @{ e = { $_.date }; Descending = $true }, @{ e = { $_.slug } })
}
