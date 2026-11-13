<?php
/* Print-panel designs -> an email to the office, to see what visitors make.

   Called by the "send it to us" button beside the upload on the VORT HRW-ALL
   100 DF page (main.js, the printed front panel - the user, 2026-11-12:
   "without making the whole form"). The visitor's picture arrives as it sits
   on the panel, a JPEG the browser drew, with no name or contact details.
   Answers JSON like contact.php: {"ok":true} or {"ok":false,"error":"<code>"}.

   Its settings are contact.php's: biomi-config.php beside public_html (where
   the mail goes, the database). The database only counts the sends, for the
   limits below - time and address, cleared after KEEP_DAYS; the picture
   itself is not kept on the server, only mailed.

   GET design.php?check  ->  what is set up, no secrets. */

declare(strict_types=1);

const MAX_BYTES = 4 * 1024 * 1024;   // the browser sends a 1000 x 1600 JPEG, well under 1 MB
const MAX_SIDE  = 2400;
const RATE_IP   = 5;                 // sends per address ...
const RATE_MIN  = 15;                // ... per this many minutes
const RATE_DAY  = 60;                // all addresses together per day - a cap on the inbox
const KEEP_DAYS = 30;
const PRODUCTS  = ['vortice-hrw-all' => 'VORT HRW-ALL 100 DF'];
const MAIL_FONT = "'Segoe UI',Tahoma,Arial,sans-serif";

date_default_timezone_set('Asia/Tbilisi');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');

function answer(array $body, int $status = 200): void {
  http_response_code($status);
  echo json_encode($body, JSON_UNESCAPED_UNICODE);
  exit;
}
function fail(string $code, int $status = 400): void { answer(['ok' => false, 'error' => $code], $status); }
function enc(string $s): string { return '=?UTF-8?B?' . base64_encode($s) . '?='; }
function h(string $s): string { return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }

$cfgFile = dirname(__DIR__, 2) . '/biomi-config.php';
$cfg = is_file($cfgFile) ? (include $cfgFile) : null;
if (!is_array($cfg)) $cfg = null;

