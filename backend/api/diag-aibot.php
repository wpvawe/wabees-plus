<?php
/**
 * AI Bot Diagnostic — Check Firestore data + flow + logs
 * Usage: GET /api/diag-aibot.php              → shows log + finds AI-enabled users
 *        GET /api/diag-aibot.php?userId=xxx   → full check for specific user
 */
header('Content-Type: application/json');
require_once __DIR__ . '/../config/firebase-config.php';

$userId = $_GET['userId'] ?? '';
$result = [];

// Always show recent logs
$logFile = __DIR__ . '/../logs/webhook_' . date('Y-m-d') . '.log';
if (file_exists($logFile)) {
    $lines = file($logFile, FILE_IGNORE_NEW_LINES);
    $aiLines = array_filter($lines, fn($l) => stripos($l, 'AI_BOT') !== false || stripos($l, 'ai_bot') !== false);
    $result['aiLogs'] = array_values(array_slice($aiLines, -15));
    $result['lastLogLines'] = array_values(array_slice($lines, -10));
    $result['totalLogLines'] = count($lines);
} else {
    $result['aiLogs'] = [];
    $result['lastLogLines'] = ['no log file for today'];
}

// Find users with aiBotEnabled=true
$url = "https://firestore.googleapis.com/v1/projects/" . FIREBASE_PROJECT_ID
    . "/databases/(default)/documents:runQuery";
$body = json_encode([
    'structuredQuery' => [
        'from' => [['collectionId' => 'users']],
        'where' => [
            'fieldFilter' => [
                'field' => ['fieldPath' => 'aiBotEnabled'],
                'op' => 'EQUAL',
                'value' => ['booleanValue' => true],
            ],
        ],
        'limit' => 10,
    ],
]);
$ch = curl_init($url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, get_firebase_auth_headers());
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
$resp = curl_exec($ch);
curl_close($ch);
$rows = json_decode($resp, true) ?: [];
$enabledUsers = [];
foreach ($rows as $r) {
    if (!isset($r['document'])) continue;
    $docName = $r['document']['name'] ?? '';
    $parts = explode('/', $docName);
    $uid = end($parts);
    $fields = $r['document']['fields'] ?? [];
    $enabledUsers[] = [
        'userId' => $uid,
        'businessName' => $fields['businessName']['stringValue'] ?? '?',
        'aiBotEnabled' => $fields['aiBotEnabled']['booleanValue'] ?? false,
    ];
}
$result['aiBotEnabledUsers'] = $enabledUsers;

// If specific userId given, do full check
if (!empty($userId)) {
    $userDoc = firestore_get("users/$userId");
    $result['userDoc'] = [
        'code' => $userDoc['code'] ?? 'null',
        'aiBotEnabled' => $userDoc['data']['fields']['aiBotEnabled']['booleanValue'] ?? 'NOT_SET',
        'hasAccessToken' => isset($userDoc['data']['fields']['whatsappAccessToken']),
    ];

    $configResp = firestore_get("users/$userId/bot_config/settings");
    $result['botConfig'] = [
        'code' => $configResp['code'] ?? 'null',
        'enabled' => $configResp['data']['fields']['enabled']['booleanValue'] ?? 'NOT_SET',
        'businessName' => $configResp['data']['fields']['businessName']['stringValue'] ?? 'NOT_SET',
    ];

    $usageResp = firestore_get("users/$userId/bot_usage/current");
    $result['botUsage'] = [
        'code' => $usageResp['code'] ?? 'null',
    ];
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
