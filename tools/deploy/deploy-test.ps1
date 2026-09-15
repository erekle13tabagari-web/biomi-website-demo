# Upload the website to the staging copy at https://test.biomi.ge (ProService).
#
# Run it through "Upload Test Site.bat". Only files that changed since the last
# upload are sent, and files that were deleted here are deleted there too (only
# ones this script uploaded - anything else on the server is left alone).
#
#   -DryRun      list what would be uploaded/deleted, connect to nothing
#   -Full        ignore the record of the last upload and send everything again
#   -ResetLogin  forget the saved FTP login and ask for it again
#
# The FTP login is typed by the user into this console window and kept
# in %APPDATA%\Biomi, encrypted for this Windows account (DPAPI). It is never
# written into the project folder, so it can't end up on GitHub.
#
# ProService's firewall banned the office IP for an hour when FileZilla opened
# many connections at once, so this uses ONE connection, sends files one after
# another, and stops after a few failures in a row instead of hammering on.

param([switch]$DryRun, [switch]$Full, [switch]$ResetLogin)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $root

$FtpHost  = 'ftp.biomi.ge'           # the certificate on this name is valid (checked 2026-09-15)
$SiteHost = 'test.biomi.ge'
$ServerIp = '91.239.206.19'          # for the after-upload check while DNS is still catching up
$store        = Join-Path $env:APPDATA 'Biomi'
$loginFile    = Join-Path $store 'test-ftp-login.xml'
$manifestFile = Join-Path $store 'test-site-manifest.json'

# The PDFs don't fit on the account yet (disk ~95% full, shared with the
# mailboxes). One brochure goes up to test downloads; the rest wait for space.
$PdfAllow = @('assets/downloads/vortice-lineo-brochure.pdf')
# The only two font files the CSS uses; the rest of fonts/ is source material.
$FontAllow = @('fonts/Futura 100/Variable/Futura100-VF-Upright.ttf',
               'fonts/Futura 100 Georgian/Variable/Futura100-GEO-VF-Upright.ttf')
$AssetExt = @('html','css','js','json','avif','webp','jpg','jpeg','png','gif','svg','ico','pdf','woff2','woff','ttf','xml','txt')

# Staging-only files, generated here rather than taken from the project:
# search engines must not index the test copy, and pages/CSS/JS are always
# revalidated so a fresh upload shows without a hard refresh.
$Generated = [ordered]@{
  'robots.txt' = "User-agent: *`nDisallow: /`n"
  '.htaccess'  = @'
# test.biomi.ge - staging copy of the new Biomi website. Not for search engines.
Options -Indexes
DirectoryIndex index.html
AddDefaultCharset UTF-8
AddType image/avif .avif
AddType image/webp .webp
AddType font/ttf .ttf
# Always https: the form sender refuses posts from an http:// page, and
# Citynet and the browser both expect a secure page.
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</IfModule>
<IfModule mod_headers.c>
  Header set X-Robots-Tag "noindex, nofollow"
  <FilesMatch "\.(html|css|js|json)$">
    Header set Cache-Control "no-cache"
  </FilesMatch>
</IfModule>
'@ -replace "`r`n", "`n"
}

function Say($text, $color = 'Gray') { Write-Host ('   ' + $text) -ForegroundColor $color }

# Pages build-meta.ps1 keeps hidden (noindex, out of the sitemap and search) are
# not uploaded at all - on the server "hidden" means not there, so no stray link
# can open one (the service page did, from the projects menu, 2026-09-15).
# Read from build-meta's own $HIDDEN line so there is one list, not two.
$Hidden = @()
$metaSrc = [IO.File]::ReadAllText((Join-Path $root 'tools\build-meta.ps1'))
if ($metaSrc -match '(?m)^\$HIDDEN\s*=\s*(.+)$') {
  $Hidden = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
}

# ---------------------------------------------------------------- files to send
function Test-Wanted([string]$p) {
  if ($Hidden -contains $p) { return $false }
  if ($p -match '^[^/]+\.html$') { return $p -ne 'Launch Biomi Website.html' }
  if ($p -eq 'sitemap.xml') { return $true }
  if ($p -match '^api/[^/]+\.(php|png)$') { return $true }   # the form sender + its email logo; secrets live beside public_html, not here
  if ($FontAllow -contains $p) { return $true }
  if ($p -notmatch '^(assets|products|news|projects)/') { return $false }
  if ($p -like 'assets/downloads/*') { return $PdfAllow -contains $p }
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

$local = [ordered]@{}     # path -> @{ hash; size; file (or $null for generated) }
foreach ($p in ($listed | Sort-Object -Unique)) {
  if (-not (Test-Wanted $p)) { continue }
  $fp = Join-Path $root $p
  if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { continue }   # deleted, not yet committed
  if ($p -match '[^\x20-\x7E]') { Say "Skipped (non-English characters in the name): $p" Yellow; continue }
  $bytes = [IO.File]::ReadAllBytes($fp)
  $local[$p] = @{ hash = (HashOf $bytes); size = $bytes.Length; file = $fp }
}
foreach ($k in $Generated.Keys) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Generated[$k])
  $local[$k] = @{ hash = (HashOf $bytes); size = $bytes.Length; data = $bytes }
}

