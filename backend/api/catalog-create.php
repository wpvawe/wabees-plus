<?php
/**
 * WABEES — Create Product in Meta Commerce Catalog
 * POST /api/catalog-create.php
 * 
 * Creates a product in the user's WhatsApp Commerce catalog via Meta Graph API.
 * Also saves the product to Firestore for local caching.
 */

require_once '_security.php';

// Security checks
enforce_post();
rate_limit('catalog_create_' . $_SERVER['REMOTE_ADDR'], 30, 60);

// Required fields
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid JSON body']]);
    exit;
}

check_honeypot($data);

require_fields($data, ['catalog_id', 'access_token', 'name', 'price', 'currency']);

// Sanitize inputs
$catalog_id = sanitize_string($data['catalog_id'], 50);
$access_token = $data['access_token']; // Token should not be sanitized
$name = sanitize_string($data['name'], 150);
$description = sanitize_string($data['description'] ?? '', 5000);
$price = intval($data['price']); // Price in cents
$currency = sanitize_string($data['currency'] ?? 'USD', 3);
$category = sanitize_string($data['category'] ?? '', 100);
$image_url = sanitize_string($data['image_url'] ?? '', 2000);
$url = sanitize_string($data['url'] ?? '', 2000);
$retailer_id = sanitize_string($data['retailer_id'] ?? '', 100);
$availability = sanitize_string($data['availability'] ?? 'in stock', 20);

// Validate price
if ($price < 0) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Price must be a positive number']]);
    exit;
}

// Build product data for Meta API
$product_data = [
    'name' => $name,
    'price' => $price,
    'currency' => strtoupper($currency),
    'availability' => $availability,
];

if (!empty($description))
    $product_data['description'] = $description;
if (!empty($category))
    $product_data['category'] = $category;
if (!empty($image_url))
    $product_data['image_url'] = $image_url;
if (!empty($url))
    $product_data['url'] = $url;
if (!empty($retailer_id))
    $product_data['retailer_id'] = $retailer_id;

// Call Meta Graph API to create product
$meta_url = "https://graph.facebook.com/v21.0/{$catalog_id}/products";
$result = call_meta_api($meta_url, 'POST', $product_data, $access_token);

$response_data = $result['data'] ?? [];

if ($result['http_code'] >= 400 || isset($response_data['error'])) {
    http_response_code($result['http_code'] >= 400 ? $result['http_code'] : 400);
    echo json_encode($response_data);
    exit;
}

// Return success with Meta product ID
echo json_encode([
    'success' => true,
    'message' => 'Product created on Meta Commerce',
    'data' => [
        'meta_product_id' => $response_data['id'] ?? null,
        'retailer_id' => $response_data['retailer_id'] ?? $retailer_id,
    ],
]);
?>