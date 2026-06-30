<?php
/**
 * WABEES — Real-Time Stats Endpoint (live aggregated counts)
 * wabees.live/stats.php
 * Computes counts via Firestore aggregation queries (COUNT) and caches 5 min.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Cache-Control: public, max-age=300');

$out = [
    'messages'      => 0,
    'users'         => 0,
    'agents'        => 0,
    'contacts'      => 0,
    'bots'          => 0,
    'conversations' => 0,
    'cached_at'     => time(),
];

$cacheFile = __DIR__ . '/cache/stats_live.json';
$TTL = 300; // 5 minutes

// Serve cache
if (file_exists($cacheFile) && (time() - filemtime($cacheFile)) < $TTL) {
    $c = json_decode(@file_get_contents($cacheFile), true);
    if (is_array($c)) {
        $c['cached_at'] = filemtime($cacheFile);
        echo json_encode($c);
        exit;
    }
}

try {
    require_once __DIR__ . '/config/firebase-config.php';

    function _wabees_count($collectionId, $allDescendants) {
        $url = 'https://firestore.googleapis.com/v1/projects/' . FIREBASE_PROJECT_ID
            . '/databases/(default)/documents:runAggregationQuery';
        $body = [
            'structuredAggregationQuery' => [
                'structuredQuery' => [
                    'from' => [[ 'collectionId' => $collectionId, 'allDescendants' => (bool)$allDescendants ]],
                ],
                'aggregations' => [[ 'alias' => 'c', 'count' => (object)[] ]],
            ],
        ];
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
        curl_setopt($ch, CURLOPT_HTTPHEADER, get_firebase_auth_headers());
        curl_setopt($ch, CURLOPT_TIMEOUT, 15);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
        curl_setopt($ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
        $resp = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($code !== 200) {
            error_log("[WABEES stats] count($collectionId) http=$code resp=" . substr((string)$resp, 0, 300));
            return 0;
        }
        $data = json_decode($resp, true);
        // Response is an array of {result:{aggregateFields:{c:{integerValue:"N"}}}}
        if (is_array($data)) {
            foreach ($data as $row) {
                $v = $row['result']['aggregateFields']['c'] ?? null;
                if ($v !== null) {
                    return (int)($v['integerValue'] ?? $v['doubleValue'] ?? 0);
                }
            }
        }
        return 0;
    }

    $out['users']         = _wabees_count('users', false);
    $out['messages']      = _wabees_count('messages', true);
    $out['agents']        = _wabees_count('agents', true);
    $out['contacts']      = _wabees_count('contacts', true);
    $out['bots']          = _wabees_count('bots', true);
    $out['conversations'] = _wabees_count('conversations', true);
    $out['cached_at']     = time();

    // Write cache
    @mkdir(dirname($cacheFile), 0755, true);
    @file_put_contents($cacheFile, json_encode($out));
} catch (Throwable $e) {
    error_log('[WABEES stats] ' . $e->getMessage());
}

echo json_encode($out);
