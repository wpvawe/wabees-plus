<?php
/**
 * WABEES — Send Interactive Message (Quick Reply + CTA Buttons)
 * 
 * POST /api/send-interactive.php
 * Body: { phone_number_id, access_token, to, body, footer?, quick_replies?, cta_button? }
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

// Validate required fields
$required = ['phone_number_id', 'access_token', 'to', 'body'];
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
$body = $input['body'];
$footer = $input['footer'] ?? null;
$quickReplies = $input['quick_replies'] ?? []; // [{id, title}]
$ctaButton = $input['cta_button'] ?? null;      // {type, title, value}
$headerText = $input['header'] ?? null;

$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/messages";

// Determine message type based on buttons
$hasQuickReplies = !empty($quickReplies);
$hasCtaButton = !empty($ctaButton);

if ($hasQuickReplies) {
    // ============ QUICK REPLY BUTTONS ============
    $buttons = [];
    foreach (array_slice($quickReplies, 0, 3) as $qr) {
        $buttons[] = [
            'type' => 'reply',
            'reply' => [
                'id' => $qr['id'] ?? 'btn_' . count($buttons),
                'title' => substr($qr['title'] ?? 'Button', 0, 20),
            ],
        ];
    }

    $payload = [
        'messaging_product' => 'whatsapp',
        'recipient_type' => 'individual',
        'to' => $to,
        'type' => 'interactive',
        'interactive' => [
            'type' => 'button',
            'body' => ['text' => $body],
            'action' => ['buttons' => $buttons],
        ],
    ];

    if ($headerText) {
        $payload['interactive']['header'] = ['type' => 'text', 'text' => $headerText];
    }
    if ($footer) {
        $payload['interactive']['footer'] = ['text' => $footer];
    }

} elseif ($hasCtaButton) {
    // ============ CTA BUTTON (URL or PHONE) ============
    $ctaType = $ctaButton['type'] ?? 'url';

    $actionButton = [
        'type' => $ctaType === 'phone' ? 'phone_number' : 'url',
        'title' => substr($ctaButton['title'] ?? 'Click', 0, 20),
    ];

    if ($ctaType === 'phone') {
        $actionButton['phone_number'] = $ctaButton['value'];
    } else {
        $actionButton['url'] = $ctaButton['value'];
    }

    $payload = [
        'messaging_product' => 'whatsapp',
        'recipient_type' => 'individual',
        'to' => $to,
        'type' => 'interactive',
        'interactive' => [
            'type' => 'cta_url',
            'body' => ['text' => $body],
            'action' => [
                'name' => 'cta_url',
                'parameters' => [
                    'display_text' => $actionButton['title'],
                    'url' => $ctaButton['value'],
                ],
            ],
        ],
    ];

    if ($footer) {
        $payload['interactive']['footer'] = ['text' => $footer];
    }

} else {
    // ============ PLAIN TEXT (fallback) ============
    $payload = [
        'messaging_product' => 'whatsapp',
        'to' => $to,
        'type' => 'text',
        'text' => ['body' => $body],
    ];
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
curl_close($ch);

$data = json_decode($response, true);

http_response_code($httpCode);
echo json_encode($data ?: ['error' => ['message' => 'No response from WhatsApp API']]);
?>