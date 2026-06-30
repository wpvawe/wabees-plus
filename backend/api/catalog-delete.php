<?php
/**
 * WABEES — Delete Product from Meta Commerce Catalog
 * POST /api/catalog-delete.php
 * 
 * Deletes a product from the user's WhatsApp Commerce catalog via Meta Graph API.
 */

require_once '_security.php';

// Security checks
enforce_post();
rate_limit('catalog_delete_' . $_SERVER['REMOTE_ADDR'], 20, 60);

// Required fields
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid JSON body']]);
    exit;
}

check_honeypot($data);

require_fields($data, ['product_id', 'access_token']);

$product_id = sanitize_string($data['product_id'], 50);
$access_token = $data['access_token'];

// Call Meta Graph API to delete product
$meta_url = "https://graph.facebook.com/v21.0/{$product_id}";
$result = call_meta_api($meta_url, 'DELETE', null, $access_token);

$response_data = $result['data'] ?? [];

if ($result['http_code'] >= 400 || isset($response_data['error'])) {
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode($response_data);
    exit;
}

echo json_encode([
    'success' => true,
    'message' => 'Product deleted from Meta Commerce',
]);
?>