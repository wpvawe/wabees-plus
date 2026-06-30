<?php
/**
 * 📡 WHATSAPP SMART CONNECT
 * Endpoint: POST /whatsapp-smart-connect.php
 *
 * Given an access_token and phone_number_id, auto-detects everything:
 *   1. Verifies the phone number
 *   2. Discovers the WABA (business account) via owner_business_info
 *   3. Discovers the business via WABA
 *   4. Detects or creates a catalog
 *
 * Request:  { "access_token": "...", "phone_number_id": "..." }
 * Response: {
 *   "success": true,
 *   "phone": { "id", "display_phone_number", "verified_name", "quality_rating" },
 *   "waba_id": "...",
 *   "business_id": "...",
 *   "business_name": "..."
 * }
 */
require_once '_security.php';

// Security checks
enforce_post();
rate_limit('smart_connect_' . $_SERVER['REMOTE_ADDR'], 15, 60);

// ============ VALIDATE INPUT ============
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON body']);
    exit;
}

check_honeypot($data);
require_fields($data, ['access_token', 'phone_number_id']);

$access_token = $data['access_token'];
$phone_number_id = sanitize_string($data['phone_number_id'], 50);

// ============ STEP 1: Verify phone number ============
$phone_result = call_meta_api(
    "https://graph.facebook.com/v21.0/{$phone_number_id}?fields=id,display_phone_number,verified_name,quality_rating",
    'GET',
    null,
    $access_token
);
$phone_data = $phone_result['data'] ?? [];

if ($phone_result['http_code'] < 200 || $phone_result['http_code'] >= 300 || empty($phone_data['id'])) {
    $error_msg = $phone_data['error']['message'] ?? 'Invalid phone number ID or access token.';
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $error_msg]);
    exit;
}

// ============ STEP 2: Discover WABA via owner_business_info ============
$waba_id = '';
$business_id = '';
$business_name = '';

// Method A: owner_business_info from phone number
$owner_result = call_meta_api(
    "https://graph.facebook.com/v21.0/{$phone_number_id}?fields=owner_business_info",
    'GET',
    null,
    $access_token
);
$owner_data = $owner_result['data'] ?? [];
$owner_biz_id = $owner_data['owner_business_info']['id'] ?? '';

if (!empty($owner_biz_id)) {
    $business_id = $owner_biz_id;
    $business_name = $owner_data['owner_business_info']['name'] ?? '';

    // Get WABAs from this business
    $waba_result = call_meta_api(
        "https://graph.facebook.com/v21.0/{$owner_biz_id}/owned_whatsapp_business_accounts?fields=id,name",
        'GET',
        null,
        $access_token
    );
    $waba_resp = $waba_result['data'] ?? [];

    if (!empty($waba_resp['data'])) {
        // Find which WABA owns this phone number
        foreach ($waba_resp['data'] as $waba) {
            $check = call_meta_api(
                "https://graph.facebook.com/v21.0/{$waba['id']}/phone_numbers?fields=id",
                'GET',
                null,
                $access_token
            );
            $check_data = $check['data']['data'] ?? [];
            foreach ($check_data as $pn) {
                if (($pn['id'] ?? '') === $phone_number_id) {
                    $waba_id = $waba['id'];
                    break 2;
                }
            }
        }
        // If not found by matching, use the first one
        if (empty($waba_id) && !empty($waba_resp['data'][0]['id'])) {
            $waba_id = $waba_resp['data'][0]['id'];
        }
    }
}

// Method B: If above didn't find WABA, try debug_token for target_ids
if (empty($waba_id)) {
    $debug_result = call_meta_api(
        "https://graph.facebook.com/v21.0/debug_token?input_token=" . urlencode($access_token),
        'GET',
        null,
        $access_token
    );
    $debug_data = $debug_result['data']['data'] ?? [];
    $granular = $debug_data['granular_scopes'] ?? [];

    foreach ($granular as $scope) {
        if (in_array($scope['scope'] ?? '', ['whatsapp_business_management', 'whatsapp_business_messaging'])) {
            $tids = $scope['target_ids'] ?? [];
            foreach ($tids as $tid) {
                // Check if this WABA contains our phone number
                $check = call_meta_api(
                    "https://graph.facebook.com/v21.0/{$tid}/phone_numbers?fields=id",
                    'GET',
                    null,
                    $access_token
                );
                $check_data = $check['data']['data'] ?? [];
                foreach ($check_data as $pn) {
                    if (($pn['id'] ?? '') === $phone_number_id) {
                        $waba_id = $tid;
                        break 3;
                    }
                }
            }
        }
    }
}

// Method C: brute-force — try businesses if we found any
if (empty($waba_id)) {
    $biz_result = call_meta_api(
        "https://graph.facebook.com/v21.0/me/businesses?fields=id,name",
        'GET',
        null,
        $access_token
    );
    $businesses = $biz_result['data']['data'] ?? [];

    foreach ($businesses as $biz) {
        $waba_result = call_meta_api(
            "https://graph.facebook.com/v21.0/{$biz['id']}/owned_whatsapp_business_accounts?fields=id,name",
            'GET',
            null,
            $access_token
        );
        $wabas = $waba_result['data']['data'] ?? [];

        foreach ($wabas as $w) {
            $check = call_meta_api(
                "https://graph.facebook.com/v21.0/{$w['id']}/phone_numbers?fields=id",
                'GET',
                null,
                $access_token
            );
            $check_data = $check['data']['data'] ?? [];
            foreach ($check_data as $pn) {
                if (($pn['id'] ?? '') === $phone_number_id) {
                    $waba_id = $w['id'];
                    $business_id = $biz['id'];
                    $business_name = $biz['name'] ?? '';
                    break 3;
                }
            }
        }
    }
}

// ============ RETURN RESULT ============
echo json_encode([
    'success' => true,
    'phone' => [
        'id' => $phone_data['id'],
        'display_phone_number' => $phone_data['display_phone_number'] ?? '',
        'verified_name' => $phone_data['verified_name'] ?? '',
        'quality_rating' => $phone_data['quality_rating'] ?? '',
    ],
    'waba_id' => $waba_id,
    'business_id' => $business_id,
    'business_name' => $business_name,
]);
?>