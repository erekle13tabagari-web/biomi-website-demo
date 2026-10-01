# Markdown for the content files the editor at /admin writes (Decap CMS):
# the small part of it the editor's buttons can produce. Dot-sourced by
# tools/news/load-news.ps1 and tools/projects/load-projects.ps1, so a news
# article and a project page read their text the same way.
#
# ConvertFrom-NewsMarkdown returns the HTML lines: paragraphs, ## / ### headings,
# bold, italic, links, bullet and numbered lists, quotes (">" lines, a last line
# starting with a dash names who said it), and two markers kept for the builder:
# a paragraph FIGURE, and VIDEO:<YouTube id> from "VIDEO <link>".

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

# -CiteDash keeps "- " in front of a quote's attribution: the project pages
# have always printed it, the news articles never have.
function ConvertFrom-NewsMarkdown([string]$md, [switch]$CiteDash) {
  $out = New-Object System.Collections.Generic.List[string]
  if (-not $md) { return ,$out.ToArray() }
  $text = ($md -replace "`r`n", "`n").Trim()
  foreach ($block in [regex]::Split($text, '\n[ \t]*\n')) {
    $b = $block.Trim("`n", ' ', "`t")
    if (-not $b) { continue }
    if ($b -eq 'FIGURE') { $out.Add('FIGURE'); continue }
    # "VIDEO <YouTube link>" on its own: the builder turns it into the same
    # privacy-mode 16:9 player the project pages use
    if ($b -match '^VIDEO\s+(\S+)$') {
      $vid = [regex]::Match(($Matches[1] -replace '&amp;', '&'), '(?:youtu\.be/|[?&]v=|/embed/|/shorts/)([A-Za-z0-9_-]{11})')
      if ($vid.Success) { $out.Add('VIDEO:' + $vid.Groups[1].Value) }
      continue
    }
    $lines = @($b -split '\n')
    # a quote: every line starts with ">"; a last line starting with a dash is
    # who said it, and becomes the quote's attribution
    if (-not ($lines | Where-Object { $_ -notmatch '^\s*>' })) {
      $ql = @($lines | ForEach-Object { ($_ -replace '^\s*>\s?', '').Trim() } | Where-Object { $_ })
      $cite = ''
      if ($ql.Count -gt 1 -and $ql[-1] -match '^(—|–|-)\s*(.+)$') { $cite = $Matches[2]; $ql = @($ql[0..($ql.Count - 2)]) }
      $q = '<blockquote><p>' + (($ql | ForEach-Object { MdInline $_ }) -join ' ') + '</p>'
      if ($cite) { $q += '<cite>' + $(if ($CiteDash) { '- ' } else { '' }) + (MdInline $cite) + '</cite>' }
      $out.Add($q + '</blockquote>'); continue
    }
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

