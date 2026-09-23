<?php
/* GitHub sign-in for the content editor at /admin (Decap CMS).

   Decap opens this in a pop-up. With no "code" it sends the visitor to GitHub
   to sign in; GitHub sends them back here with a code, which is exchanged for
   an access token, and the token is handed to the editor window through
   postMessage - only to a biomi.ge page, never to any other site.

   The GitHub OAuth App's id and secret are read from biomi-config.php, two
   folders up (beside public_html, never inside it), like api/contact.php:

       'github_client_id'     => '...',
       'github_client_secret' => '...',

   The OAuth App's "Authorization callback URL" must be this file's address on
   the site the editor runs on: https://test.biomi.ge/api/decap-auth.php.
   Uploaded to the test site only (tools/deploy/deploy-site.ps1). */

declare(strict_types=1);
header('X-Robots-Tag: noindex, nofollow');
header('Cache-Control: no-store');
header('Referrer-Policy: no-referrer');

$ORIGINS = ['https://test.biomi.ge', 'https://biomi.ge'];

$host = strtolower((string)($_SERVER['HTTP_HOST'] ?? ''));
if (!in_array('https://' . $host, $ORIGINS, true)) { http_response_code(404); exit; }
$self = 'https://' . $host . '/api/decap-auth.php';

/* The page that talks to the editor window. Decap first sends
   "authorizing:github" and waits; the answer goes back to that window only if
   it is one of ours. */
function answer(string $status, array $content, array $origins): void {
  $msg = 'authorization:github:' . $status . ':' . json_encode($content, JSON_UNESCAPED_SLASHES);
  $m = json_encode($msg, JSON_UNESCAPED_SLASHES | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT);
  $o = json_encode($origins, JSON_UNESCAPED_SLASHES);
  $text = $status === 'success' ? 'შესვლა შესრულდა. ეს ფანჯარა დაიხურება.' : 'შესვლა ვერ მოხერხდა.';
  header('Content-Type: text/html; charset=utf-8');
  echo '<!doctype html><html lang="ka"><head><meta charset="utf-8"><meta name="robots" content="noindex">',
       '<title>ბიომი - შესვლა</title></head><body style="font-family:sans-serif;padding:24px">',
       '<p>', htmlspecialchars($text), '</p><script>(function(){var msg=', $m, ',ok=', $o, ';',
       'function receive(e){if(ok.indexOf(e.origin)<0)return;window.opener.postMessage(msg,e.origin);',
       'window.removeEventListener("message",receive,false);}',
       'window.addEventListener("message",receive,false);',
       'if(window.opener){window.opener.postMessage("authorizing:github","*");}})();</script></body></html>';
  exit;
}

$cfgFile = dirname(__DIR__, 2) . '/biomi-config.php';
$cfg = is_file($cfgFile) ? (require $cfgFile) : null;
$id = is_array($cfg) ? (string)($cfg['github_client_id'] ?? '') : '';
$secret = is_array($cfg) ? (string)($cfg['github_client_secret'] ?? '') : '';
if ($id === '' || $secret === '') {
  error_log('biomi decap-auth: github_client_id / github_client_secret missing in ' . $cfgFile);
  answer('error', ['message' => 'Sign-in is not set up on this server yet.'], $ORIGINS);
}

// ---- step 1: off to GitHub
if (!isset($_GET['code'])) {
  $state = bin2hex(random_bytes(16));
  setcookie('decap_state', $state, [
    'expires' => time() + 600, 'path' => '/api/', 'secure' => true, 'httponly' => true, 'samesite' => 'Lax',
  ]);
  // The repository is private, so the editor needs "repo"; nothing wider is ever asked for.
  $scope = (($_GET['scope'] ?? '') === 'public_repo') ? 'public_repo' : 'repo';
  header('Location: https://github.com/login/oauth/authorize?' . http_build_query([
    'client_id' => $id, 'redirect_uri' => $self, 'scope' => $scope, 'state' => $state,
  ]));
  exit;
}

// ---- step 2: back from GitHub with a code
$state = (string)($_GET['state'] ?? '');
$saved = (string)($_COOKIE['decap_state'] ?? '');
setcookie('decap_state', '', ['expires' => time() - 3600, 'path' => '/api/', 'secure' => true, 'httponly' => true, 'samesite' => 'Lax']);
if ($state === '' || $saved === '' || !hash_equals($saved, $state)) {
  answer('error', ['message' => 'The sign-in expired or did not start here. Please try again.'], $ORIGINS);
}

$post = http_build_query([
  'client_id' => $id, 'client_secret' => $secret,
  'code' => (string)$_GET['code'], 'redirect_uri' => $self,
]);
$raw = false;
if (function_exists('curl_init')) {
  $ch = curl_init('https://github.com/login/oauth/access_token');
  curl_setopt_array($ch, [
    CURLOPT_POST => true, CURLOPT_POSTFIELDS => $post, CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Accept: application/json', 'User-Agent: biomi-decap-auth'],
    CURLOPT_TIMEOUT => 20,
  ]);
  $raw = curl_exec($ch);
  curl_close($ch);
} else {
  $raw = @file_get_contents('https://github.com/login/oauth/access_token', false, stream_context_create(['http' => [
    'method' => 'POST', 'timeout' => 20, 'content' => $post,
    'header' => "Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nUser-Agent: biomi-decap-auth\r\n",
  ]]));
}
$data = is_string($raw) ? json_decode($raw, true) : null;
if (!is_array($data) || empty($data['access_token'])) {
  error_log('biomi decap-auth: token exchange failed: ' . (is_array($data) ? (string)($data['error'] ?? 'no token') : 'no response'));
  answer('error', ['message' => 'GitHub did not complete the sign-in. Please try again.'], $ORIGINS);
}
answer('success', ['token' => (string)$data['access_token'], 'provider' => 'github'], $ORIGINS);
