# Upload the website to ProService: the staging copy at https://test.biomi.ge
# ("Upload Test Site.bat") or the real site at https://biomi.ge
# ("Upload Live Site.bat"). Only files that changed since the last upload to
# that target are sent, and files deleted here are deleted there too (only ones
# this script uploaded - anything else on the server is left alone).
#
#   -Target test|live  where to (default test)
#   -DryRun            list what would be uploaded/deleted, connect to nothing
#   -Full              ignore the record of the last upload and send everything again
#   -ResetLogin        forget the saved FTP login and ask for it again
#   -Folder name       live only: the folder under the FTP account to upload into
#                      (default public_html; on go-live day, new_site - see below)
#   -FolderMoved       live only: the folder the last upload went into has since
#                      been renamed to -Folder, so its record still holds
#   -NoPdf             live only: leave out the product PDFs (disk space)
#   -Yes               live only: skip the "type biomi.ge" confirmation
#
# Go-live day: the live FTP account is rooted at /domains/biomi.ge (DirectAdmin's
# Custom directory "/domains/biomi.ge"), so the new site can be uploaded beside
# WordPress with -Folder new_site -Full, checked, and then swapped in by renaming
# public_html -> old_wordpress and new_site -> public_html in the File Manager.
# The next upload says -FolderMoved once and carries on from there.
#
# The FTP login is typed by the user into this console window and kept in
# %APPDATA%\Biomi, encrypted for this Windows account (DPAPI), one per target.
# It is never written into the project folder, so it can't end up on GitHub.
#
# ProService's firewall banned the office IP for an hour when FileZilla opened
# many connections at once, so this uses ONE connection, sends files one after
# another, and stops after a few failures in a row instead of hammering on.