function db(?array $cfg): ?PDO {
  if (!$cfg || empty($cfg['db_name']) || empty($cfg['db_user'])) return null;
  try {
    $pdo = new PDO('mysql:host=' . ($cfg['db_host'] ?? 'localhost') . ';dbname=' . $cfg['db_name'] . ';charset=utf8mb4',
                   $cfg['db_user'], (string)($cfg['db_pass'] ?? ''),
                   [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false]);
    $pdo->exec("SET time_zone = '+04:00'");
    $pdo->exec("CREATE TABLE IF NOT EXISTS design_sends (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        created_at DATETIME NOT NULL,
        site VARCHAR(100) NOT NULL,
        product VARCHAR(60) NOT NULL,
        ip VARCHAR(45) NOT NULL,
        bytes INT UNSIGNED NOT NULL,
        mail_sent TINYINT(1) NOT NULL DEFAULT 0,
        mail_error VARCHAR(255) NOT NULL DEFAULT '',
        KEY created_at (created_at),
        KEY ip_time (ip, created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    return $pdo;
  } catch (Throwable $e) {
    error_log('biomi design: database: ' . $e->getMessage());
    return null;
  }
}

$host = strtolower((string)($_SERVER['HTTP_HOST'] ?? ''));
$isTest = str_starts_with($host, 'test.');

/* ------------------------------------------------------------ health check */
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'GET') {
  if (!isset($_GET['check'])) fail('method', 405);
  $pdo = db($cfg);
  $out = ['config' => $cfg !== null, 'database' => $pdo !== null, 'mail' => function_exists('mail')];
  // On the test site only: how the last few sends went - times and results.
  if ($pdo && $isTest) {
    try {
      $out['recent'] = $pdo->query('SELECT id, created_at, bytes, mail_sent, mail_error FROM design_sends ORDER BY id DESC LIMIT 3')
                           ->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) { $out['recent'] = 'unreadable'; }
  }
  answer($out);
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('method', 405);

// A browser posting from some other website is refused (as in contact.php).
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed = $cfg['allowed_origins'] ?? ['https://biomi.ge', 'https://www.biomi.ge', 'https://test.biomi.ge'];
if ($origin !== '' && !in_array($origin, $allowed, true)) fail('origin', 403);

$len = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
if ($len > 0 && empty($_POST) && empty($_FILES)) fail('too_large', 413);
if (!$cfg) { error_log('biomi design: biomi-config.php not found at ' . $cfgFile); fail('setup', 500); }

/* ---------------------------------------------------------------- the send */
$slug = (string)($_POST['product'] ?? '');
if (!isset(PRODUCTS[$slug])) fail('invalid');
$product = PRODUCTS[$slug];
$lang = ($_POST['lang'] ?? '') === 'en' ? 'en' : 'ka';

// One JPEG, checked by what it is, not by the name the browser gave it.
$f = $_FILES['design'] ?? null;
if (!is_array($f) || is_array($f['error'])) fail('file');
if ($f['error'] === UPLOAD_ERR_INI_SIZE || $f['error'] === UPLOAD_ERR_FORM_SIZE) fail('too_large', 413);
if ($f['error'] !== UPLOAD_ERR_OK || !is_uploaded_file($f['tmp_name'])) fail('file');
$bytes = (int)$f['size'];
if ($bytes <= 0 || $bytes > MAX_BYTES) fail('too_large', 413);
$info = @getimagesize($f['tmp_name']);
if (!$info || $info[2] !== IMAGETYPE_JPEG || $info[0] < 50 || $info[1] < 50 || $info[0] > MAX_SIDE || $info[1] > MAX_SIDE) fail('file');
$jpeg = (string)file_get_contents($f['tmp_name']);
if (strncmp($jpeg, "\xFF\xD8\xFF", 3) !== 0) fail('file');

$ip   = substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45);
$site = preg_match('/^(www\.|test\.)?biomi\.ge$/', $host) ? $host : 'biomi.ge';

/* ---------------------------------------------------- limits + the count */
$pdo = db($cfg);
$sendId = 0;
if ($pdo) {
  try {
    $q = $pdo->prepare('SELECT COUNT(*) FROM design_sends WHERE ip = ? AND created_at > ?');
    $q->execute([$ip, date('Y-m-d H:i:s', time() - RATE_MIN * 60)]);
    if ((int)$q->fetchColumn() >= RATE_IP) fail('rate', 429);
    $q = $pdo->prepare('SELECT COUNT(*) FROM design_sends WHERE created_at > ?');
    $q->execute([date('Y-m-d H:i:s', time() - 86400)]);
    if ((int)$q->fetchColumn() >= RATE_DAY) fail('rate', 429);

    $pdo->prepare('INSERT INTO design_sends (created_at, site, product, ip, bytes) VALUES (?,?,?,?,?)')
        ->execute([date('Y-m-d H:i:s'), $site, $slug, $ip, $bytes]);
    $sendId = (int)$pdo->lastInsertId();
    $pdo->prepare('DELETE FROM design_sends WHERE created_at < ?')
        ->execute([date('Y-m-d H:i:s', strtotime('-' . KEEP_DAYS . ' days'))]);
  } catch (Throwable $e) {
    error_log('biomi design: log: ' . $e->getMessage());
  }
}

/* ------------------------------------------------------------------- mail */
$when = date('d.m.Y H:i');
$page = 'https://' . $site . '/products/' . $slug . ($lang === 'en' ? '-en' : '') . '.html';
$langName = $lang === 'en' ? 'ინგლისური' : 'ქართული';
$subject = ($isTest ? '[TEST] ' : '') . 'დიზაინი ვებ-გვერდიდან - ' . $product;
$fileName = 'design-' . ($sendId ?: date('YmdHis')) . '.jpg';
$logo = __DIR__ . '/email-logo.png';
if (!is_file($logo)) $logo = '';

$text = implode("\r\n", [
  'ვებ-გვერდიდან გამოგზავნილი დიზაინი' . ($sendId ? ' #' . $sendId : ''),
  '',
  'პროდუქტი: ' . $product,
  'გვერდი:   ' . $page . ' (' . $langName . ')',
  'დრო:      ' . $when,
  '',
  'სურათი მიმაგრებულია (' . $fileName . ') - ისე, როგორც ის პანელზე დასვა.',
  'გამომგზავნს სახელი და კონტაქტი არ მოუწერია.',
]) . "\r\n";

$cell = 'font-family:' . MAIL_FONT . ';';
$logoHtml = $logo
  ? '<img src="cid:biomi-logo@biomi.ge" width="180" height="30" alt="ბიომი ჰოლდინგი" style="display:block;border:0;outline:none;width:180px;height:30px;">'
  : '<span style="' . $cell . 'font-size:22px;font-weight:700;color:#ffffff;">ბიომი</span>';
$badge = ($isTest ? '<span style="display:inline-block;padding:3px 9px;margin-right:8px;border-radius:4px;background:#85519a;color:#ffffff;font-weight:700;">TEST</span>' : '')
       . ($sendId ? '#' . $sendId : '');
$html = '<!doctype html><html lang="ka"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
  . '<title>' . h($subject) . '</title></head>'
  . '<body style="margin:0;padding:0;background:#f1f4fc;">'
  . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f1f4fc" style="background:#f1f4fc;">'
  . '<tr><td align="center" style="padding:28px 12px;">'
  . '<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="#ffffff" style="width:100%;max-width:600px;background:#ffffff;border:1px solid #e7e6ea;border-radius:14px;">'
  . '<tr><td bgcolor="#1b1b33" style="background:#1b1b33;padding:22px 32px;border-radius:14px 14px 0 0;">'
  .   '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
  .     '<td valign="middle">' . $logoHtml . '</td>'
  .     '<td valign="middle" align="right" style="' . $cell . 'font-size:13px;color:#8ba4fb;white-space:nowrap;">' . $badge . '</td>'
  .   '</tr></table>'
  . '</td></tr>'
  . '<tr><td style="padding:28px 32px 0;' . $cell . 'font-size:13px;line-height:18px;font-weight:700;color:#0238be;">ახალი დიზაინი ვებ-გვერდიდან</td></tr>'
  . '<tr><td style="padding:6px 32px 0;' . $cell . 'font-size:24px;line-height:31px;font-weight:700;color:#1b1b33;">' . h($product) . '</td></tr>'
  . '<tr><td style="padding:4px 32px 0;' . $cell . 'font-size:14px;line-height:20px;color:#6c6f72;">' . h($when) . '</td></tr>'
  . '<tr><td align="center" style="padding:24px 32px 6px;">'
  .   '<img src="cid:design@biomi.ge" width="300" height="480" alt="დიზაინი" style="display:block;border:1px solid #e7e6ea;width:300px;height:480px;">'
  . '</td></tr>'
  . '<tr><td align="center" style="padding:4px 32px 0;' . $cell . 'font-size:13px;line-height:19px;color:#6c6f72;">ისე, როგორც ის წინა პანელზე დასვა. სრული ზომით - მიმაგრებულ ფაილში.</td></tr>'
  . '<tr><td style="padding:24px 32px 26px;' . $cell . 'font-size:12px;line-height:19px;color:#6c6f72;">'
  .   '<div style="border-top:1px solid #e7e6ea;padding-top:16px;">'
  .     'გვერდი: <a href="' . h($page) . '" style="color:#6c6f72;">' . h(preg_replace('#^https?://#', '', $page) ?? $page) . '</a> &middot; ' . h($langName) . ' ვერსია<br>'
  .     'გაგზავნილია ' . h($when) . ' &middot; ' . h($site) . '<br>'
  .     'გამომგზავნს სახელი და კონტაქტი არ მოუწერია - პასუხის გაცემა შეუძლებელია.'
  .   '</div>'
  . '</td></tr>'
  . '</table></td></tr></table></body></html>';

/* MIME: text + HTML as alternatives; the logo and the design ride with the
   HTML (related) - the design inline, with a file name so it can be saved. */
$alt = 'alt-' . bin2hex(random_bytes(10));
$rel = 'rel-' . bin2hex(random_bytes(10));
$body = "This is a multi-part message in MIME format.\r\n"
  . "--$alt\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
  . chunk_split(base64_encode($text))
  . "--$alt\r\nContent-Type: multipart/related; boundary=\"$rel\"\r\n\r\n"
  . "--$rel\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
  . chunk_split(base64_encode($html));
if ($logo) {
  $body .= "--$rel\r\nContent-Type: image/png; name=\"biomi-logo.png\"\r\nContent-Transfer-Encoding: base64\r\n"
         . "Content-ID: <biomi-logo@biomi.ge>\r\nContent-Disposition: inline; filename=\"biomi-logo.png\"\r\n\r\n"
         . chunk_split(base64_encode((string)file_get_contents($logo)));
}
$body .= "--$rel\r\nContent-Type: image/jpeg; name=\"$fileName\"\r\nContent-Transfer-Encoding: base64\r\n"
       . "Content-ID: <design@biomi.ge>\r\nContent-Disposition: inline; filename=\"$fileName\"\r\n\r\n"
       . chunk_split(base64_encode($jpeg))
       . "--$rel--\r\n--$alt--\r\n";

$to   = (string)($cfg['mail_to'] ?? 'marketing@biomi.ge');
$from = (string)($cfg['mail_from'] ?? $to);
$headers = [
  'From: ' . enc('Biomi ვებ-გვერდი') . ' <' . $from . '>',
  'MIME-Version: 1.0',
  'X-Mailer: biomi.ge print-panel designs',
  'Content-Type: multipart/alternative; boundary="' . $alt . '"',
];

$sent = false; $mailError = '';
try {
  $sent = mail($to, enc($subject), $body, implode("\r\n", $headers), '-f' . $from);
  if (!$sent) { $last = error_get_last(); $mailError = 'mail() returned false' . ($last ? ': ' . $last['message'] : ''); }
} catch (Throwable $e) {
  $mailError = 'mail: ' . $e->getMessage();
}
if ($mailError !== '') error_log('biomi design: ' . $mailError);

if ($pdo && $sendId) {
  try {
    $pdo->prepare('UPDATE design_sends SET mail_sent = ?, mail_error = ? WHERE id = ?')
        ->execute([$sent ? 1 : 0, mb_substr($mailError, 0, 255), $sendId]);
  } catch (Throwable $e) { error_log('biomi design: log update: ' . $e->getMessage()); }
}

if (!$sent) fail('mail', 502);
answer(['ok' => true]);
