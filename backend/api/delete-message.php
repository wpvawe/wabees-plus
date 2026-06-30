<?php
/**
 * WABEES — Delete WhatsApp Message (Unsend for everyone)
 * POST /api/delete-message.php
 * Body: { phone_number_id, access_token, message_id }
 * 
 * WhatsApp Cloud API: POST /{phone-number-id}/messages
 * Body: { messaging_product, status: "deleted", message_id: "wamid.xxx" }
 */
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => ['message' => 'Method not allowed']]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
foreach (['phone_number_id', 'access_token', 'message_id'] as $f) {
    if (empty($input[$f])) {
        http_response_code(400);
        echo json_encode(['error' => ['message' => "$f is required"]]);
        exit;
    }
}

$phoneNumberId = $input['phone_number_id'];
$accessToken   = $input['access_token'];
$messageId     = $input['message_id'];

// Validate: WhatsApp message IDs start with "wamid."
// Reject numeric-only IDs which are phone_number_ids, not message IDs
if (!str_starts_with($messageId, 'wamid.')) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid message_id: must be a WhatsApp wamid (starts with wamid.)']]);
    exit;
}

// WhatsApp Cloud API: DELETE a sent message
// Method: POST to /{phone-number-id}/messages
// Body: { messaging_product: "whatsapp", status: "deleted", message_id: "wamid.xxx" }
$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/messages";

$payload = [
    'messaging_product' => 'whatsapp',
    'status'            => 'deleted',
    'message_id'        => $messageId,
];

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL            => $url,
    CURLOPT_POST           => true,          // ← POST (not DELETE)
    CURLOPT_POSTFIELDS     => json_encode($payload),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 15,
    CURLOPT_HTTPHEADER     => [
        'Content-Type: application/json',
        "Authorization: Bearer {$accessToken}",
    ],
]);
$response = curl_exec($ch);
$code     = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$err      = curl_error($ch);
curl_close($ch);

if ($err) {
    http_response_code(500);
    echo json_encode(['error' => ['message' => "cURL error: $err"]]);
    exit;
}

http_response_code($code);
echo $response ?: json_encode(['error' => ['message' => 'No response from WhatsApp']]);
