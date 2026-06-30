<?php
/**
 * WABEES — Mark Message as Read
 * 
 * POST /api/mark-read.php
 * Body: { phone_number_id, access_token, message_id }
 * 
 * Sends a read receipt to WhatsApp Cloud API
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
$messageId = $input['message_id'] ?? '';

if (empty($phoneNumberId) || empty($accessToken) || empty($messageId)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'phone_number_id, access_token, and message_id are required']]);
    exit;
}

$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/messages";

$payload = [
    'messaging_product' => 'whatsapp',
    'status' => 'read',
    'message_id' => $messageId,
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer {$accessToken}",
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$data = json_decode($response, true);

http_response_code($httpCode);
echo json_encode($data ?: ['success' => true]);
?>