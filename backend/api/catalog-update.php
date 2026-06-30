<?php
/**
 * WABEES — Update Product in Meta Commerce Catalog
 * POST /api/catalog-update.php
 * 
 * Updates a product in the user's WhatsApp Commerce catalog via Meta Graph API.
 */

require_once '_security.php';

// Security checks
enforce_post();
rate_limit('catalog_update_' . $_SERVER['REMOTE_ADDR'], 30, 60);

// Required fields
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid JSON body']]);
    exit;
}

check_honeypot($data);

require_fields($data, ['product_id', 'access_token']);

// Sanitize inputs
$product_id = sanitize_string($data['product_id'], 50);
$access_token = $data['access_token'];

// Build update data — only include fields that are present
$update_data = [];
if (isset($data['name']))
    $update_data['name'] = sanitize_string($data['name'], 150);
if (isset($data['description']))
    $update_data['description'] = sanitize_string($data['description'], 5000);
if (isset($data['price']))
    $update_data['price'] = intval($data['price']);
if (isset($data['currency']))
    $update_data['currency'] = strtoupper(sanitize_string($data['currency'], 3));
if (isset($data['category']))
    $update_data['category'] = sanitize_string($data['category'], 100);
if (isset($data['image_url']))
    $update_data['image_url'] = sanitize_string($data['image_url'], 2000);
if (isset($data['url']))
    $update_data['url'] = sanitize_string($data['url'], 2000);
if (isset($data['availability']))
    $update_data['availability'] = sanitize_string($data['availability'], 20);

if (empty($update_data)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'No fields to update']]);
    exit;
}

// Call Meta Graph API to update product
$meta_url = "https://graph.facebook.com/v21.0/{$product_id}";
$result = call_meta_api($meta_url, 'POST', $update_data, $access_token);

$response_data = $result['data'] ?? [];

if ($result['http_code'] >= 400 || isset($response_data['error'])) {
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode($response_data);
    exit;
}

echo json_encode([
    'success' => true,
    'message' => 'Product updated on Meta Commerce',
    'data' => $response_data,
]);
?>