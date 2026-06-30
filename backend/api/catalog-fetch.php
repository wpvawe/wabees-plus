<?php
/**
 * 📦 CATALOG FETCH — Get all catalogs for a Business Account
 * Endpoint: POST /catalog-fetch.php
 * 
 * Request: { "business_id": "...", "access_token": "..." }
 * Response: { "success": true, "catalogs": [...] }
 */
require_once '_security.php';

// Security checks
enforce_post();
rate_limit('catalog_fetch_' . $_SERVER['REMOTE_ADDR'], 30, 60);

// ============ VALIDATE INPUT ============
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON body']);
    exit;
}

check_honeypot($data);
require_fields($data, ['business_id', 'access_token']);

$business_id = sanitize_string($data['business_id'], 50);
$access_token = $data['access_token']; // Token should not be sanitized

// ============ FETCH CATALOGS FROM META ============
$meta_url = "https://graph.facebook.com/v21.0/{$business_id}/owned_product_catalogs?fields=id,name,product_count,vertical";
$result = call_meta_api($meta_url, 'GET', null, $access_token);

if ($result['http_code'] >= 200 && $result['http_code'] < 300 && isset($result['data']['data'])) {
    echo json_encode([
        'success' => true,
        'catalogs' => $result['data']['data'],
    ]);
} else {
    $error_msg = $result['data']['error']['message'] ?? 'Failed to fetch catalogs';
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode([
        'success' => false,
        'message' => $error_msg,
    ]);
    exit;
}
?>