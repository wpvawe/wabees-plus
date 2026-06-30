<?php
/**
 * WABEES — Media Proxy v2 (Range-aware)
 *
 * - Resolves agent → owner for access token
 * - Supports HTTP Range requests (needed for audio/video streaming)
 *
 * GET /api/media-proxy.php?id=<mediaId>&uid=<userId>
 */

require_once __DIR__ . '/../config/firebase-config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Range');

$mediaId = $_GET['id']  ?? '';
$userId  = $_GET['uid'] ?? '';

if (empty($mediaId) || empty($userId)) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'id and uid required']);
    exit;
}

// ── Resolve owner (agents → owner) ──────────────────────────────
function _proxy_resolve_owner(string $uid): string {
    $cacheKey = "wabees_owner_{$uid}";
    if (function_exists('apcu_fetch')) {
        $v = apcu_fetch($cacheKey, $ok);
        if ($ok && $v) return $v;
    }
    $doc = firestore_get("users/{$uid}");
    $owner = ($doc['code'] === 200)
        ? ($doc['data']['fields']['dataOwner']['stringValue'] ?? null)
        : null;
    $result = ($owner && $owner !== $uid) ? $owner : $uid;
    if (function_exists('apcu_store')) apcu_store($cacheKey, $result, 3600);
    return $result;
}

// ── Get access token for owner ───────────────────────────────────
function _proxy_get_token(string $ownerUid): ?string {
    $cacheKey = "wabees_media_token_{$ownerUid}";
    if (function_exists('apcu_fetch')) {
        $v = apcu_fetch($cacheKey, $ok);
        if ($ok && $v) return $v;
    }
    // Try whatsapp_config/config.accessToken
    $cfg = firestore_get("users/{$ownerUid}/whatsapp_config/config");
    if ($cfg['code'] === 200) {
        $token = $cfg['data']['fields']['accessToken']['stringValue'] ?? null;
        if ($token) {
            if (function_exists('apcu_store')) apcu_store($cacheKey, $token, 1800);
            return $token;
        }
    }
    // Fallback: user doc.whatsappAccessToken
    $udoc = firestore_get("users/{$ownerUid}");
    if ($udoc['code'] === 200) {
        $token = $udoc['data']['fields']['whatsappAccessToken']['stringValue'] ?? null;
        if ($token) {
            if (function_exists('apcu_store')) apcu_store($cacheKey, $token, 1800);
            return $token;
        }
    }
    return null;
}

$ownerUid    = _proxy_resolve_owner($userId);
$accessToken = _proxy_get_token($ownerUid);

if (!$accessToken) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Access token not found', 'uid' => $userId, 'owner' => $ownerUid]);
    exit;
}

// ── Step 1: Get WhatsApp download URL ────────────────────────────
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL            => "https://graph.facebook.com/v21.0/{$mediaId}",
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 15,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_IPRESOLVE      => CURL_IPRESOLVE_V4,
    CURLOPT_HTTPHEADER     => ["Authorization: Bearer {$accessToken}"],
]);
$metaResp = curl_exec($ch);
$metaCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($metaCode !== 200) {
    http_response_code(502);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'WhatsApp meta fetch failed', 'code' => $metaCode]);
    exit;
}

$meta        = json_decode($metaResp, true);
$downloadUrl = $meta['url'] ?? null;
$mimeType    = $meta['mime_type'] ?? 'application/octet-stream';
$fileSize    = isset($meta['file_size']) ? (int)$meta['file_size'] : 0;

if (!$downloadUrl) {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'No download URL in WhatsApp response']);
    exit;
}

// ── Detect extension ──────────────────────────────────────────────
$extMap = [
    'image/jpeg' => 'jpg', 'image/png'  => 'png', 'image/gif'  => 'gif',
    'image/webp' => 'webp','image/heic' => 'heic','image/bmp'  => 'bmp',
    'video/mp4'  => 'mp4', 'video/3gpp' => '3gp',
    'audio/mpeg' => 'mp3', 'audio/ogg'  => 'ogg', 'audio/ogg; codecs=opus' => 'ogg',
    'audio/amr'  => 'amr', 'audio/aac'  => 'aac', 'audio/mp4'  => 'm4a',
    'application/pdf' => 'pdf',
];
$cleanMime = explode(';', $mimeType)[0];
$ext       = $extMap[$cleanMime] ?? ($extMap[$mimeType] ?? 'bin');
$filename  = "media_{$mediaId}.{$ext}";

// ── Check local cache ─────────────────────────────────────────────
$cacheDir  = __DIR__ . '/../uploads/media/';
$cachePath = $cacheDir . "proxy_{$mediaId}.{$ext}";
if (!is_dir($cacheDir)) @mkdir($cacheDir, 0755, true);

$useCache = false;
if (file_exists($cachePath) && filesize($cachePath) > 0) {
    $useCache = true;
    $fileSize = filesize($cachePath);
}

// ── Step 2: Download if not cached ───────────────────────────────
if (!$useCache) {
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $downloadUrl,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 120,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_IPRESOLVE      => CURL_IPRESOLVE_V4,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_HTTPHEADER     => ["Authorization: Bearer {$accessToken}"],
    ]);
    $fileContent = curl_exec($ch);
    $dlCode      = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($dlCode !== 200 || empty($fileContent)) {
        http_response_code(502);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Media download failed', 'code' => $dlCode]);
        exit;
    }

    @file_put_contents($cachePath, $fileContent);
    $fileSize = strlen($fileContent);
}

// ── Step 3: Serve with Range support ─────────────────────────────
$rangeHeader = $_SERVER['HTTP_RANGE'] ?? null;

header("Content-Type: $mimeType");
header("Accept-Ranges: bytes");
header("Cache-Control: public, max-age=86400");
header("Content-Disposition: inline; filename=\"{$filename}\"");

if ($rangeHeader && preg_match('/bytes=(\d*)-(\d*)/', $rangeHeader, $m)) {
    // Partial content response
    $start = $m[1] !== '' ? (int)$m[1] : 0;
    $end   = $m[2] !== '' ? (int)$m[2] : $fileSize - 1;
    $end   = min($end, $fileSize - 1);
    $length = $end - $start + 1;

    http_response_code(206);
    header("Content-Range: bytes {$start}-{$end}/{$fileSize}");
    header("Content-Length: {$length}");

    if ($useCache) {
        $fp = fopen($cachePath, 'rb');
        fseek($fp, $start);
        echo fread($fp, $length);
        fclose($fp);
    } else {
        echo substr($fileContent, $start, $length);
    }
} else {
    // Full content
    header("Content-Length: {$fileSize}");
    if ($useCache) {
        readfile($cachePath);
    } else {
        echo $fileContent;
    }
}
