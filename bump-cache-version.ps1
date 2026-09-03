# Refresh the ?v= tag on style.css / main.js in every page.
#
# GitHub Pages serves these files with no version in the URL, so a returning
# visitor's browser keeps its cached copy and a change can be live but
# invisible to them. Stamping a new ?v= on each publish forces a fresh fetch.
#
# Called by "Update Website.bat" before it commits.

# Only stamp when the files the tag exists to bust have actually changed.
#
# Stamping a fresh timestamp on every run rewrote all 45 pages each time, so the
# publish script always saw "changes" and made a commit full of nothing but new
# ?v= numbers - and its "nothing to commit" branch could never be reached.
# Pass -Force to stamp regardless.
$assets = @('assets/css/style.css', 'assets/js/main.js')
if ($args -notcontains '-Force') {
  Push-Location $PSScriptRoot
  git diff --quiet HEAD -- $assets 2>$null
  $assetsChanged = ($LASTEXITCODE -ne 0)   # non-zero also covers "no git / no HEAD", so we stamp
  Pop-Location
  if (-not $assetsChanged) {
    Write-Host "   Cache tag: unchanged - style.css / main.js not edited since the last publish"
    return
  }
}

$ver = Get-Date -Format 'yyyyMMddHHmm'
$changed = 0

Get-ChildItem -Path $PSScriptRoot -Recurse -Filter *.html |
  Where-Object { $_.FullName -notmatch '\\backup|_files|\\\.claude\\' } |
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
