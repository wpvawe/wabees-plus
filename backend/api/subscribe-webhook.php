<?php
/**
 * WABEES — Subscribe to WhatsApp webhooks for a phone number
 *
 * This MUST be called after a user connects their WhatsApp number.
 * Without it, Meta does not deliver incoming messages to the webhook.
 *
 * Meta API: POST /{phone-number-id}/subscribed_apps
 *
 * POST /subscribe-webhook.php
 * Body: { phone_number_id, access_token }
 */
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'POST only']);
    exit;
}

$body = json_decode(file_get_contents('php://input'), true);
$phoneNumberId = trim($body['phone_number_id'] ?? '');
$accessToken   = trim($body['access_token'] ?? '');

if (empty($phoneNumberId) || empty($accessToken)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'phone_number_id and access_token required']);
    exit;
}

// Call Meta API to subscribe this phone number to webhooks
$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/subscribed_apps";

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL            => $url,
    CURLOPT_POST           => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 15,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_HTTPHEADER     => [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json',
    ],
    CURLOPT_POSTFIELDS     => '{}',
    CURLOPT_SSL_VERIFYPEER => true,
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlErr  = curl_error($ch);
curl_close($ch);

error_log("[WABEES] subscribe-webhook: phoneId=$phoneNumberId HTTP=$httpCode curlErr=$curlErr response=$response");

if ($curlErr) {
    http_response_code(502);
    echo json_encode(['success' => false, 'error' => "cURL error: $curlErr"]);
    exit;
}

$data = json_decode($response, true);

if ($httpCode >= 200 && $httpCode < 300 && ($data['success'] ?? false)) {
    echo json_encode([
        'success' => true,
        'message' => 'Webhook subscription active. Messages will now be delivered.',
    ]);
} else {
    // Log but don't hard-fail — the number may already be subscribed
    $errMsg = $data['error']['message'] ?? $response;
    error_log("[WABEES] subscribe-webhook: META RETURNED HTTP=$httpCode msg=$errMsg");

    // 400 with code 200 often means "already subscribed" — treat as success
    $metaCode = $data['error']['code'] ?? 0;
    if ($httpCode === 400 && $metaCode == 200) {
        echo json_encode(['success' => true, 'message' => 'Already subscribed']);
        exit;
    }

    http_response_code(502);
    echo json_encode([
        'success'  => false,
        'error'    => $errMsg,
        'httpCode' => $httpCode,
    ]);
}