# ------------------------------------------------------ compare with last upload
$sent = @{}
if (-not $Full -and (Test-Path -LiteralPath $manifestFile)) {
  $m = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($m.files) { foreach ($pr in $m.files.PSObject.Properties) { $sent[$pr.Name] = $pr.Value } }
}

# Staging headers and robots first, then assets, then the pages that use them.
$order = { param($p) if ($Generated.Contains($p)) { 0 } elseif ($p -like '*.html') { 2 } else { 1 } }
$toSend   = @($local.Keys | Where-Object { $sent[$_] -ne $local[$_].hash } | Sort-Object @{ e = { & $order $_ } }, @{ e = { $_ } })
$toDelete = @($sent.Keys | Where-Object { -not $local.Contains($_) } | Sort-Object)
$sendBytes = 0; foreach ($p in $toSend) { $sendBytes += $local[$p].size }
$allBytes  = 0; foreach ($p in $local.Keys) { $allBytes += $local[$p].size }

Say ('Website: {0} files, {1:N1} MB' -f $local.Count, ($allBytes / 1MB))
Say ('To upload: {0} files, {1:N1} MB   To delete: {2}' -f $toSend.Count, ($sendBytes / 1MB), $toDelete.Count) White
if ($DryRun) {
  foreach ($p in $toSend)   { Say ('  + ' + $p) }
  foreach ($p in $toDelete) { Say ('  - ' + $p) }
  exit 0
}
if ($toSend.Count -eq 0 -and $toDelete.Count -eq 0) { Say 'test.biomi.ge is already up to date.' Green; exit 0 }

# ------------------------------------------------------------------- the login
if ($ResetLogin -and (Test-Path -LiteralPath $loginFile)) { Remove-Item -LiteralPath $loginFile }
if (-not (Test-Path -LiteralPath $loginFile)) {
  # Asked for right here in the console: the Get-Credential dialog opened
  # off-screen under Windows Terminal (2026-09-15) and could not be brought up.
  Write-Host ''
  Say 'FTP login of the test site account (DirectAdmin > FTP Management).' White
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
  $uri = 'ftp://' + $FtpHost + '/' + ((($rel -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
  $r = [Net.FtpWebRequest][Net.WebRequest]::Create($uri)
  $r.Method = $method
  $r.Credentials = $netCred
  $r.EnableSsl = $true
  $r.UseBinary = $true
  $r.UsePassive = $true
  $r.KeepAlive = $true
  $r.ConnectionGroupName = 'biomi-test'
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
  $o = [ordered]@{ host = $FtpHost; updated = (Get-Date).ToString('s'); files = [ordered]@{} }
  foreach ($k in ($sent.Keys | Sort-Object)) { $o.files[$k] = $sent[$k] }
  [IO.File]::WriteAllText($manifestFile, ($o | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
}

$failedInARow = 0; $failed = @(); $done = 0
$started = Get-Date
try {
  # Folders the uploads need, parents first. "Already exists" (550) is fine;
  # a folder that truly could not be made shows up as failed uploads below.
  $needDirs = @{}
  foreach ($p in $toSend) { $parts = $p -split '/'; for ($i = 1; $i -lt $parts.Count; $i++) { $needDirs[($parts[0..($i - 1)] -join '/')] = $true } }
  foreach ($d in ($needDirs.Keys | Sort-Object { ($_ -split '/').Count }, { $_ })) {
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
    Write-Progress -Activity 'Uploading to test.biomi.ge' -Status $p -PercentComplete ([int](100 * $n / $toSend.Count))
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
    Say 'run "Upload Test Site" again and re-type the user name and password.' Red
  } else {
    Say ('Upload stopped: ' + $_.Exception.Message) Red
  }
  exit 1
}
finally {
  Write-Progress -Activity 'Uploading to test.biomi.ge' -Completed
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
# the test.biomi.ge DNS record has reached this computer.
$ErrorActionPreference = 'Continue'
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (Test-Path $curl) {
  $head = & $curl -s -o NUL -D - --max-time 20 --resolve "${SiteHost}:443:$ServerIp" "https://$SiteHost/"
  if (-not $head) { $head = @('no answer') }
  $status = ($head | Select-Object -First 1)
  $noindex = [bool]($head | Where-Object { $_ -match '^X-Robots-Tag:.*noindex' })
  Say ('https://' + $SiteHost + '/  ->  ' + $status + $(if ($noindex) { '  (hidden from search engines)' } else { '  (WARNING: no noindex header)' })) $(if ($status -match ' 200') { 'Green' } else { 'Yellow' })
}
