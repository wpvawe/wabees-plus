<?php
/**
 * 📦 CATALOG AUTO-CREATE — Create a new catalog for Business Account
 * Endpoint: POST /catalog-auto-create.php
 * 
 * Request: { "business_id": "...", "access_token": "...", "name": "..." }
 * Response: { "success": true, "catalog_id": "...", "name": "..." }
 */
require_once '_security.php';

// Security checks
enforce_post();
rate_limit('catalog_autocreate_' . $_SERVER['REMOTE_ADDR'], 10, 60);

// ============ VALIDATE INPUT ============
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON body']);
    exit;
}

check_honeypot($data);
require_fields($data, ['business_id', 'access_token', 'name']);

$business_id = sanitize_string($data['business_id'], 50);
$access_token = $data['access_token']; // Token should not be sanitized
$catalog_name = sanitize_string($data['name'], 100);

// ============ CREATE CATALOG ON META ============
$meta_url = "https://graph.facebook.com/v21.0/{$business_id}/owned_product_catalogs";
$payload = [
    'name' => $catalog_name,
    'vertical' => 'commerce', // commerce type for WhatsApp Commerce
];

$result = call_meta_api($meta_url, 'POST', $payload, $access_token);

if ($result['http_code'] >= 200 && $result['http_code'] < 300 && isset($result['data']['id'])) {
    echo json_encode([
        'success' => true,
        'catalog_id' => $result['data']['id'],
        'name' => $catalog_name,
    ]);
} else {
    $error_msg = $result['data']['error']['message'] ?? 'Failed to create catalog';
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode([
        'success' => false,
        'message' => $error_msg,
    ]);
    exit;
}
?>