<?php
/* Contact form -> email to the office + a log of the request and the consents.

   Called by the contact form in assets/js/main.js (POST, multipart). Answers
   JSON: {"ok":true} or {"ok":false,"error":"<code>"}; main.js turns the code
   into a message for the visitor.

   Secrets are NOT in this file (it is public on GitHub). They live in
   biomi-config.php, two folders up - beside public_html, where the web server
   does not serve it:
       /home/biomige/domains/<site>/biomi-config.php
   The user types the database password into that file in DirectAdmin's File
   Manager; tools/deploy/biomi-config.sample.php shows its shape.

   GET contact.php?check  ->  what is set up and what is not, no secrets.

   The office mailbox is on this same server, so the mail is handed to the
   server's own mail program (PHP mail()) - no SMTP password is needed. */

declare(strict_types=1);

const MAX_FILES = 5;
const MAX_FILE  = 10 * 1024 * 1024;   // per PDF - the form says "max 10MB per file"
const MAX_TOTAL = 15 * 1024 * 1024;   // all PDFs together; mail grows by a third on the way
const RATE_IP   = 5;                  // requests per address ...
const RATE_MIN  = 15;                 // ... per this many minutes
// consent.html (2026-09-18): an enquiry that led to no contract is kept 14
// months from sending. Marketing consents are kept until withdrawn
// (marketing.html), so only the rows without one are cleared on this clock.
const KEEP_MONTHS = 14;
const MAIL_FONT = "'Segoe UI',Tahoma,Arial,sans-serif";   // Outlook has no web fonts; Segoe UI carries Georgian

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

/* ---------------------------------------------------------------- settings */
$cfgFile = dirname(__DIR__, 2) . '/biomi-config.php';
$cfg = is_file($cfgFile) ? (include $cfgFile) : null;
if (!is_array($cfg)) $cfg = null;

