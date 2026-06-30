<?php
/**
 * WABEES — Get WhatsApp Phone Number Insights
 * 
 * POST /api/get-insights.php
 * Body: { phone_number_id, access_token, business_account_id? }
 * 
 * Returns: quality rating, messaging limits, template analytics
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
$phoneNumberId = $input['phone_number_id'] ?? '';
$accessToken = $input['access_token'] ?? '';
$businessAccountId = $input['business_account_id'] ?? '';

if (empty($phoneNumberId) || empty($accessToken)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'phone_number_id and access_token are required']]);
    exit;
}

$result = [];

// ============ 1. PHONE NUMBER QUALITY + MESSAGING LIMITS ============
$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}?fields=quality_rating,messaging_limit_tier,display_phone_number,verified_name,code_verification_status,platform_type,status";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Authorization: Bearer {$accessToken}",
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$phoneData = json_decode($response, true) ?? [];

if ($httpCode === 200 && !isset($phoneData['error'])) {
    $qualityRating = $phoneData['quality_rating'] ?? 'UNKNOWN';
    $messagingTier = $phoneData['messaging_limit_tier'] ?? 'TIER_NOT_SET';

    // Map quality to simple label
    $qualityMap = [
        'GREEN' => ['label' => 'High', 'color' => 'green', 'emoji' => '✅'],
        'YELLOW' => ['label' => 'Medium', 'color' => 'yellow', 'emoji' => '⚠️'],
        'RED' => ['label' => 'Low', 'color' => 'red', 'emoji' => '🔴'],
        'UNKNOWN' => ['label' => 'Unknown', 'color' => 'grey', 'emoji' => '❓'],
    ];

    // Map tier to limit
    $tierMap = [
        'TIER_NOT_SET' => ['name' => 'Not Set', 'limit' => 250],
        'TIER_50' => ['name' => 'Tier 50', 'limit' => 50],
        'TIER_250' => ['name' => 'Tier 250', 'limit' => 250],
        'TIER_1K' => ['name' => 'Tier 1K', 'limit' => 1000],
        'TIER_2K' => ['name' => 'Tier 2K', 'limit' => 2000],
        'TIER_10K' => ['name' => 'Tier 10K', 'limit' => 10000],
        'TIER_100K' => ['name' => 'Tier 100K', 'limit' => 100000],
        'TIER_250K' => ['name' => 'Tier 250K', 'limit' => 250000],
        'TIER_500K' => ['name' => 'Tier 500K', 'limit' => 500000],
        'UNLIMITED' => ['name' => 'Unlimited', 'limit' => -1],
    ];

    $result['quality'] = $qualityMap[$qualityRating] ?? $qualityMap['UNKNOWN'];
    $result['quality']['raw'] = $qualityRating;
    $result['messaging_limit'] = $tierMap[$messagingTier] ?? $tierMap['TIER_NOT_SET'];
    $result['messaging_limit']['raw'] = $messagingTier;
    $result['phone'] = [
        'display' => $phoneData['display_phone_number'] ?? '',
        'verified_name' => $phoneData['verified_name'] ?? '',
        'status' => $phoneData['status'] ?? '',
        'platform' => $phoneData['platform_type'] ?? '',
    ];
} else {
    $result['quality'] = ['label' => 'Unknown', 'color' => 'grey', 'emoji' => '❓', 'raw' => 'UNKNOWN'];
    $result['messaging_limit'] = ['name' => 'Unknown', 'limit' => 0, 'raw' => 'UNKNOWN'];
    $result['phone'] = [];
    $result['quality_error'] = $phoneData['error']['message'] ?? 'Failed to fetch quality';
}

// ============ 2. TEMPLATE ANALYTICS (if business_account_id provided) ============
if (!empty($businessAccountId)) {
    $tplUrl = "https://graph.facebook.com/v21.0/{$businessAccountId}/message_templates?fields=name,status,quality_score,category,language&limit=100";

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $tplUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer {$accessToken}",
    ]);

    $tplResponse = curl_exec($ch);
    $tplHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $tplData = json_decode($tplResponse, true) ?? [];

    if ($tplHttpCode === 200 && isset($tplData['data'])) {
        $templates = [];
        $statusCounts = ['APPROVED' => 0, 'PENDING' => 0, 'REJECTED' => 0];

        foreach ($tplData['data'] as $tpl) {
            $status = $tpl['status'] ?? 'UNKNOWN';
            if (isset($statusCounts[$status])) {
                $statusCounts[$status]++;
            }

            $templates[] = [
                'name' => $tpl['name'] ?? '',
                'status' => $status,
                'quality_score' => $tpl['quality_score']['score'] ?? null,
                'category' => $tpl['category'] ?? '',
                'language' => $tpl['language'] ?? '',
            ];
        }

        $result['templates'] = [
            'list' => $templates,
            'total' => count($templates),
            'approved' => $statusCounts['APPROVED'],
            'pending' => $statusCounts['PENDING'],
            'rejected' => $statusCounts['REJECTED'],
        ];
    } else {
        $result['templates'] = [
            'list' => [],
            'total' => 0,
            'error' => $tplData['error']['message'] ?? 'Failed to fetch templates',
        ];
    }

    // ============ 3. 24H ANALYTICS (sent count for messaging limit usage) ============
    $endTs = time();
    $startTs = $endTs - 86400; // 24 hours ago

    $analyticsUrl = 'https://graph.facebook.com/v21.0/' . $businessAccountId
        . '?fields=analytics.start(' . $startTs . ').end(' . $endTs . ').granularity(DAY)'
        . '.phone_numbers(["' . $phoneNumberId . '"])';

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $analyticsUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer {$accessToken}",
    ]);

    $analyticsResponse = curl_exec($ch);
    $analyticsHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $analyticsData = json_decode($analyticsResponse, true) ?? [];

    $sent24h = 0;
    $delivered24h = 0;
    $received24h = 0;

    if ($analyticsHttpCode === 200 && isset($analyticsData['analytics']['data_points'])) {
        foreach ($analyticsData['analytics']['data_points'] as $dp) {
            $sent24h += (int) ($dp['sent'] ?? 0);
            $delivered24h += (int) ($dp['delivered'] ?? 0);
            $received24h += (int) ($dp['received'] ?? 0);
        }
    }

    $result['usage_24h'] = [
        'sent' => $sent24h,
        'delivered' => $delivered24h,
        'received' => $received24h,
    ];
}

echo json_encode($result);
?>
