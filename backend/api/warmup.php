<?php
/**
 * WABEES — Container Warmup Endpoint
 * Pre-fetches JWT token, DNS + TLS for Firestore and Facebook API.
 * Also pre-warms the wa_map file cache so ALL accounts get instant resolution.
 * Called by startup script before container starts serving traffic.
 */

require_once __DIR__ . '/../config/firebase-admin.php';
require_once __DIR__ . '/../config/firebase-config.php';

$start = microtime(true);

// 1. Pre-warm Firebase Admin token (JWT exchange ~2-3s on cold start)
$token = get_firebase_admin_token();
$tokenMs = round((microtime(true) - $start) * 1000);

// 2. Pre-warm DNS + TLS to Firestore API AND load ALL wa_map docs
//    This ensures EVERY account gets instant user resolution from the first request
$t2 = microtime(true);
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://firestore.googleapis.com/v1/projects/' . FIREBASE_PROJECT_ID . '/databases/(default)/documents/wa_map?pageSize=200');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
curl_setopt($ch, CURLOPT_DNS_CACHE_TIMEOUT, 3600);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token,
    'Content-Type: application/json',
]);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);
$firestoreMs = round((microtime(true) - $t2) * 1000);

// 2b. Populate wa_map file cache from the response
$mapCount = 0;
if ($httpCode < 400 && !empty($response)) {
    $data = json_decode($response, true);
    $docs = $data['documents'] ?? [];
    $map = [];
    $now = time();

    foreach ($docs as $doc) {
        $docName = $doc['name'] ?? '';
        $fields = $doc['fields'] ?? [];
        $parts = explode('/', $docName);
        $pnid = end($parts);
        if (empty($pnid))
            continue;

        $uid = $fields['userId']['stringValue'] ?? null;
        if (!$uid)
            continue;

        $map[$pnid] = [
            'userId' => $uid,
            'ts' => $now,
        ];
    }

    if (!empty($map)) {
        $cacheFile = __DIR__ . '/../cache/wa_map.json';
        $cacheDir = dirname($cacheFile);
        if (!is_dir($cacheDir))
            @mkdir($cacheDir, 0755, true);
        @file_put_contents($cacheFile, json_encode($map));
        $mapCount = count($map);
    }
}

// 3. Pre-warm DNS + TLS to Facebook Graph API (bot replies go here)
$t3 = microtime(true);
$ch2 = curl_init();
curl_setopt($ch2, CURLOPT_URL, 'https://graph.facebook.com/v21.0/me');
curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch2, CURLOPT_TIMEOUT, 10);
curl_setopt($ch2, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
curl_setopt($ch2, CURLOPT_DNS_CACHE_TIMEOUT, 3600);
curl_setopt($ch2, CURLOPT_NOBODY, true);  // HEAD request, minimal data
curl_exec($ch2);
curl_close($ch2);
$fbMs = round((microtime(true) - $t3) * 1000);

$totalMs = round((microtime(true) - $start) * 1000);
error_log("[WABEES] WARMUP: token={$tokenMs}ms firestore={$firestoreMs}ms(maps=$mapCount) facebook={$fbMs}ms total={$totalMs}ms");

header('Content-Type: text/plain');
echo "OK {$totalMs}ms (maps=$mapCount)\n";

