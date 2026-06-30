<?php
/**
 * WABEES — Temp Diagnostic: Check user by phoneNumberId
 * DELETE AFTER USE
 */
require_once __DIR__ . '/../config/firebase-config.php';
header('Content-Type: application/json');

$phoneNumberId = '1111873841999878';

// Step 1: Find user from wa_map
$waMapDoc = firestore_get("wa_map/{$phoneNumberId}");
$userId = null;
$waMapData = [];

if ($waMapDoc['code'] === 200) {
    $fields = $waMapDoc['data']['fields'] ?? [];
    $userId = $fields['userId']['stringValue'] 
           ?? $fields['ownerId']['stringValue'] 
           ?? null;
    foreach ($fields as $k => $v) {
        $waMapData[$k] = array_values($v)[0] ?? null;
    }
}

if (!$userId) {
    echo json_encode([
        'status' => 'not_found',
        'message' => "No user mapped to phoneNumberId $phoneNumberId in wa_map",
        'wa_map_response_code' => $waMapDoc['code'],
    ], JSON_PRETTY_PRINT);
    exit;
}

// Step 2: Get user doc
$userDoc = firestore_get("users/{$userId}");
$userData = [];
if ($userDoc['code'] === 200) {
    $fields = $userDoc['data']['fields'] ?? [];
    // Safe: only expose non-sensitive fields
    $userData['email'] = $fields['email']['stringValue'] ?? null;
    $userData['name'] = $fields['name']['stringValue'] ?? null;
    $userData['role'] = $fields['role']['stringValue'] ?? null;
    $userData['status'] = $fields['status']['stringValue'] ?? null;
    $userData['dataOwner'] = $fields['dataOwner']['stringValue'] ?? null;
}

// Step 3: Get owner (if agent)
$ownerId = $userData['dataOwner'] ?? $userId;

// Step 4: Get WhatsApp config
$cfgDoc = firestore_get("users/{$ownerId}/whatsapp_config/config");
$config = [];
$accessToken = null;
$storedPhoneNumberId = null;

if ($cfgDoc['code'] === 200) {
    $fields = $cfgDoc['data']['fields'] ?? [];
    $accessToken = $fields['accessToken']['stringValue'] ?? null;
    $storedPhoneNumberId = $fields['phoneNumberId']['stringValue'] ?? null;
    $config['phoneNumberId'] = $storedPhoneNumberId;
    $config['hasToken'] = !empty($accessToken);
    $config['tokenLength'] = strlen($accessToken ?? '');
    $config['tokenPreview'] = $accessToken ? substr($accessToken, 0, 10) . '...' : null;
    $config['businessId'] = $fields['businessId']['stringValue'] ?? null;
    $config['phoneNumberIdMatches'] = ($storedPhoneNumberId === $phoneNumberId);
}

// Step 5: Test WhatsApp API with the token
$apiTest = null;
if ($accessToken && $storedPhoneNumberId) {
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => "https://graph.facebook.com/v21.0/{$storedPhoneNumberId}?fields=display_phone_number,verified_name,quality_rating,status,platform_type",
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_HTTPHEADER => ["Authorization: Bearer {$accessToken}"],
    ]);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    $apiTest = ['httpCode' => $code, 'response' => json_decode($resp, true)];
}

// Step 6: Check subscription
$subDoc = firestore_get("users/{$ownerId}/subscription/current");
$subscription = [];
if ($subDoc['code'] === 200) {
    $fields = $subDoc['data']['fields'] ?? [];
    $subscription['plan'] = $fields['plan']['stringValue'] ?? null;
    $subscription['status'] = $fields['status']['stringValue'] ?? null;
    $expiry = $fields['expiresAt']['timestampValue'] ?? null;
    $subscription['expiresAt'] = $expiry;
    if ($expiry) {
        $expTs = strtotime($expiry);
        $subscription['isExpired'] = $expTs < time();
        $subscription['expiresIn'] = $expTs > time() ? round(($expTs - time()) / 86400) . ' days' : 'EXPIRED';
    }
}

echo json_encode([
    'phoneNumberId' => $phoneNumberId,
    'userId' => $userId,
    'ownerId' => $ownerId,
    'user' => $userData,
    'whatsapp_config' => $config,
    'api_test' => $apiTest,
    'subscription' => $subscription,
    'diagnosis' => [
        'config_found' => $cfgDoc['code'] === 200,
        'token_valid_format' => $config['hasToken'] ?? false,
        'phoneId_matches_wamap' => $config['phoneNumberIdMatches'] ?? false,
        'api_ok' => ($apiTest['httpCode'] ?? 0) === 200,
        'subscription_active' => !($subscription['isExpired'] ?? true),
    ],
], JSON_PRETTY_PRINT);
