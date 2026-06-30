<?php
/**
 * WABEES — Get WhatsApp Monthly Analytics
 * 
 * POST /api/get-analytics.php
 * Body: { business_account_id, access_token, phone_number_id, start, end }
 *   start/end = Unix timestamps
 * 
 * Returns: conversation analytics with category breakdown, pricing info
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => ['message' => 'Method not allowed']]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$businessAccountId = $input['business_account_id'] ?? '';
$accessToken = $input['access_token'] ?? '';
$phoneNumberId = $input['phone_number_id'] ?? '';
$startTs = $input['start'] ?? (time() - 30 * 86400); // default 30 days ago
$endTs = $input['end'] ?? time();

if (empty($businessAccountId) || empty($accessToken)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'business_account_id and access_token are required']]);
    exit;
}

$result = [];

// ============ 1. MESSAGE ANALYTICS (sent/delivered/received) ============
$phoneFilter = !empty($phoneNumberId) ? '.phone_numbers(["' . $phoneNumberId . '"])' : '';
$analyticsUrl = "https://graph.facebook.com/v21.0/{$businessAccountId}?fields=analytics.start({$startTs}).end({$endTs}).granularity(DAY){$phoneFilter}";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $analyticsUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Authorization: Bearer {$accessToken}",
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    $logFile = __DIR__ . '/../logs/analytics_' . date('Y-m-d') . '.log';
    $logDir = dirname($logFile);
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    file_put_contents(
        $logFile,
        date('H:i:s') . " MSG_HTTP=$httpCode URL=$analyticsUrl RESPONSE=$response\n",
        FILE_APPEND
    );
}

// Add debug info to response
$debugInfo = [
    'url' => $analyticsUrl,
    'http_code' => $httpCode,
    'response' => json_decode($response, true),
    'phone_filter' => $phoneFilter,
];

$data = json_decode($response, true) ?? [];

$totalSent = 0;
$totalDelivered = 0;
$totalReceived = 0;
$dailyData = [];

if ($httpCode === 200 && isset($data['analytics']['data_points'])) {
    foreach ($data['analytics']['data_points'] as $dp) {
        $sent = (int) ($dp['sent'] ?? 0);
        $delivered = (int) ($dp['delivered'] ?? 0);
        $received = (int) ($dp['received'] ?? 0);

        $totalSent += $sent;
        $totalDelivered += $delivered;
        $totalReceived += $received;

        $dailyData[] = [
            'start' => $dp['start'] ?? 0,
            'end' => $dp['end'] ?? 0,
            'sent' => $sent,
            'delivered' => $delivered,
            'received' => $received,
        ];
    }
}

$result['messages'] = [
    'sent' => $totalSent,
    'delivered' => $totalDelivered,
    'received' => $totalReceived,
    'daily' => $dailyData,
];

// ============ 2. CONVERSATION ANALYTICS (category breakdown) ============
// Use curl_multi to fetch ALL categories IN PARALLEL (instead of 5 sequential calls)
$categories = ['AUTHENTICATION', 'MARKETING', 'UTILITY', 'SERVICE', 'REFERRAL_CONVERSION'];
$conversationData = [];

$mh = curl_multi_init();
$handles = [];

foreach ($categories as $cat) {
    $convUrl = "https://graph.facebook.com/v21.0/{$businessAccountId}?fields="
        . "conversation_analytics.start({$startTs}).end({$endTs})"
        . ".granularity(DAILY)"
        . '.conversation_category(["' . $cat . '"])'
        . '.conversation_type(["FREE_TIER","REGULAR"])'
        . '.dimensions(["CONVERSATION_CATEGORY","CONVERSATION_TYPE"])';

    if (!empty($phoneNumberId)) {
        $convUrl .= '.phone_numbers(["' . $phoneNumberId . '"])';
    }

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $convUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer {$accessToken}",
    ]);

    curl_multi_add_handle($mh, $ch);
    $handles[$cat] = $ch;
}

// Execute all requests in parallel
$running = null;
do {
    curl_multi_exec($mh, $running);
    curl_multi_select($mh);
} while ($running > 0);

// Collect results
foreach ($categories as $cat) {
    $ch = $handles[$cat];
    $convResponse = curl_multi_getcontent($ch);
    $convHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    if ($convHttpCode !== 200) {
        $logFile = __DIR__ . '/../logs/analytics_' . date('Y-m-d') . '.log';
        $logDir = dirname($logFile);
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        file_put_contents(
            $logFile,
            date('H:i:s') . " CONV_HTTP=$convHttpCode CAT=$cat RESPONSE=$convResponse\n",
            FILE_APPEND
        );
    }

    $convData = json_decode($convResponse, true) ?? [];

    $free = 0;
    $paid = 0;

    if ($convHttpCode === 200 && isset($convData['conversation_analytics']['data'])) {
        foreach ($convData['conversation_analytics']['data'] as $entry) {
            $dataPoints = $entry['data_points'] ?? [];
            foreach ($dataPoints as $dp) {
                $count = (int) ($dp['conversation'] ?? 0);
                $convType = $dp['conversation_type'] ?? 'REGULAR';
                if ($convType === 'FREE_TIER') {
                    $free += $count;
                } else {
                    $paid += $count;
                }
            }
        }
    }

    $conversationData[$cat] = [
        'free' => $free,
        'paid' => $paid,
        'total' => $free + $paid,
    ];

    curl_multi_remove_handle($mh, $ch);
    curl_close($ch);
}

curl_multi_close($mh);

// Compute totals
$totalFree = 0;
$totalPaid = 0;
foreach ($conversationData as $catData) {
    $totalFree += $catData['free'];
    $totalPaid += $catData['paid'];
}

// Per-category pricing (approximate, INR per conversation — Meta's standard rates)
$pricing = [
    'AUTHENTICATION' => 0.30,
    'MARKETING' => 0.78,
    'UTILITY' => 0.30,
    'SERVICE' => 0.35,
    'REFERRAL_CONVERSION' => 0.00,
];

$totalCost = 0.0;
$costBreakdown = [];
foreach ($conversationData as $cat => $catData) {
    $rate = $pricing[$cat] ?? 0.0;
    $catCost = $catData['paid'] * $rate;
    $totalCost += $catCost;
    $costBreakdown[$cat] = [
        'rate' => $rate,
        'cost' => round($catCost, 2),
    ];
}

$result['conversations'] = [
    'categories' => $conversationData,
    'total_free' => $totalFree,
    'total_paid' => $totalPaid,
    'total' => $totalFree + $totalPaid,
];

$result['billing'] = [
    'currency' => 'INR',
    'cost_breakdown' => $costBreakdown,
    'total_cost' => round($totalCost, 2),
    'free_conversations' => $totalFree,
    'paid_conversations' => $totalPaid,
];

$result['period'] = [
    'start' => (int) $startTs,
    'end' => (int) $endTs,
];

$result['debug'] = $debugInfo;

echo json_encode($result);
?>
