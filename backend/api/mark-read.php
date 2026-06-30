<?php
/**
 * WABEES — Mark Message as Read (+ optional typing indicator)
 *
 * POST /api/mark-read.php
 * Body: { phone_number_id, access_token, message_id, typing_indicator? }
 *
 * Sends a read receipt to WhatsApp Cloud API. When `typing_indicator` is
 * present (string "text" or object), Meta also shows a typing indicator to
 * the customer for ~25 seconds, dismissing automatically when the next
 * outbound message is sent.
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
$typingIndicator = $input['typing_indicator'] ?? null;

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

// Typing indicator: per Meta docs the field is an object { type: "text" }.
// Accept either a bare string ("text") or a pre-shaped object.
if (!empty($typingIndicator)) {
    if (is_string($typingIndicator)) {
        $payload['typing_indicator'] = ['type' => $typingIndicator];
    } elseif (is_array($typingIndicator)) {
        $payload['typing_indicator'] = $typingIndicator;
    }
}

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
