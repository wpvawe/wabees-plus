<?php
/**
 * WABEES — List Products from Meta Commerce Catalog
 * POST /api/catalog-list.php
 * 
 * Fetches all products from a user's WhatsApp Commerce catalog via Meta Graph API.
 */

require_once '_security.php';

// Security checks
enforce_post();
rate_limit('catalog_list_' . $_SERVER['REMOTE_ADDR'], 30, 60);

// Required fields
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid JSON body']]);
    exit;
}

check_honeypot($data);

require_fields($data, ['catalog_id', 'access_token']);

$catalog_id = sanitize_string($data['catalog_id'], 50);
$access_token = $data['access_token'];

// Pagination
$limit = min(intval($data['limit'] ?? 50), 250);
$after = sanitize_string($data['after'] ?? '', 200);

// Fetch products from Meta Graph API (GET request)
$fields = 'id,name,description,price,currency,availability,image_url,url,retailer_id,category';
$meta_url = "https://graph.facebook.com/v21.0/{$catalog_id}/products?fields={$fields}&limit={$limit}";
if (!empty($after)) {
    $meta_url .= '&after=' . urlencode($after);
}

$result = call_meta_api($meta_url, 'GET', null, $access_token);

$response_data = $result['data'] ?? [];

if ($result['http_code'] >= 400 || isset($response_data['error'])) {
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode($response_data);
    exit;
}

echo json_encode([
    'success' => true,
    'message' => 'Products fetched',
    'data' => $response_data['data'] ?? [],
    'paging' => $response_data['paging'] ?? null,
]);
?>