<?php
/**
 * WABEES — Phone Number Health & Quality Rating
 * 
 * POST /api/phone-health.php
 * Body: { phone_number_id, access_token }
 * 
 * Returns: quality_rating, messaging_limit_tier, status, display_phone_number, verified_name
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
$phoneNumberId = $input['phone_number_id'] ?? '';
$accessToken = $input['access_token'] ?? '';

if (empty($phoneNumberId) || empty($accessToken)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'phone_number_id and access_token are required']]);
    exit;
}

$fields = 'quality_rating,messaging_limit_tier,status,display_phone_number,verified_name,code_verification_status,platform_type,throughput,last_onboarded_time,name_status';
$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}?fields={$fields}";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Authorization: Bearer {$accessToken}",
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$data = json_decode($response, true) ?? [];

http_response_code($httpCode);
echo json_encode($data);
?>