param(
  [ValidateSet('test', 'live')][string]$Target = 'test',
  [switch]$DryRun, [switch]$Full, [switch]$ResetLogin,
  [string]$Folder = '', [switch]$FolderMoved, [switch]$NoPdf, [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $root
$Live = $Target -eq 'live'

$FtpHost  = 'ftp.biomi.ge'           # the certificate on this name is valid (checked 2026-09-15)
$ServerIp = '91.239.206.19'          # for the after-upload check while DNS is still catching up
$SiteHost = if ($Live) { 'biomi.ge' } else { 'test.biomi.ge' }
$store        = Join-Path $env:APPDATA 'Biomi'
$loginFile    = Join-Path $store ($Target + '-ftp-login.xml')
$manifestFile = Join-Path $store ($Target + '-site-manifest.json')
# The test account is rooted at the test site's public_html; the live one a
# level up, at the domain folder, for the go-live swap described above.
if (-not $Live -and $Folder) { Write-Host '   -Folder is for the live site only.' -ForegroundColor Red; exit 1 }
$RemoteDir = if ($Live) { if ($Folder) { $Folder.Trim('/') } else { 'public_html' } } else { '' }

# The PDFs didn't fit on the account (disk ~95% full, shared with the
# mailboxes), so the test copy carries one brochure to test downloads with.
# The live site takes them all once $LivePdfs is $true: that waits until the
# old WordPress folder (domains/biomi.ge/old_wordpress, ~3.7 GB) is deleted,
# because 292 MB of PDFs beside it could fill the disk the mailboxes need.
# Switched on 2026-09-22: the user deleted old_wordpress/wp-content/uploads
# (3.1 GB of the 3.7), which leaves room to spare; the rest of that folder
# stays, outside public_html and unreachable from the web.
$LivePdfs = $true
if ($Live -and -not $LivePdfs) { $NoPdf = [switch]$true }
$PdfAllow = @('assets/downloads/vortice-lineo-brochure.pdf')
# The only two font files the CSS uses; the rest of fonts/ is source material.
$FontAllow = @('fonts/Futura 100/Variable/Futura100-VF-Upright.ttf',
               'fonts/Futura 100 Georgian/Variable/Futura100-GEO-VF-Upright.ttf')
$AssetExt = @('html','css','js','json','avif','webp','jpg','jpeg','png','gif','svg','ico','pdf','woff2','woff','ttf','xml','txt')

function Say($text, $color = 'Gray') { Write-Host ('   ' + $text) -ForegroundColor $color }

# --------------------------------------------------------------- the .htaccess
# Both targets are generated here from the same pieces, so the redirects and
# headers tested on test.biomi.ge are the ones the live site gets.

# Old WordPress addresses -> new pages, from tools/deploy/redirects.tsv (built
# 2026-09-18 from the old site's database). Georgian paths are matched as
# written: mod_rewrite compares against the decoded address.
function Get-LegacyRules {
  $lines = [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'redirects.tsv'), [Text.Encoding]::UTF8)
  $rules = New-Object Collections.Generic.List[string]
  foreach ($l in $lines) {
    if (-not $l.Trim() -or $l.StartsWith('#')) { continue }
    $f = $l -split "`t"
    $from = $f[0].Trim().Trim('/'); $to = $f[1].Trim()
    if (-not $from -or -not $to) { continue }
    $rx = '^' + [regex]::Replace($from, '[.^$*+?()\[\]{}|\\]', '\$0') + '/?$'
    if ($to -eq '410') { $rules.Add('  RewriteRule ' + $rx + ' - [G,L]') }
    else { $rules.Add('  RewriteRule ' + $rx + ' ' + $to + ' [R=301,L,NE]') }
  }
  return $rules
}

function New-Htaccess {
  $h = New-Object Collections.Generic.List[string]
  if ($Live) {
    $h.Add('# biomi.ge - the Biomi website. Generated by tools/deploy/deploy-site.ps1;')
    $h.Add('# edit it there (or tools/deploy/redirects.tsv), not on the server.')
  } else {
    $h.Add('# test.biomi.ge - staging copy of the new Biomi website. Not for search engines.')
    $h.Add('# Generated by tools/deploy/deploy-site.ps1 - same rules as the live site.')
  }
  $h.Add('Options -Indexes')
  $h.Add('DirectoryIndex index.html')
  $h.Add('AddDefaultCharset UTF-8')
  $h.Add('AddType image/avif .avif')
  $h.Add('AddType image/webp .webp')
  $h.Add('AddType font/ttf .ttf')
  $h.Add('# The site''s own "page not found", in the language of the address asked for.')
  $h.Add('ErrorDocument 404 /404.html')
  $h.Add('<If "%{REQUEST_URI} =~ m#-en(\.html?)?/?$#">')
  $h.Add('  ErrorDocument 404 /404-en.html')
  $h.Add('</If>')
  $h.Add('<IfModule mod_rewrite.c>')
  $h.Add('  RewriteEngine On')
  if ($Live) {
    $h.Add('  # One address for the site: https://biomi.ge. The call-back service and the')
    $h.Add('  # form sender both expect it, and search engines should see one copy, not')
    $h.Add('  # four. NE keeps an encoded Georgian path from being encoded a second time.')
    $h.Add('  RewriteCond %{HTTPS} !=on [OR]')
    $h.Add('  RewriteCond %{HTTP_HOST} !^biomi\.ge$ [NC]')
    $h.Add('  RewriteRule ^ https://biomi.ge%{REQUEST_URI} [L,R=301,NE]')
  } else {
    $h.Add('  # Always https: the form sender refuses posts from an http:// page.')
    $h.Add('  RewriteCond %{HTTPS} !=on')
    $h.Add('  RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301,NE]')
  }
  $h.Add('  # ---- The old WordPress site''s addresses (tools/deploy/redirects.tsv)')
  foreach ($r in (Get-LegacyRules)) { $h.Add($r) }
  $h.Add('  # ---- Anything else from the old site: the nearest section, or gone')
  $h.Add('  RewriteRule ^(product|product-category|shop)(/|$) /products.html [R=301,L]')
  $h.Add('  RewriteRule ^portfolio(/|$) /projects.html [R=301,L]')
  $h.Add('  RewriteRule ^(category|tag|brand|author|project-cat)/ - [G,L]')
  $h.Add('  RewriteRule ^(.*/)?feed/?$ - [G,L]')
  $h.Add('  RewriteRule ^(wp-admin|wp-content|wp-includes|wp-json|wp-login\.php|xmlrpc\.php)(/|$) - [G,L]')
  $h.Add('  RewriteRule ^en(/.*)?$ /index-en.html [R=301,L]')
  $h.Add('  RewriteRule ^ru(/.*)?$ / [R=301,L]')
  $h.Add('  # WordPress addresses by number or query (?p=12, ?page_id=47, ?product=...)')
  $h.Add('  RewriteCond %{QUERY_STRING} (^|&)(p|page_id|product|portfolio|post_type|s|add-to-cart)= [NC]')
  $h.Add('  RewriteRule ^$ /? [R=301,L]')
  $h.Add('</IfModule>')
  $h.Add('<IfModule mod_headers.c>')
  $h.Add('  # Browser-side protections the site had none of (review, 2026-09-17)')
  $h.Add('  Header always set Strict-Transport-Security "max-age=31536000"')
  $h.Add('  Header always set X-Content-Type-Options "nosniff"')
  $h.Add('  Header always set X-Frame-Options "SAMEORIGIN"')
  $h.Add('  Header always set Referrer-Policy "strict-origin-when-cross-origin"')
  $h.Add('  Header always set Permissions-Policy "camera=(), microphone=(), payment=(), usb=()"')
  $h.Add('  Header always unset X-Powered-By')
  if ($Live) {
    $h.Add('  # Pages, styles and scripts are checked for a newer copy on every visit (a')
    $h.Add('  # cheap "not modified" when nothing changed); images and fonts are reused for')
    $h.Add('  # a week / a month. Short enough for a photo replaced under the same name.')
    $h.Add('  <FilesMatch "\.(html|css|js|json|xml|txt)$">')
    $h.Add('    Header set Cache-Control "no-cache"')
    $h.Add('  </FilesMatch>')
    $h.Add('  <FilesMatch "\.(avif|webp|jpe?g|png|gif|svg|ico|pdf)$">')
    $h.Add('    Header set Cache-Control "public, max-age=604800"')
    $h.Add('  </FilesMatch>')
    $h.Add('  <FilesMatch "\.(ttf|woff2?)$">')
    $h.Add('    Header set Cache-Control "public, max-age=2592000"')
    $h.Add('  </FilesMatch>')
    $h.Add('  # ...except a style, script or tab icon asked for with its ?v= tag: that tag')
    $h.Add('  # changes whenever the file does (bump-cache-version.ps1), so a tagged copy')
    $h.Add('  # can be kept for a year without the per-page check (SEO audit, 2026-09-21).')
    $h.Add('  # <If> is applied after <FilesMatch>, so this wins where both match.')
    $h.Add('  <If "%{QUERY_STRING} =~ /(^|&)v=/ && %{REQUEST_URI} =~ /\.(css|js|svg)$/">')
    $h.Add('    Header set Cache-Control "public, max-age=31536000, immutable"')
    $h.Add('  </If>')
  } else {
    $h.Add('  Header set X-Robots-Tag "noindex, nofollow"')
    $h.Add('  <FilesMatch "\.(html|css|js|json)$">')
    $h.Add('    Header set Cache-Control "no-cache"')
    $h.Add('  </FilesMatch>')
  }
  $h.Add('</IfModule>')
  return (($h -join "`n") + "`n")
}

# Files generated here rather than taken from the project. The test copy gets a
# robots.txt that shuts search engines out; the live site uses the project's own
# (build-meta.ps1 writes it, with the sitemap address).
$Generated = [ordered]@{}
if (-not $Live) { $Generated['robots.txt'] = "User-agent: *`nDisallow: /`n" }
$Generated['.htaccess'] = New-Htaccess

# Pages build-meta.ps1 keeps hidden (noindex, out of the sitemap and search) are
# not uploaded at all - on the server "hidden" means not there, so no stray link
# can open one (the service page did, from the projects menu, 2026-09-15).
# Read from build-meta's own $HIDDEN line so there is one list, not two.
$Hidden = @()
$metaSrc = [IO.File]::ReadAllText((Join-Path $root 'tools\build-meta.ps1'))
if ($metaSrc -match '(?m)^\$HIDDEN\s*=\s*(.+)$') {
  $Hidden = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
}

# The live site must not go up still telling search engines that the real pages
# are the GitHub demo: every canonical, share card and the sitemap come from
# build-meta.ps1's $BASE, which is switched to https://biomi.ge on go-live day.
if ($Live) {
  $ix = [IO.File]::ReadAllText((Join-Path $root 'index.html'))
  if ($ix -notmatch '<link rel="canonical" href="https://biomi\.ge/') {
    Say 'Not uploaded: the pages still name the GitHub demo as their address.' Red
    Say 'Set $BASE in tools\build-meta.ps1 to https://biomi.ge, run build-meta.ps1,' Red
    Say 'then upload again.' Red
    exit 1
  }
}

# ---------------------------------------------------------------- files to send
function Test-Wanted([string]$p) {
  if ($Hidden -contains $p) { return $false }
  if ($p -match '^[^/]+\.html$') { return $p -ne 'Launch Biomi Website.html' }
  if ($p -eq 'sitemap.xml') { return $true }
  if ($p -eq 'robots.txt') { return $Live }
  # the icons crawlers and phones look for at the root regardless of markup
  # (Google's search-result icon among them); the pages' own is favicon.svg
  if ($p -eq 'favicon.ico' -or $p -eq 'apple-touch-icon.png') { return $true }
  if ($p -match '^api/[^/]+\.(php|png)$') { return $true }   # the form sender + its email logo; secrets live beside public_html, not here
  if ($FontAllow -contains $p) { return $true }
  if ($p -notmatch '^(assets|products|news|projects)/') { return $false }
  if ($p -like 'assets/downloads/*') { if ($Live) { return -not $NoPdf } else { return $PdfAllow -contains $p } }
  $ext = [IO.Path]::GetExtension($p).TrimStart('.').ToLowerInvariant()
  return $AssetExt -contains $ext
}

# What "Update Website" would publish: tracked files plus new, not-ignored ones.
$prevEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$listed = @(git -c core.quotepath=off ls-files) + @(git -c core.quotepath=off ls-files --others --exclude-standard)
[Console]::OutputEncoding = $prevEnc
if ($LASTEXITCODE -ne 0 -or $listed.Count -lt 100) { Say 'Could not read the file list from git.' Red; exit 1 }

$md5 = [Security.Cryptography.MD5]::Create()
function HashOf([byte[]]$b) { [BitConverter]::ToString($md5.ComputeHash($b)).Replace('-', '') }

$local = [ordered]@{}     # path -> @{ hash; size; file (or data for generated) }
foreach ($p in ($listed | Sort-Object -Unique)) {
  if (-not (Test-Wanted $p)) { continue }
  $fp = Join-Path $root $p
  if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { continue }   # deleted, not yet committed
  if ($p -match '[^\x20-\x7E]') { Say "Skipped (non-English characters in the name): $p" Yellow; continue }
  $bytes = [IO.File]::ReadAllBytes($fp)
  $local[$p] = @{ hash = (HashOf $bytes); size = $bytes.Length; file = $fp }
}
foreach ($k in $Generated.Keys) {
  # UTF-8 without a BOM: Apache would read a BOM as part of the first directive
  $bytes = (New-Object Text.UTF8Encoding $false).GetBytes($Generated[$k])
  $local[$k] = @{ hash = (HashOf $bytes); size = $bytes.Length; data = $bytes }
}

# ------------------------------------------------------ compare with last upload
$sent = @{}
if (-not $Full -and (Test-Path -LiteralPath $manifestFile)) {
  $m = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $lastDir = if ($m.PSObject.Properties['folder']) { [string]$m.folder } else { '' }
  if ($lastDir -ne $RemoteDir -and -not $FolderMoved) {
    Say ('The last upload went into "' + $lastDir + '", this one into "' + $RemoteDir + '".') Red
    Say 'If that folder has since been renamed to this one, add -FolderMoved;' Red
    Say 'to upload everything into this folder afresh, add -Full.' Red
    exit 1
  }
  if ($m.files) { foreach ($pr in $m.files.PSObject.Properties) { $sent[$pr.Name] = $pr.Value } }
}

# Server settings and robots first, then assets, then the pages that use them.
$order = { param($p) if ($Generated.Contains($p)) { 0 } elseif ($p -like '*.html') { 2 } else { 1 } }
$toSend   = @($local.Keys | Where-Object { $sent[$_] -ne $local[$_].hash } | Sort-Object @{ e = { & $order $_ } }, @{ e = { $_ } })
# -NoPdf means "don't send the PDFs this time", not "remove them": without this
# a run with it would delete every PDF an earlier run had put up.
$toDelete = @($sent.Keys | Where-Object { -not $local.Contains($_) -and -not ($NoPdf -and $_ -like 'assets/downloads/*') } | Sort-Object)
$sendBytes = 0; foreach ($p in $toSend) { $sendBytes += $local[$p].size }
$allBytes  = 0; foreach ($p in $local.Keys) { $allBytes += $local[$p].size }

$where = $SiteHost + $(if ($RemoteDir -and $RemoteDir -ne 'public_html') { ' (folder ' + $RemoteDir + ')' } else { '' })
Say ('Target: ' + $where) White
Say ('Website: {0} files, {1:N1} MB' -f $local.Count, ($allBytes / 1MB))
Say ('To upload: {0} files, {1:N1} MB   To delete: {2}' -f $toSend.Count, ($sendBytes / 1MB), $toDelete.Count) White
if ($DryRun) {
  foreach ($p in $toSend)   { Say ('  + ' + $p) }
  foreach ($p in $toDelete) { Say ('  - ' + $p) }
  exit 0
}
if ($toSend.Count -eq 0 -and $toDelete.Count -eq 0) { Say ($where + ' is already up to date.') Green; exit 0 }

if ($Live -and -not $Yes) {
  Write-Host ''
  Say 'This changes the LIVE website that customers see.' Yellow
  $answer = Read-Host '   Type biomi.ge and press Enter to go ahead'
  if ($answer.Trim() -ne 'biomi.ge') { Say 'Nothing was uploaded.' Yellow; exit 1 }
}

# ------------------------------------------------------------------- the login
if ($ResetLogin -and (Test-Path -LiteralPath $loginFile)) { Remove-Item -LiteralPath $loginFile }
if (-not (Test-Path -LiteralPath $loginFile)) {
  # Asked for right here in the console: the Get-Credential dialog opened
  # off-screen under Windows Terminal (2026-09-15) and could not be brought up.
  Write-Host ''
  Say ('FTP login of the ' + $(if ($Live) { 'LIVE site' } else { 'test site' }) + ' account (DirectAdmin > FTP Management).') White
  Say 'It is saved encrypted for this Windows user and asked only once.' White
  Write-Host ''
  $u  = Read-Host '   User name (full, like name@biomi.ge)'
  $pw = Read-Host '   Password (stays hidden as you type or paste)' -AsSecureString
  if (-not $u -or -not $u.Trim() -or $pw.Length -eq 0) { Say 'No login entered - nothing was uploaded.' Yellow; exit 1 }
  $cred = New-Object Management.Automation.PSCredential($u.Trim(), $pw)
  Write-Host ''
  New-Item -ItemType Directory -Force -Path $store | Out-Null
  $cred | Export-Clixml -LiteralPath $loginFile
}
$netCred = (Import-Clixml -LiteralPath $loginFile).GetNetworkCredential()

# ------------------------------------------------------------------- FTP calls
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function New-FtpRequest([string]$rel, [string]$method) {
  # not $full: PowerShell names ignore case, and that is the -Full switch
  $remotePath = if ($RemoteDir) { $RemoteDir + '/' + $rel } else { $rel }
  $uri = 'ftp://' + $FtpHost + '/' + ((($remotePath -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
  $r = [Net.FtpWebRequest][Net.WebRequest]::Create($uri)
  $r.Method = $method
  $r.Credentials = $netCred
  $r.EnableSsl = $true
  $r.UseBinary = $true
  $r.UsePassive = $true
  $r.KeepAlive = $true
  $r.ConnectionGroupName = 'biomi-' + $Target
  $r.Timeout = 60000
  $r.ReadWriteTimeout = 120000
  return $r
}
function FtpStatus($err) {
  $e = $err.Exception; while ($e -and -not ($e -is [Net.WebException])) { $e = $e.InnerException }
  if ($e -and $e.Response) { return [int]$e.Response.StatusCode }
  return 0
}
function Invoke-Ftp([string]$rel, [string]$method, [byte[]]$bytes) {
  $r = New-FtpRequest $rel $method
  if ($bytes) {
    $r.ContentLength = $bytes.Length
    $s = $r.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
  }
  $resp = $r.GetResponse(); $resp.Close()
}

function Save-Manifest {
  New-Item -ItemType Directory -Force -Path $store | Out-Null
  $o = [ordered]@{ host = $FtpHost; folder = $RemoteDir; updated = (Get-Date).ToString('s'); files = [ordered]@{} }
  foreach ($k in ($sent.Keys | Sort-Object)) { $o.files[$k] = $sent[$k] }
  [IO.File]::WriteAllText($manifestFile, ($o | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
}

$failedInARow = 0; $failed = @(); $done = 0
$started = Get-Date
try {
  # Folders the uploads need, parents first (the target folder itself too).
  # "Already exists" (550) is fine; a folder that truly could not be made shows
  # up as failed uploads below.
  $needDirs = @{}
  foreach ($p in $toSend) { $parts = $p -split '/'; for ($i = 1; $i -lt $parts.Count; $i++) { $needDirs[($parts[0..($i - 1)] -join '/')] = $true } }
  $dirs = @($needDirs.Keys | Sort-Object { ($_ -split '/').Count }, { $_ })
  if ($RemoteDir) {
    $saved = $RemoteDir; $RemoteDir = ''
    try { Invoke-Ftp $saved ([Net.WebRequestMethods+Ftp]::MakeDirectory) $null }
    catch { $code = FtpStatus $_; if ($code -eq 530) { throw 'LOGIN' }; if ($code -ne 550) { throw } }
    finally { $RemoteDir = $saved }
  }
  foreach ($d in $dirs) {
    try { Invoke-Ftp $d ([Net.WebRequestMethods+Ftp]::MakeDirectory) $null }
    catch {
      $code = FtpStatus $_
      if ($code -eq 530) { throw 'LOGIN' }
      if ($code -ne 550) { throw }
    }
  }

  $n = 0
  foreach ($p in $toSend) {
    $n++
    $item = $local[$p]
    $bytes = if ($item.data) { $item.data } else { [IO.File]::ReadAllBytes($item.file) }
    Write-Progress -Activity ('Uploading to ' + $where) -Status $p -PercentComplete ([int](100 * $n / $toSend.Count))
    $ok = $false
    foreach ($wait in 0, 3, 10) {
      if ($wait) { Start-Sleep -Seconds $wait }
      try { Invoke-Ftp $p ([Net.WebRequestMethods+Ftp]::UploadFile) $bytes; $ok = $true; break }
      catch {
        if ((FtpStatus $_) -eq 530) { throw 'LOGIN' }
        $lastErr = $_.Exception.Message
      }
    }
    if ($ok) {
      $sent[$p] = $item.hash; $done++; $failedInARow = 0
      Say ('[{0}/{1}] {2}' -f $n, $toSend.Count, $p)
      if ($done % 25 -eq 0) { Save-Manifest }
    } else {
      $failed += $p; $failedInARow++
      Say ('[{0}/{1}] FAILED {2} - {3}' -f $n, $toSend.Count, $p, $lastErr) Red
      if ($failedInARow -ge 5) { Say 'Five failures in a row - stopping so the server firewall does not block this office.' Red; break }
    }
  }

  if ($failedInARow -lt 5) {
    foreach ($p in $toDelete) {
      try { Invoke-Ftp $p ([Net.WebRequestMethods+Ftp]::DeleteFile) $null }
      catch { $code = FtpStatus $_; if ($code -eq 530) { throw 'LOGIN' }; if ($code -ne 550) { Say ('Could not delete ' + $p + ' - ' + $_.Exception.Message) Yellow; continue } }
      $sent.Remove($p); Say ('deleted ' + $p)
    }
  }
}
catch {
  if ("$_" -eq 'LOGIN') {
    Remove-Item -LiteralPath $loginFile -ErrorAction SilentlyContinue
    Say 'The server refused the FTP login. The saved login was forgotten -' Red
    Say 'run the upload again and re-type the user name and password.' Red
  } else {
    Say ('Upload stopped: ' + $_.Exception.Message) Red
  }
  exit 1
}
finally {
  Write-Progress -Activity ('Uploading to ' + $where) -Completed
  Save-Manifest
}

$secs = [int]((Get-Date) - $started).TotalSeconds
Write-Host ''
if ($failed.Count) {
  Say ('Uploaded {0} files in {1} s; {2} FAILED (they will be retried next time):' -f $done, $secs, $failed.Count) Yellow
  foreach ($p in $failed) { Say ('  ' + $p) Yellow }
} else {
  Say ('Uploaded {0} files in {1} s.' -f $done, $secs) Green
}

# ------------------------------------------------------------ is the site up?
# --resolve talks to the ProService server directly, so this works even before
# a DNS change has reached this computer. A folder that isn't public_html is
# not served yet, so there is nothing to check.
if ($RemoteDir -and $RemoteDir -ne 'public_html') { Say ('Uploaded into "' + $RemoteDir + '" - not public until it is renamed to public_html.') White; exit 0 }
$ErrorActionPreference = 'Continue'
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (Test-Path $curl) {
  $head = & $curl -s -o NUL -D - --max-time 20 --resolve "${SiteHost}:443:$ServerIp" "https://$SiteHost/"
  if (-not $head) { $head = @('no answer') }
  $status = ($head | Select-Object -First 1)
  $noindex = [bool]($head | Where-Object { $_ -match '^X-Robots-Tag:.*noindex' })
  $note = if ($Live) { if ($noindex) { '  (WARNING: hidden from search engines)' } else { '' } }
          else { if ($noindex) { '  (hidden from search engines)' } else { '  (WARNING: no noindex header)' } }
  Say ('https://' + $SiteHost + '/  ->  ' + $status + $note) $(if ($status -match ' 200' -and -not $note.Contains('WARNING')) { 'Green' } else { 'Yellow' })
}