function db(?array $cfg): ?PDO {
  static $pdo = null, $tried = false;
  if ($tried) return $pdo;
  $tried = true;
  if (!$cfg || empty($cfg['db_name']) || empty($cfg['db_user'])) return null;
  try {
    $pdo = new PDO('mysql:host=' . ($cfg['db_host'] ?? 'localhost') . ';dbname=' . $cfg['db_name'] . ';charset=utf8mb4',
                   $cfg['db_user'], (string)($cfg['db_pass'] ?? ''),
                   [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false]);
    $pdo->exec("SET time_zone = '+04:00'");
    $pdo->exec("CREATE TABLE IF NOT EXISTS form_requests (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        created_at DATETIME NOT NULL,
        site VARCHAR(100) NOT NULL,
        lang CHAR(2) NOT NULL,
        page VARCHAR(300) NOT NULL DEFAULT '',
        fullname VARCHAR(120) NOT NULL,
        email VARCHAR(190) NOT NULL,
        phone VARCHAR(40) NOT NULL,
        company VARCHAR(150) NOT NULL DEFAULT '',
        brief TEXT NOT NULL,
        files TEXT NOT NULL,
        ip VARCHAR(45) NOT NULL,
        user_agent VARCHAR(255) NOT NULL DEFAULT '',
        mail_sent TINYINT(1) NOT NULL DEFAULT 0,
        mail_error VARCHAR(255) NOT NULL DEFAULT '',
        KEY created_at (created_at),
        KEY ip_time (ip, created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS form_consents (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        request_id INT UNSIGNED NOT NULL,
        created_at DATETIME NOT NULL,
        email VARCHAR(190) NOT NULL,
        phone VARCHAR(40) NOT NULL,
        privacy TINYINT(1) NOT NULL,
        processing TINYINT(1) NOT NULL DEFAULT 0,
        marketing TINYINT(1) NOT NULL,
        policy_version VARCHAR(80) NOT NULL,
        ip VARCHAR(45) NOT NULL,
        marketing_withdrawn_at DATETIME NULL,
        KEY request_id (request_id),
        KEY email (email),
        KEY created_at (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    // Tables made before the separate personal-data tick (2026-09-18) lack its
    // column. Older rows keep 0: that tick did not exist when they were given.
    if (!$pdo->query("SHOW COLUMNS FROM form_consents LIKE 'processing'")->fetch()) {
      $pdo->exec("ALTER TABLE form_consents ADD COLUMN processing TINYINT(1) NOT NULL DEFAULT 0 AFTER privacy");
    }
  } catch (Throwable $e) {
    error_log('biomi contact: database: ' . $e->getMessage());
    $pdo = null;
  }
  return $pdo;
}

/* ------------------------------------------------------- the office email */
/* The office gets a branded HTML email, with a plain-text copy for mail apps
   that show no HTML. It is built from tables with inline styles because that
   is all Outlook's renderer reliably understands, and the logo travels inside
   the email (cid:) rather than as a web link, so Outlook shows it without
   asking. GET contact.php?preview on the test site shows it with sample data. */
function enc(string $s): string { return '=?UTF-8?B?' . base64_encode($s) . '?='; }
function h(string $s): string { return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function mailRow(string $label, string $valueHtml, bool $first = false): string {
  $line = $first ? '' : 'border-top:1px solid #e7e6ea;';
  return '<tr>'
    . '<td width="200" valign="top" style="' . $line . 'width:200px;padding:11px 12px 11px 0;font-family:' . MAIL_FONT . ';font-size:13px;line-height:20px;font-weight:700;color:#1b1b33;">' . $label . '</td>'
    . '<td valign="top" style="' . $line . 'padding:11px 0;font-family:' . MAIL_FONT . ';font-size:15px;line-height:20px;color:#43454e;">' . $valueHtml . '</td>'
    . '</tr>';
}
function mailHeading(string $text): string {
  return '<tr><td style="padding:26px 32px 8px;font-family:' . MAIL_FONT . ';font-size:12px;line-height:16px;font-weight:700;letter-spacing:.04em;color:#0238be;">' . $text . '</td></tr>';
}
function mailTick(bool $yes, string $yesText, string $noText): string {
  return $yes
    ? '<span style="display:inline-block;padding:3px 11px;border-radius:20px;background:#e5f3eb;color:#1a7d46;font-weight:700;font-size:13px;">&#10003;&nbsp; ' . $yesText . '</span>'
    : '<span style="display:inline-block;padding:3px 11px;border-radius:20px;background:#fbe9e8;color:#b23b37;font-weight:700;font-size:13px;">&#10007;&nbsp; ' . $noText . '</span>';
}
/* $d: id, fullname, email, phone, company, brief, files [{name,size}], marketing,
   page, lang, site, test, when. Returns subject, text, html and the logo path
   (or '' when the logo file is missing and a text wordmark stands in). */
function mailParts(array $d): array {
  $core = 'ვებ-გვერდიდან მოთხოვნა - ' . $d['fullname'];
  $subject = ($d['test'] ? '[TEST] ' : '') . $core;
  $langName = $d['lang'] === 'en' ? 'ინგლისური' : 'ქართული';
  $tel = preg_replace('/[^\d+]/', '', $d['phone']) ?? '';
  $logo = __DIR__ . '/email-logo.png';
  if (!is_file($logo)) $logo = '';
  $files = $d['files'];
  $company = $d['company'];
  $brief = $d['brief'];
  $page = $d['page'];

  $text = implode("\r\n", [
    'ვებ-გვერდიდან ახალი მოთხოვნა' . ($d['id'] ? ' #' . $d['id'] : ''),
    '',
    'სახელი და გვარი: ' . $d['fullname'],
    'ელ. ფოსტა:       ' . $d['email'],
    'ტელეფონი:        ' . $d['phone'],
    'კომპანია:        ' . ($company !== '' ? $company : '-'),
    '',
    'მოთხოვნა:',
    $brief !== '' ? $brief : '-',
    '',
    'ფაილები:         ' . ($files ? count($files) . ' (მიმაგრებულია)' : '-'),
    '',
    'კონფიდენციალურობის პოლიტიკა: დაეთანხმა',
    'მონაცემთა დამუშავება:        დაეთანხმა',
    'მარკეტინგული მიზნები:        ' . ($d['marketing'] ? 'თანახმაა' : 'არ არის თანახმა'),
    '',
    'გვერდი: ' . ($page !== '' ? $page : '-') . ' (' . $langName . ')',
    'დრო:    ' . $d['when'] . ' - ' . $d['site'],
    '',
    'პასუხისთვის უბრალოდ დააჭირეთ "Reply" - წერილი მივა ' . $d['email'] . '-ზე.',
  ]) . "\r\n";

  $logoHtml = $logo
    ? '<img src="cid:biomi-logo@biomi.ge" width="180" height="30" alt="ბიომი ჰოლდინგი" style="display:block;border:0;outline:none;width:180px;height:30px;">'
    : '<span style="font-family:' . MAIL_FONT . ';font-size:22px;font-weight:700;color:#ffffff;">ბიომი</span>';
  $badge = ($d['test'] ? '<span style="display:inline-block;padding:3px 9px;margin-right:8px;border-radius:4px;background:#85519a;color:#ffffff;font-weight:700;">TEST</span>' : '')
         . ($d['id'] ? '#' . $d['id'] : '');

  $contactRows = mailRow('სახელი და გვარი', h($d['fullname']), true)
    . mailRow('ელ. ფოსტა', '<a href="mailto:' . h($d['email']) . '" style="color:#0249f7;text-decoration:none;">' . h($d['email']) . '</a>')
    . mailRow('ტელეფონი', '<a href="tel:' . h($tel) . '" style="color:#0249f7;text-decoration:none;">' . h($d['phone']) . '</a>')
    . mailRow('კომპანია', $company !== '' ? h($company) : '<span style="color:#a7abb2;">-</span>');

  $fileRows = '';
  foreach ($files as $i => $f) {
    $fileRows .= mailRow($i === 0 ? 'PDF' : '&nbsp;',
      h($f['name']) . ' <span style="color:#6c6f72;font-size:13px;">&middot; ' . max(1, (int)round($f['size'] / 1024)) . ' KB</span>', $i === 0);
  }

  $replyHref = 'mailto:' . h($d['email']) . '?subject=' . rawurlencode('Re: ' . $core);
  $pageHtml = $page !== ''
    ? '<a href="' . h($page) . '" style="color:#6c6f72;">' . h(preg_replace('#^https?://#', '', $page) ?? $page) . '</a>'
    : '-';
  $cell = 'font-family:' . MAIL_FONT . ';';

  $html = '<!doctype html><html lang="ka"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    . '<title>' . h($subject) . '</title></head>'
    . '<body style="margin:0;padding:0;background:#f1f4fc;">'
    . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f1f4fc" style="background:#f1f4fc;">'
    . '<tr><td align="center" style="padding:28px 12px;">'
    . '<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="#ffffff" style="width:100%;max-width:600px;background:#ffffff;border:1px solid #e7e6ea;border-radius:14px;">'

    // header band
    . '<tr><td bgcolor="#1b1b33" style="background:#1b1b33;padding:22px 32px;border-radius:14px 14px 0 0;">'
    .   '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
    .     '<td valign="middle">' . $logoHtml . '</td>'
    .     '<td valign="middle" align="right" style="' . $cell . 'font-size:13px;color:#8ba4fb;white-space:nowrap;">' . $badge . '</td>'
    .   '</tr></table>'
    . '</td></tr>'

    // title
    . '<tr><td style="padding:28px 32px 0;' . $cell . 'font-size:13px;line-height:18px;font-weight:700;color:#0238be;">ახალი მოთხოვნა ვებ-გვერდიდან</td></tr>'
    . '<tr><td style="padding:6px 32px 0;' . $cell . 'font-size:24px;line-height:31px;font-weight:700;color:#1b1b33;">' . h($d['fullname']) . '</td></tr>'
    . '<tr><td style="padding:4px 32px 0;' . $cell . 'font-size:14px;line-height:20px;color:#6c6f72;">'
    .   ($company !== '' ? h($company) . ' &middot; ' : '') . h($d['when']) . '</td></tr>'

    // contact
    . mailHeading('საკონტაქტო ინფორმაცია')
    . '<tr><td style="padding:0 32px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' . $contactRows . '</table></td></tr>'

    // message
    . mailHeading('მოთხოვნა')
    . '<tr><td style="padding:0 32px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
    .   '<td bgcolor="#f1f4fc" style="background:#f1f4fc;border-left:3px solid #0249f7;padding:14px 18px;' . $cell . 'font-size:15px;line-height:23px;color:#1b1b33;">'
    .     ($brief !== '' ? nl2br(h($brief), false) : '<span style="color:#a7abb2;">მოთხოვნა არ დაწერა</span>')
    .   '</td></tr></table></td></tr>'

    // files
    . ($files ? mailHeading('მიმაგრებული ფაილები (' . count($files) . ')')
        . '<tr><td style="padding:0 32px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' . $fileRows . '</table></td></tr>' : '')

    // consents
    . mailHeading('თანხმობები')
    . '<tr><td style="padding:0 32px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
    .   mailRow('კონფიდენციალურობის პოლიტიკა', mailTick(true, 'დაეთანხმა', 'არ დაეთანხმა'), true)
    // both required: the form cannot be sent without them
    .   mailRow('მონაცემთა დამუშავება', mailTick(true, 'დაეთანხმა', 'არ დაეთანხმა'))
    .   mailRow('მარკეტინგული მიზნები', mailTick((bool)$d['marketing'], 'თანახმაა', 'არ არის თანახმა'))
    . '</table></td></tr>'

    // actions
    . '<tr><td style="padding:28px 32px 4px;"><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>'
    .   '<td bgcolor="#0249f7" align="center" style="background:#0249f7;border-radius:8px;padding:12px 22px;"><a href="' . $replyHref . '" style="' . $cell . 'font-size:14px;font-weight:700;color:#ffffff;text-decoration:none;"><span style="color:#ffffff;">პასუხი ელ. ფოსტით</span></a></td>'
    .   '<td width="10" style="width:10px;">&nbsp;</td>'
    .   ($tel !== '' ? '<td bgcolor="#ffffff" align="center" style="border:2px solid #1b1b33;border-radius:8px;padding:10px 20px;"><a href="tel:' . h($tel) . '" style="' . $cell . 'font-size:14px;font-weight:700;color:#1b1b33;text-decoration:none;"><span style="color:#1b1b33;">დარეკვა</span></a></td>' : '')
    . '</tr></table></td></tr>'

    // footer
    . '<tr><td style="padding:24px 32px 26px;' . $cell . 'font-size:12px;line-height:19px;color:#6c6f72;">'
    .   '<div style="border-top:1px solid #e7e6ea;padding-top:16px;">'
    .     'გვერდი: ' . $pageHtml . ' &middot; ' . h($langName) . ' ვერსია<br>'
    .     'გაგზავნილია ' . h($d['when']) . ' &middot; ' . h($d['site']) . '<br>'
    .     'ამ წერილზე "Reply" პასუხს პირდაპირ გაუგზავნის ' . h($d['email']) . '-ს.'
    .   '</div>'
    . '</td></tr>'

    . '</table></td></tr></table></body></html>';

  return ['subject' => $subject, 'text' => $text, 'html' => $html, 'logo' => $logo];
}

/* ------------------------------------------------------------ health check */
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'GET') {
  // Test site only: the office email with made-up details, shown in the browser.
  // Nothing is sent or stored.
  if (isset($_GET['preview']) && str_starts_with(strtolower((string)($_SERVER['HTTP_HOST'] ?? '')), 'test.')) {
    $m = mailParts([
      'id' => 12, 'fullname' => 'ნინო ბერიძე', 'email' => 'nino@example.com', 'phone' => '+995 555 12 34 56',
      'company' => 'შპს მაგალითი', 'brief' => "საოფისე შენობა, 1200 მ².\nგვჭირდება VRF გაგრილება და ვენტილაცია, პროექტი ესკიზის ეტაპზეა.",
      'files' => [['name' => 'ნახაზი-1.pdf', 'size' => 348000], ['name' => 'spec.pdf', 'size' => 91000]],
      'marketing' => !isset($_GET['nomarketing']), 'page' => 'https://test.biomi.ge/', 'lang' => 'ka',
      'site' => 'test.biomi.ge', 'test' => true, 'when' => date('Y-m-d H:i'),
    ]);
    header('Content-Type: text/html; charset=utf-8');
    echo str_replace('cid:biomi-logo@biomi.ge', 'email-logo.png', $m['html']);
    exit;
  }
  if (!isset($_GET['check'])) fail('method', 405);
  $pdo = db($cfg);
  $out = [
    'php'         => PHP_VERSION,
    'config'      => $cfg !== null,
    'database'    => $pdo !== null,
    'mail'        => function_exists('mail'),
    'upload_max'  => ini_get('upload_max_filesize'),
    'post_max'    => ini_get('post_max_size'),
    'max_uploads' => ini_get('max_file_uploads'),
  ];
  // On the test site only: how the last few sends went - times and results,
  // nothing a visitor typed.
  if ($pdo && str_starts_with(strtolower((string)($_SERVER['HTTP_HOST'] ?? '')), 'test.')) {
    try {
      $out['recent'] = $pdo->query('SELECT id, created_at, mail_sent, mail_error, files <> \'\' AS had_files
                                    FROM form_requests ORDER BY id DESC LIMIT 3')->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) { $out['recent'] = 'unreadable'; }
  }
  answer($out);
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail('method', 405);

/* A browser posting from some other website is refused. (Scripts that send no
   Origin get through to the checks below, which is what the rate limit is for.) */
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed = $cfg['allowed_origins'] ?? ['https://biomi.ge', 'https://www.biomi.ge', 'https://test.biomi.ge'];
if ($origin !== '' && !in_array($origin, $allowed, true)) fail('origin', 403);

/* A POST bigger than post_max_size arrives with $_POST and $_FILES empty. */
$len = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
if ($len > 0 && empty($_POST) && empty($_FILES)) fail('too_large', 413);

if (!$cfg) { error_log('biomi contact: biomi-config.php not found at ' . $cfgFile); fail('setup', 500); }

/* Honeypot: a field people never see. Bots that fill every box get a quiet
   "ok" and nothing is sent or stored. */
if (trim((string)($_POST['website'] ?? '')) !== '') answer(['ok' => true]);

/* ---------------------------------------------------------------- the form */
function line(string $key, int $max): string {
  $v = (string)($_POST[$key] ?? '');
  $v = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $v) ?? '';   // one line, no header tricks
  $v = trim(preg_replace('/\s+/u', ' ', $v) ?? '');
  return mb_substr($v, 0, $max);
}
$fullname = line('fullname', 120);
$email    = line('email', 190);
$phone    = line('phone', 40);
$company  = line('company', 150);
$page     = line('page', 300);
$lang     = ($_POST['lang'] ?? '') === 'en' ? 'en' : 'ka';
$brief    = trim(str_replace("\r\n", "\n", (string)($_POST['brief'] ?? '')));
$brief    = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]+/u', '', $brief) ?? '';
$privacy  = isset($_POST['privacy']) && $_POST['privacy'] !== '';
$processing = isset($_POST['processing']) && $_POST['processing'] !== '';   // consent.html - required
$marketing = isset($_POST['marketing']) && $_POST['marketing'] !== '';     // marketing.html - optional

$digits = preg_replace('/\D+/', '', $phone) ?? '';
if (mb_strlen($fullname) < 2
    || !filter_var($email, FILTER_VALIDATE_EMAIL)
    || strlen($digits) < 7 || strlen($digits) > 15 || !preg_match('/^[\d\s()+\-.]+$/', $phone)
    || mb_strlen($brief) > 4000 || count(preg_split('/\s+/u', $brief, -1, PREG_SPLIT_NO_EMPTY)) > 300) {
  fail('invalid');
}
if (!$privacy || !$processing) fail('consent');

/* PDFs: checked by their first bytes, not by the name the browser sent. */
$files = [];
if (!empty($_FILES['files']) && is_array($_FILES['files']['name'])) {
  $total = 0;
  foreach ($_FILES['files']['name'] as $i => $name) {
    $err = $_FILES['files']['error'][$i];
    if ($err === UPLOAD_ERR_NO_FILE) continue;
    if ($err === UPLOAD_ERR_INI_SIZE || $err === UPLOAD_ERR_FORM_SIZE) fail('too_large', 413);
    if ($err !== UPLOAD_ERR_OK) fail('file');
    $tmp = $_FILES['files']['tmp_name'][$i];
    $size = (int)$_FILES['files']['size'][$i];
    $total += $size;
    if (count($files) >= MAX_FILES || $size > MAX_FILE || $total > MAX_TOTAL) fail('too_large', 413);
    if (!is_uploaded_file($tmp)) fail('file');
    $head = (string)file_get_contents($tmp, false, null, 0, 1024);
    if (strpos($head, '%PDF-') === false) fail('file');
    $clean = preg_replace('/[\x00-\x1F\x7F"\\\\\/]+/u', '', basename((string)$name)) ?: 'document';
    if (!preg_match('/\.pdf$/i', $clean)) $clean .= '.pdf';
    $files[] = ['name' => mb_substr($clean, 0, 120), 'tmp' => $tmp, 'size' => $size];
  }
}

$ip   = substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45);
$ua   = mb_substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255);
$site = strtolower(preg_replace('/[^A-Za-z0-9.\-]/', '', (string)($_SERVER['HTTP_HOST'] ?? '')) ?? '');
$now  = date('Y-m-d H:i:s');
$isTest = str_starts_with($site, 'test.');

/* Which text the visitor agreed to: a fingerprint of the three documents the
   form links as they were on the server at that moment. No version number to
   forget to bump. */
$policy = [];
foreach (['privacy'   => ($lang === 'en' ? 'privacy-en.html' : 'privacy.html'),
          'consent'   => ($lang === 'en' ? 'consent-en.html' : 'consent.html'),
          'marketing' => ($lang === 'en' ? 'marketing-en.html' : 'marketing.html')] as $k => $f) {
  $p = dirname(__DIR__) . '/' . $f;
  $policy[] = $k . ':' . (is_file($p) ? substr((string)sha1_file($p), 0, 12) : 'missing');
}
$policyVersion = implode(' ', $policy);

/* ---------------------------------------------------- rate limit + the log */
$pdo = db($cfg);
$requestId = 0;
if ($pdo) {
  try {
    $q = $pdo->prepare('SELECT COUNT(*) FROM form_requests WHERE ip = ? AND created_at > ?');
    $q->execute([$ip, date('Y-m-d H:i:s', time() - RATE_MIN * 60)]);
    if ((int)$q->fetchColumn() >= RATE_IP) fail('rate', 429);

    $fileList = implode("\n", array_map(fn($f) => $f['name'] . ' (' . round($f['size'] / 1024) . ' KB)', $files));
    $pdo->prepare('INSERT INTO form_requests (created_at, site, lang, page, fullname, email, phone, company, brief, files, ip, user_agent)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?)')
        ->execute([$now, $site, $lang, $page, $fullname, $email, $phone, $company, $brief, $fileList, $ip, $ua]);
    $requestId = (int)$pdo->lastInsertId();
    $pdo->prepare('INSERT INTO form_consents (request_id, created_at, email, phone, privacy, processing, marketing, policy_version, ip)
                   VALUES (?,?,?,?,?,?,?,?,?)')
        ->execute([$requestId, $now, $email, $phone, 1, 1, $marketing ? 1 : 0, $policyVersion, $ip]);

    // Nothing is kept longer than the consent documents promise (KEEP_MONTHS).
    $cut = date('Y-m-d H:i:s', strtotime('-' . KEEP_MONTHS . ' months'));
    $pdo->prepare('DELETE FROM form_requests WHERE created_at < ?')->execute([$cut]);
    $pdo->prepare('DELETE FROM form_consents WHERE created_at < ? AND marketing = 0')->execute([$cut]);
  } catch (Throwable $e) {
    // The log failing must not lose the enquiry: the mail still goes, and it
    // carries the consents too.
    error_log('biomi contact: log: ' . $e->getMessage());
  }
}

/* ------------------------------------------------------------------- mail */
$to   = (string)($cfg['mail_to'] ?? 'marketing@biomi.ge');
$from = (string)($cfg['mail_from'] ?? $to);
$mail = mailParts([
  'id' => $requestId, 'fullname' => $fullname, 'email' => $email, 'phone' => $phone, 'company' => $company,
  'brief' => $brief, 'files' => $files, 'marketing' => $marketing, 'page' => $page, 'lang' => $lang,
  'site' => $site, 'test' => $isTest, 'when' => date('Y-m-d H:i'),
]);

/* MIME: text + HTML as alternatives; the logo rides with the HTML (related);
   PDFs, if any, wrap the lot (mixed). */
$alt = 'alt-' . bin2hex(random_bytes(10));
$altBody = "--$alt\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
         . chunk_split(base64_encode($mail['text']));
if ($mail['logo']) {
  $rel = 'rel-' . bin2hex(random_bytes(10));
  $altBody .= "--$alt\r\nContent-Type: multipart/related; boundary=\"$rel\"\r\n\r\n"
            . "--$rel\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
            . chunk_split(base64_encode($mail['html']))
            . "--$rel\r\nContent-Type: image/png; name=\"biomi-logo.png\"\r\nContent-Transfer-Encoding: base64\r\n"
            . "Content-ID: <biomi-logo@biomi.ge>\r\nContent-Disposition: inline; filename=\"biomi-logo.png\"\r\n\r\n"
            . chunk_split(base64_encode((string)file_get_contents($mail['logo'])))
            . "--$rel--\r\n";
} else {
  $altBody .= "--$alt\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
            . chunk_split(base64_encode($mail['html']));
}
$altBody .= "--$alt--\r\n";

$headers = [
  'From: ' . enc('Biomi ვებ-გვერდი') . ' <' . $from . '>',
  'Reply-To: ' . $email,
  'MIME-Version: 1.0',
  'X-Mailer: biomi.ge contact form',
];
if (!$files) {
  $headers[] = 'Content-Type: multipart/alternative; boundary="' . $alt . '"';
  $body = "This is a multi-part message in MIME format.\r\n" . $altBody;
} else {
  $mix = 'mix-' . bin2hex(random_bytes(10));
  $headers[] = 'Content-Type: multipart/mixed; boundary="' . $mix . '"';
  $body = "This is a multi-part message in MIME format.\r\n"
        . "--$mix\r\nContent-Type: multipart/alternative; boundary=\"$alt\"\r\n\r\n" . $altBody;
  foreach ($files as $f) {
    $ascii = preg_replace('/[^A-Za-z0-9._\- ]+/', '_', $f['name']) ?: 'document.pdf';
    $body .= "--$mix\r\n"
           . "Content-Type: application/pdf; name=\"$ascii\"\r\n"
           . "Content-Transfer-Encoding: base64\r\n"
           . "Content-Disposition: attachment; filename=\"$ascii\"; filename*=UTF-8''" . rawurlencode($f['name']) . "\r\n\r\n"
           . chunk_split(base64_encode((string)file_get_contents($f['tmp'])));
  }
  $body .= "--$mix--\r\n";
}
$subject = $mail['subject'];

$sent = false; $mailError = '';
try {
  $sent = mail($to, enc($subject), $body, implode("\r\n", $headers), '-f' . $from);
  if (!$sent) { $last = error_get_last(); $mailError = 'mail() returned false' . ($last ? ': ' . $last['message'] : ''); }
} catch (Throwable $e) {
  $mailError = 'mail: ' . $e->getMessage();
}
if ($mailError !== '') error_log('biomi contact: ' . $mailError);

if ($pdo && $requestId) {
  try {
    $pdo->prepare('UPDATE form_requests SET mail_sent = ?, mail_error = ? WHERE id = ?')
        ->execute([$sent ? 1 : 0, mb_substr($mailError, 0, 255), $requestId]);
  } catch (Throwable $e) { error_log('biomi contact: log update: ' . $e->getMessage()); }
}

if (!$sent) fail('mail', 502);
answer(['ok' => true]);
