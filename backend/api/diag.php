<?php
/**
 * DIAGNOSTIC — Tests timing of the full webhook pipeline
 * Access at: https://api.wabees.live/api/diag.php
 * DELETE THIS FILE AFTER DEBUGGING
 */
header('Content-Type: application/json');

$results = [];
$t0 = microtime(true);

// 1. Load config
require_once __DIR__ . '/../config/firebase-config.php';
require_once __DIR__ . '/../config/firebase-admin.php';
$results['project_id'] = FIREBASE_PROJECT_ID;
$results['t1_config'] = round((microtime(true) - $t0) * 1000) . 'ms';

// 2. Get token
$t1 = microtime(true);
$token = get_firebase_admin_token();
$results['token'] = $token ? 'GOT (' . strlen($token) . ' chars)' : 'NULL';
$results['t2_token'] = round((microtime(true) - $t1) * 1000) . 'ms';

// 3. Read wa_map
$t2 = microtime(true);
$waMapResult = firestore_get('wa_map/968371416366913');
$results['wa_map'] = 'code=' . $waMapResult['code'];
$results['t3_wa_map'] = round((microtime(true) - $t2) * 1000) . 'ms';

// 4. Read user doc
$t3 = microtime(true);
$uid = $waMapResult['data']['fields']['userId']['stringValue'] ?? 'none';
$userResult = firestore_get("users/$uid");
$results['user'] = 'code=' . $userResult['code'];
$results['t4_user'] = round((microtime(true) - $t3) * 1000) . 'ms';

// 5. Write test message
$t4 = microtime(true);
$writeResult = firestore_set("site_stats/diag_test", [
    'test' => true,
    'timestamp' => gmdate('Y-m-d\TH:i:s\Z'),
]);
$results['write'] = 'code=' . $writeResult['code'];
$results['t5_write'] = round((microtime(true) - $t4) * 1000) . 'ms';

// 6. Total
$results['t_total'] = round((microtime(true) - $t0) * 1000) . 'ms';

// 7. Check webhook log file for today
$logFile = __DIR__ . '/../logs/webhook_' . date('Y-m-d') . '.log';
if (file_exists($logFile)) {
    $lines = file($logFile, FILE_IGNORE_NEW_LINES);
    $last15 = array_slice($lines, -15);
    $results['recent_logs'] = $last15;
} else {
    $results['recent_logs'] = 'No log file for today';
}

// 8. Check cache file
$cacheFile = __DIR__ . '/../cache/wa_map.json';
if (file_exists($cacheFile)) {
    $data = json_decode(file_get_contents($cacheFile), true);
    $results['cache'] = count($data) . ' entries';
} else {
    $results['cache'] = 'NO CACHE FILE';
}

echo json_encode($results, JSON_PRETTY_PRINT);
?>