# Refresh the ?v= tag on style.css / main.js in every page.
#
# GitHub Pages serves these files with no version in the URL, so a returning
# visitor's browser keeps its cached copy and a change can be live but
# invisible to them. Stamping a new ?v= on each publish forces a fresh fetch.
#
# Called by "Update Website.bat" before it commits.

$ver = Get-Date -Format 'yyyyMMddHHmm'
$changed = 0

Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *.html |
  Where-Object { $_.FullName -notmatch '\\backup|_files' } |
  ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    # matches assets/css/style.css or assets/js/main.js, with or without an existing ?v=
    $new = [regex]::Replace(
      $text,
      '(assets/(?:css/style\.css|js/main\.js))(\?v=[^"]*)?"',
      { param($m) $m.Groups[1].Value + '?v=' + $ver + '"' }
    )
    if ($new -ne $text) {
      Set-Content -LiteralPath $_.FullName -Value $new -NoNewline -Encoding UTF8
      $changed++
    }
  }

Write-Host "   Cache tag: v=$ver  ($changed pages)"
