# Refresh the ?v= tag on style.css / main.js / favicon.svg in every page.
#
# GitHub Pages serves these files with no version in the URL, so a returning
# visitor's browser keeps its cached copy and a change can be live but
# invisible to them. Stamping a new ?v= on each publish forces a fresh fetch.
#
# Called by "Update Website.bat" before it commits.

# Only stamp when the files the tag exists to bust have actually changed.
#
# The favicon is here for the same reason as the other two, and needs it more:
# publish script always saw "changes" and made a commit full of nothing but new
# ?v= numbers - and its "nothing to commit" branch could never be reached.
# Pass -Force to stamp regardless.
$assets = @('assets/css/style.css', 'assets/js/main.js', 'assets/img/favicon.svg')
if ($args -notcontains '-Force') {
  Push-Location $PSScriptRoot
  # Compare against what is actually PUBLISHED, not against HEAD.
  #
  # This read HEAD and got it wrong every time. Work is committed as it is done
  # and the site is published later, so by the time this runs the working tree
  # is clean: "git diff HEAD" reports no change however far the stylesheet has
  # moved since the last push, and the tag never moves.
  #
  # That shipped a release where the about page carried new markup and every
  # page still asked for the previous ?v=. The new CSS was sitting on the
  # server; returning visitors kept the stylesheet they already had, so the
  # cycle badges arrived unstyled and rendered at full page width.
  #
  # origin/main is the published state. Fetch first, since the publish script
  # does not fetch until after this runs.
  git fetch origin main --quiet 2>$null
  $base = 'origin/main'
  git rev-parse --verify --quiet origin/main > $null 2>&1
  if ($LASTEXITCODE -ne 0) { $base = 'HEAD' }   # no remote yet: fall back
  git diff --quiet $base -- $assets 2>$null
  $assetsChanged = ($LASTEXITCODE -ne 0)   # non-zero also covers "no git", so we stamp
  Pop-Location
  if (-not $assetsChanged) {
    Write-Host "   Cache tag: unchanged - style.css / main.js match what is published"
    return
  }
}

$ver = Get-Date -Format 'yyyyMMddHHmm'
$changed = 0

Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *.html |
  Where-Object { $_.FullName -notmatch '\\backup|_files|\\\.claude\\' } |
  ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    # matches style.css, main.js or favicon.svg, with or without an existing ?v=
    $new = [regex]::Replace(
      $text,
      '(assets/(?:css/style\.css|js/main\.js|img/favicon\.svg))(\?v=[^"]*)?"',
      { param($m) $m.Groups[1].Value + '?v=' + $ver + '"' }
    )
    if ($new -ne $text) {
      Set-Content -LiteralPath $_.FullName -Value $new -NoNewline -Encoding UTF8
      $changed++
    }
  }

Write-Host "   Cache tag: v=$ver  ($changed pages)"
