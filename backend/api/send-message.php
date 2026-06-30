<?php
/**
 * WABEES — WhatsApp API Proxy: Send Message
 * 
 * Proxies message sending to WhatsApp Cloud API
 * POST /api/send-message.php
 * 
 * Body: { phone_number_id, access_token, to, type, message?, template_name?, ... }
 * Types: text, template, image, video, document, audio
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

if (!empty($input['context_message_id'])) {
    $waPayload['context'] = ['message_id' => $input['context_message_id']];
}

$input = json_decode(file_get_contents('php://input'), true);

// Validate required fields
$required = ['phone_number_id', 'access_token', 'to', 'type'];
foreach ($required as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        echo json_encode(['error' => ['message' => "$field is required"]]);
        exit;
    }
}

$phoneNumberId = $input['phone_number_id'];
$accessToken = $input['access_token'];
$to = $input['to'];
$type = $input['type'];

// Build WhatsApp API payload
$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/messages";

$payload = [
    'messaging_product' => 'whatsapp',
    'to' => $to,
];

switch ($type) {
    case 'text':
        if (empty($input['message'])) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'message is required for text type']]);
            exit;
        }
        $payload['type'] = 'text';
        $payload['text'] = ['body' => $input['message']];
        break;

    case 'template':
        if (empty($input['template_name']) || empty($input['language_code'])) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'template_name and language_code are required']]);
            exit;
        }
        $payload['type'] = 'template';
        $payload['template'] = [
            'name' => $input['template_name'],
            'language' => ['code' => $input['language_code']],
        ];
        if (!empty($input['components'])) {
            $payload['template']['components'] = $input['components'];
        }
        break;

    case 'image':
    case 'video':
    case 'document':
    case 'audio':
        $mediaId  = $input['media_id']  ?? '';
        $mediaUrl = $input['media_url'] ?? '';
        if (empty($mediaId) && empty($mediaUrl)) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'media_id or media_url is required for media type']]);
            exit;
        }
        $payload['type'] = $type;
        $mediaPayload = [];
        // WhatsApp API accepts ONLY 'id' OR 'link', NOT both!
        // Prefer 'id' (from WhatsApp Cloud upload) over 'link' (public URL)
        if (!empty($mediaId)) {
            $mediaPayload['id'] = $mediaId;
        } elseif (!empty($mediaUrl)) {
            $mediaPayload['link'] = $mediaUrl;
        }
        if (!empty($input['caption']) && in_array($type, ['image', 'video', 'document'])) {
            $mediaPayload['caption'] = $input['caption'];
        }
        // CRITICAL: audio with voice=true sends as WhatsApp voice note (waveform UI)
        // Without this flag it sends as a regular audio file attachment
        if ($type === 'audio' && ($input['is_voice'] ?? false)) {
            $mediaPayload['voice'] = true;
        }
        $payload[$type] = $mediaPayload;
        break;

    default:
        http_response_code(400);
        echo json_encode(['error' => ['message' => "Unsupported message type: $type"]]);
        exit;
}

// Send to Meta API
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer {$accessToken}",
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

// Log errors for debugging
if ($httpCode !== 200) {
    $logFile = __DIR__ . '/../logs/send_errors_' . date('Y-m-d') . '.log';
    $logDir = dirname($logFile);
    if (!is_dir($logDir))
        mkdir($logDir, 0755, true);
    file_put_contents(
        $logFile,
        date('H:i:s') . " TO=$to TYPE=$type HTTP=$httpCode CURL_ERR=$curlError RESPONSE=$response\n",
        FILE_APPEND
    );
    error_log("[WABEES] SEND_ERROR TO=$to TYPE=$type HTTP=$httpCode RESP=$response");
} else {
    error_log("[WABEES] SEND_OK TO=$to TYPE=$type");
}

if ($curlError) {
    http_response_code(500);
    echo json_encode(['error' => ['message' => 'Network error: ' . $curlError]]);
    exit;
}

$data = json_decode($response, true);

http_response_code($httpCode);
echo json_encode($data ?: ['error' => ['message' => 'No response from WhatsApp API']]);
?>
