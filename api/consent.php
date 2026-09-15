<?php
/* Cookie-consent log: one row for every Accept or Decline on the consent bar
   (assets/js/main.js, "Analytics").

   What a row holds, and why nothing more:
   - consent_id: a random ID the visitor's browser made and keeps. It names no
     one, but it lets a specific visitor's choice be found and shown.
   - choice, banner_version, when, which site / page / language.
   - ip_masked: the address with its last part zeroed (IPv4 /24, IPv6 /48) -
     enough to spot abuse, not enough to identify anyone.
   Rows older than 6 years are deleted, as privacy.html promises.

   Self-contained on purpose: it shares biomi-config.php with contact.php but
   not its code, so a change here cannot break the contact form. */

declare(strict_types=1);

const KEEP_YEARS    = 6;
const RATE_PER_HOUR = 60;    // per masked address - a real visitor clicks once or twice

date_default_timezone_set('Asia/Tbilisi');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');

function reply(array $body, int $status = 200): void {
  http_response_code($status);
  echo json_encode($body);
  exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') reply(['ok' => false, 'error' => 'method'], 405);

$cfgFile = dirname(__DIR__, 2) . '/biomi-config.php';
$cfg = is_file($cfgFile) ? (include $cfgFile) : null;
if (!is_array($cfg)) reply(['ok' => false, 'error' => 'setup'], 500);

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed = $cfg['allowed_origins'] ?? ['https://biomi.ge', 'https://www.biomi.ge', 'https://test.biomi.ge'];
if ($origin !== '' && !in_array($origin, $allowed, true)) reply(['ok' => false, 'error' => 'origin'], 403);

$choice  = (string)($_POST['choice'] ?? '');
$cid     = (string)($_POST['id'] ?? '');
$version = (int)($_POST['version'] ?? 0);
if (!in_array($choice, ['accept', 'decline'], true) || !preg_match('/^[a-f0-9]{32}$/', $cid)
    || $version < 1 || $version > 1000) {
  reply(['ok' => false, 'error' => 'invalid'], 400);
}
$lang = ($_POST['lang'] ?? '') === 'en' ? 'en' : 'ka';
// the path only: a query string could carry anything
$page = (string)(parse_url((string)($_POST['page'] ?? ''), PHP_URL_PATH) ?? '');
$page = substr(preg_replace('/[^A-Za-z0-9\/._\-]/', '', $page) ?? '', 0, 200);
$site = substr(strtolower(preg_replace('/[^A-Za-z0-9.\-]/', '', (string)($_SERVER['HTTP_HOST'] ?? '')) ?? ''), 0, 100);

$ip = (string)($_SERVER['REMOTE_ADDR'] ?? '');
$bin = @inet_pton($ip);
if ($bin === false) {
  $ipMasked = '';
} elseif (strlen($bin) === 4) {
  $ipMasked = (string)inet_ntop(substr($bin, 0, 3) . "\0");
} else {
  $ipMasked = (string)inet_ntop(substr($bin, 0, 6) . str_repeat("\0", 10));
}

try {
  $pdo = new PDO('mysql:host=' . ($cfg['db_host'] ?? 'localhost') . ';dbname=' . $cfg['db_name'] . ';charset=utf8mb4',
                 $cfg['db_user'], (string)($cfg['db_pass'] ?? ''),
                 [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false]);
  $pdo->exec("SET time_zone = '+04:00'");
  $pdo->exec("CREATE TABLE IF NOT EXISTS consent_log (
      id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      created_at DATETIME NOT NULL,
      consent_id CHAR(32) NOT NULL,
      choice ENUM('accept','decline') NOT NULL,
      banner_version SMALLINT UNSIGNED NOT NULL,
      site VARCHAR(100) NOT NULL,
      lang CHAR(2) NOT NULL,
      page VARCHAR(200) NOT NULL DEFAULT '',
      ip_masked VARCHAR(45) NOT NULL DEFAULT '',
      KEY created_at (created_at),
      KEY consent_id (consent_id),
      KEY ip_time (ip_masked, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

  $q = $pdo->prepare('SELECT COUNT(*) FROM consent_log WHERE ip_masked = ? AND created_at > ?');
  $q->execute([$ipMasked, date('Y-m-d H:i:s', time() - 3600)]);
  if ((int)$q->fetchColumn() >= RATE_PER_HOUR) reply(['ok' => false, 'error' => 'rate'], 429);

  $pdo->prepare('INSERT INTO consent_log (created_at, consent_id, choice, banner_version, site, lang, page, ip_masked)
                 VALUES (?,?,?,?,?,?,?,?)')
      ->execute([date('Y-m-d H:i:s'), $cid, $choice, $version, $site, $lang, $page, $ipMasked]);

  $pdo->prepare('DELETE FROM consent_log WHERE created_at < ?')
      ->execute([date('Y-m-d H:i:s', (int)strtotime('-' . KEEP_YEARS . ' years'))]);
} catch (Throwable $e) {
  error_log('biomi consent: ' . $e->getMessage());
  reply(['ok' => false, 'error' => 'db'], 500);
}

reply(['ok' => true]);
