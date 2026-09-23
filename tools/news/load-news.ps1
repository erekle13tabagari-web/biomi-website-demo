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

# ---- Markdown, the small part of it the editor's buttons can produce
function MdInline([string]$s) {
  # \* \_ \[ and friends are literal characters: park them in private-use code
  # points so the rules below cannot read them as markup
  $s = [regex]::Replace($s, '\\([\\`*_{}\[\]()#+\-.!~|])', { param($m) [string][char](0xE000 + [int][char]$m.Groups[1].Value) })
  $s = $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
  $s = [regex]::Replace($s, '\[([^\]]+)\]\(([^)\s]+)\)', {
    param($m)
    $u = $m.Groups[2].Value.Replace('"', '%22')
    $ext = if ($u -match '^https?://') { ' target="_blank" rel="noopener"' } else { '' }
    '<a href="' + $u + '"' + $ext + '>' + $m.Groups[1].Value + '</a>'
  })
  $s = [regex]::Replace($s, '\*\*(.+?)\*\*', '<strong>$1</strong>')
  $s = [regex]::Replace($s, '__(.+?)__', '<strong>$1</strong>')
  $s = [regex]::Replace($s, '(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])', '<em>$1</em>')
  $s = [regex]::Replace($s, '(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?![\w_])', '<em>$1</em>')
  $s = [regex]::Replace($s, '[-]', {
    param($m) $c = [string][char]([int][char]$m.Value - 0xE000); if ($c -eq '>') { '&gt;' } else { $c }
  })
  return $s
}

function ConvertFrom-NewsMarkdown([string]$md) {
  $out = New-Object System.Collections.Generic.List[string]
  if (-not $md) { return ,$out.ToArray() }
  $text = ($md -replace "`r`n", "`n").Trim()
  foreach ($block in [regex]::Split($text, '\n[ \t]*\n')) {
    $b = $block.Trim("`n", ' ', "`t")
    if (-not $b) { continue }
    if ($b -eq 'FIGURE') { $out.Add('FIGURE'); continue }
    $lines = @($b -split '\n')
    if ($lines.Count -eq 1 -and $b -match '^(#{2,3})\s+(.+?)\s*#*$') {
      $lvl = $Matches[1].Length
      $out.Add('<h' + $lvl + '>' + (MdInline $Matches[2]) + '</h' + $lvl + '>'); continue
    }
    if (-not ($lines | Where-Object { $_ -notmatch '^\s*[-*+]\s+' })) {
      $out.Add('<ul>')
      foreach ($l in $lines) { $out.Add('  <li>' + (MdInline ($l -replace '^\s*[-*+]\s+', '')) + '</li>') }
      $out.Add('</ul>'); continue
    }
    if (-not ($lines | Where-Object { $_ -notmatch '^\s*\d+[.)]\s+' })) {
      $out.Add('<ol>')
      foreach ($l in $lines) { $out.Add('  <li>' + (MdInline ($l -replace '^\s*\d+[.)]\s+', '')) + '</li>') }
      $out.Add('</ol>'); continue
    }
    # one paragraph; a line ending in two spaces or a backslash is a line break
    $p = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $l = $lines[$i]
      $brk = $l -match '(  |\\)$'
      $l = ($l -replace '(  |\\)$', '').Trim()
      $p += (MdInline $l)
      if ($i -lt $lines.Count - 1) { $p += $(if ($brk) { '<br>' } else { ' ' }) }
    }
    $out.Add('<p>' + $p + '</p>')
  }
  return ,$out.ToArray()
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
        h1       = [string]$t.h1
        crumb    = $(if ($t.crumb) { [string]$t.crumb } else { [string]$t.h1 })
        title    = $(if ($t.title) { [string]$t.title } else { [string]$t.h1 + $suffix })
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
