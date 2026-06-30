<?php
/**
 * WABEES — WhatsApp API Proxy: Get Templates
 * 
 * Fetches approved message templates from WhatsApp Business Account
 * POST /api/get-templates.php
 * 
 * Body: { business_account_id, access_token }
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => ['message' => 'Method not allowed']]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (empty($input['business_account_id']) || empty($input['access_token'])) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'business_account_id and access_token are required']]);
    exit;
}

$businessAccountId = $input['business_account_id'];
$accessToken = $input['access_token'];

// Fetch templates from Meta API
$url = "https://graph.facebook.com/v21.0/{$businessAccountId}/message_templates?fields=name,status,language,category,components&limit=100&access_token={$accessToken}";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$data = json_decode($response, true);

http_response_code($httpCode);
echo json_encode($data ?: ['error' => ['message' => 'Failed to fetch templates']]);
?>