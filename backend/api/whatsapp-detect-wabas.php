<?php
/**
 * 📡 WHATSAPP DETECT WABAs
 * Endpoint: POST /whatsapp-detect-wabas.php
 *
 * Given a business ID + access token, fetches all WhatsApp Business Accounts.
 * Uses debug_token API as primary fallback for reliable WABA discovery.
 *
 * Request:  { "access_token": "...", "business_id": "..." }
 * Response: { "success": true, "wabas": [{ "id", "name", "currency", ... }] }
 */
require_once '_security.php';

// Security checks
enforce_post();
rate_limit('detect_waba_' . $_SERVER['REMOTE_ADDR'], 20, 60);

// ============ VALIDATE INPUT ============
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON body']);
    exit;
}

check_honeypot($data);
require_fields($data, ['access_token', 'business_id']);

$access_token = $data['access_token'];
$business_id = sanitize_string($data['business_id'], 50);

$waba_fields = 'id,name,currency,message_template_namespace,account_review_status';

// ============ STRATEGY 1: /{business_id}/owned_whatsapp_business_accounts ============
// Only try if business_id doesn't look synthetic (starts with _auto_)
if (strpos($business_id, '_auto_') !== 0) {
    $endpoints = [
        "owned_whatsapp_business_accounts",
        "client_whatsapp_business_accounts",
    ];

    foreach ($endpoints as $ep) {
        $result = call_meta_api(
            "https://graph.facebook.com/v21.0/{$business_id}/{$ep}?fields={$waba_fields}",
            'GET',
            null,
            $access_token
        );
        $resp = $result['data'] ?? [];
        if ($result['http_code'] >= 200 && $result['http_code'] < 300 && !empty($resp['data'])) {
            echo json_encode(['success' => true, 'wabas' => $resp['data']]);
            exit;
        }
    }
}

// ============ STRATEGY 2: debug_token → granular_scopes → WABA IDs ============
// This is the most reliable method for System User tokens
$debug_result = call_meta_api(
    "https://graph.facebook.com/v21.0/debug_token?input_token=" . urlencode($access_token),
    'GET',
    null,
    $access_token
);
$debug_data = $debug_result['data']['data'] ?? [];

if (!empty($debug_data)) {
    $waba_ids = [];
    $granular_scopes = $debug_data['granular_scopes'] ?? [];

    foreach ($granular_scopes as $scope) {
        if (in_array($scope['scope'] ?? '', ['whatsapp_business_management', 'whatsapp_business_messaging'])) {
            $target_ids = $scope['target_ids'] ?? [];
            foreach ($target_ids as $tid) {
                $waba_ids[$tid] = true;
            }
        }
    }

    if (!empty($waba_ids)) {
        // Query each WABA for full details
        $wabas = [];
        foreach (array_keys($waba_ids) as $waba_id) {
            $waba_result = call_meta_api(
                "https://graph.facebook.com/v21.0/{$waba_id}?fields={$waba_fields}",
                'GET',
                null,
                $access_token
            );
            $waba_data = $waba_result['data'] ?? [];
            if (!empty($waba_data['id'])) {
                $wabas[] = $waba_data;
            }
        }

        if (!empty($wabas)) {
            echo json_encode(['success' => true, 'wabas' => $wabas]);
            exit;
        }
    }
}

// ============ ALL STRATEGIES FAILED ============
http_response_code(400);
echo json_encode([
    'success' => false,
    'message' => 'No WhatsApp Business Accounts found. Make sure your token has whatsapp_business_management permission.',
]);
exit;
?>