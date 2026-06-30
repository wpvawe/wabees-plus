<?php
/**
 * WABEES — Real-Time Stats Endpoint
 * wabees.live/stats.php
 * Returns aggregated platform stats as JSON (cached 60s)
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Cache-Control: public, max-age=60');

$stats = [
    'messages'      => 0,
    'users'         => 0,
    'agents'        => 0,
    'contacts'      => 0,
    'bots'          => 0,
    'conversations' => 0,
    'cached_at'     => time(),
];

try {
    $configPath = __DIR__ . '/config/firebase-config.php';
    if (!file_exists($configPath)) {
        echo json_encode($stats);
        exit;
    }
    require_once $configPath;

    // Try reading the aggregated stats document (fast path)
    // firestore_get_cached returns ['code'=>200, 'data'=>['fields'=>[...]]]
    $doc = firestore_get_cached('stats/global', 60);

    $f = $doc['data']['fields'] ?? null;
    if (!empty($f)) {
        $stats['messages']      = (int)($f['totalMessages']['integerValue']      ?? $f['totalMessages']['doubleValue']      ?? 0);
        $stats['users']         = (int)($f['totalUsers']['integerValue']          ?? $f['totalUsers']['doubleValue']          ?? 0);
        $stats['agents']        = (int)($f['totalAgents']['integerValue']         ?? $f['totalAgents']['doubleValue']         ?? 0);
        $stats['contacts']      = (int)($f['totalContacts']['integerValue']       ?? $f['totalContacts']['doubleValue']       ?? 0);
        $stats['bots']          = (int)($f['totalBots']['integerValue']           ?? $f['totalBots']['doubleValue']           ?? 0);
        $stats['conversations'] = (int)($f['totalConversations']['integerValue']  ?? $f['totalConversations']['doubleValue']  ?? 0);
    }
} catch (Throwable $e) {
    // silent — return zeros, JS handles gracefully
}

echo json_encode($stats);
