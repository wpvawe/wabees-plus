<?php
/**
 * 📡 WHATSAPP DETECT BUSINESSES
 * Endpoint: POST /whatsapp-detect-businesses.php
 *
 * Given an access token, fetches all businesses the token has access to.
 * Uses multiple fallback strategies including debug_token for System User tokens.
 *
 * Request:  { "access_token": "..." }
 * Response: { "success": true, "businesses": [{ "id": "...", "name": "..." }] }
 */
require_once '_security.php';

// Security checks
enforce_post();
rate_limit('detect_biz_' . $_SERVER['REMOTE_ADDR'], 20, 60);

// ============ VALIDATE INPUT ============
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON body']);
    exit;
}

check_honeypot($data);
require_fields($data, ['access_token']);

$access_token = $data['access_token'];

// ============ STRATEGY 1: /me/businesses ============
$result = call_meta_api(
    "https://graph.facebook.com/v21.0/me/businesses?fields=id,name,created_time",
    'GET',
    null,
    $access_token
);
$response_data = $result['data'] ?? [];

if ($result['http_code'] >= 200 && $result['http_code'] < 300 && !empty($response_data['data'])) {
    echo json_encode(['success' => true, 'businesses' => $response_data['data']]);
    exit;
}

// ============ STRATEGY 2: debug_token → granular_scopes → WABA IDs → business info ============
// This works for ALL token types including System User tokens
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
        // Get business info from the first WABA
        $businesses_map = [];

        foreach (array_keys($waba_ids) as $waba_id) {
            $waba_result = call_meta_api(
                "https://graph.facebook.com/v21.0/{$waba_id}?fields=id,name,on_behalf_of_business_info,owner_business_info",
                'GET',
                null,
                $access_token
            );
            $waba_data = $waba_result['data'] ?? [];

            // Extract business info from WABA
            $biz_info = $waba_data['owner_business_info'] ?? $waba_data['on_behalf_of_business_info'] ?? null;
            if ($biz_info && !empty($biz_info['id'])) {
                $businesses_map[$biz_info['id']] = [
                    'id' => $biz_info['id'],
                    'name' => $biz_info['name'] ?? 'Business ' . $biz_info['id'],
                ];
            }
        }

        if (!empty($businesses_map)) {
            echo json_encode(['success' => true, 'businesses' => array_values($businesses_map)]);
            exit;
        }

        // If we found WABA IDs but no business info, create a synthetic business
        // so the flow can continue (WABA detection will use debug_token too)
        echo json_encode([
            'success' => true,
            'businesses' => [
                [
                    'id' => '_auto_' . array_keys($waba_ids)[0],
                    'name' => $debug_data['application'] ?? 'Your Business',
                    '_auto_discovered' => true,
                ]
            ],
        ]);
        exit;
    }
}

// ============ STRATEGY 3: /me identity as synthetic business ============
$me_result = call_meta_api(
    "https://graph.facebook.com/v21.0/me?fields=id,name",
    'GET',
    null,
    $access_token
);
$me_data = $me_result['data'] ?? [];

if (!empty($me_data['id'])) {
    echo json_encode([
        'success' => true,
        'businesses' => [
            [
                'id' => $me_data['id'],
                'name' => $me_data['name'] ?? 'Your Business',
                '_auto_discovered' => true,
            ]
        ],
    ]);
    exit;
}

// ============ ALL STRATEGIES FAILED ============
http_response_code(400);
echo json_encode([
    'success' => false,
    'message' => 'Could not detect businesses. Verify your token has business_management or whatsapp_business_management permissions.',
]);
exit;
?>