<?php
/**
 * WABEES — WhatsApp API Proxy: Send Message
 * POST /api/send-message.php
 * Types: text, template, image, video, document, audio, sticker, reaction
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

$input = json_decode(file_get_contents('php://input'), true) ?: [];

$required = ['phone_number_id', 'access_token', 'to', 'type'];
foreach ($required as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        echo json_encode(['error' => ['message' => "$field is required"]]);
        exit;
    }
}

$phoneNumberId = $input['phone_number_id'];
$accessToken   = $input['access_token'];
$to            = $input['to'];
$type          = $input['type'];

$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/messages";

$payload = [
    'messaging_product' => 'whatsapp',
    'recipient_type'    => 'individual',
    'to'                => $to,
];

switch ($type) {
    case 'text':
        if (empty($input['message'])) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'message is required for text type']]);
            exit;
        }
        $payload['type'] = 'text';
        $payload['text'] = ['preview_url' => true, 'body' => $input['message']];
        break;

    case 'template':
        if (empty($input['template_name']) || empty($input['language_code'])) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'template_name and language_code are required']]);
            exit;
        }
        $payload['type'] = 'template';
        $payload['template'] = [
            'name'     => $input['template_name'],
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
    case 'sticker':
        $mediaId  = $input['media_id']  ?? '';
        $mediaUrl = $input['media_url'] ?? '';
        if (empty($mediaId) && empty($mediaUrl)) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'media_id or media_url is required for media type']]);
            exit;
        }
        $payload['type'] = $type;
        $mediaPayload = [];
        if (!empty($mediaId))      $mediaPayload['id']   = $mediaId;
        else                       $mediaPayload['link'] = $mediaUrl;
        if (!empty($input['caption']) && in_array($type, ['image','video','document'], true)) {
            $mediaPayload['caption'] = $input['caption'];
        }
        if ($type === 'document' && !empty($input['filename'])) {
            $mediaPayload['filename'] = $input['filename'];
        }
        if ($type === 'audio' && !empty($input['is_voice'])) {
            $mediaPayload['voice'] = true;
        }
        $payload[$type] = $mediaPayload;
        break;

    case 'reaction':
        if (empty($input['message_id'])) {
            http_response_code(400);
            echo json_encode(['error' => ['message' => 'message_id is required for reaction']]);
            exit;
        }
        $payload['type'] = 'reaction';
        $payload['reaction'] = [
            'message_id' => $input['message_id'],
            'emoji'      => $input['emoji'] ?? '',
        ];
        break;

    default:
        http_response_code(400);
        echo json_encode(['error' => ['message' => "Unsupported message type: $type"]]);
        exit;
}

// Reply context — only valid for non-reaction sends.
if ($type !== 'reaction' && !empty($input['context_message_id'])) {
    $payload['context'] = ['message_id' => $input['context_message_id']];
}

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

$response  = curl_exec($ch);
$httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($httpCode !== 200) {
    $logFile = __DIR__ . '/../logs/send_errors_' . date('Y-m-d') . '.log';
    $logDir  = dirname($logFile);
    if (!is_dir($logDir)) mkdir($logDir, 0755, true);
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
