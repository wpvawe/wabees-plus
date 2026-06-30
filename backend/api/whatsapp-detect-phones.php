<?php
/**
 * 📡 WHATSAPP DETECT PHONE NUMBERS
 * Endpoint: POST /whatsapp-detect-phones.php
 *
 * Given a WABA ID + access token, fetches all registered phone numbers.
 * Request:  { "access_token": "...", "waba_id": "..." }
 * Response: { "success": true, "phones": [{ "id", "display_phone_number", "verified_name", ... }] }
 */
require_once '_security.php';

// Security checks
enforce_post();
rate_limit('detect_phone_' . $_SERVER['REMOTE_ADDR'], 20, 60);

// ============ VALIDATE INPUT ============
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON body']);
    exit;
}

check_honeypot($data);
require_fields($data, ['access_token', 'waba_id']);

$access_token = $data['access_token'];
$waba_id = sanitize_string($data['waba_id'], 50);

// ============ FETCH PHONE NUMBERS FROM META ============
$meta_url = "https://graph.facebook.com/v21.0/{$waba_id}/phone_numbers?fields=id,display_phone_number,verified_name,quality_rating,code_verification_status,name_status,is_official_business_account";
$result = call_meta_api($meta_url, 'GET', null, $access_token);

$response_data = $result['data'] ?? [];

if ($result['http_code'] >= 200 && $result['http_code'] < 300 && isset($response_data['data'])) {
    echo json_encode([
        'success' => true,
        'phones' => $response_data['data'],
    ]);
} else {
    $error_msg = $response_data['error']['message'] ?? 'Failed to fetch phone numbers.';
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode([
        'success' => false,
        'message' => $error_msg,
    ]);
    exit;
}
?>