<?php
/**
 * WABEES — WhatsApp API Proxy: Verify Token
 * 
 * Verifies WhatsApp Cloud API credentials by calling Meta's API
 * POST /api/verify-token.php
 * 
 * Body: { phone_number_id, access_token, business_account_id (optional) }
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

if (empty($input['phone_number_id']) || empty($input['access_token'])) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'phone_number_id and access_token are required']]);
    exit;
}

$phoneNumberId = $input['phone_number_id'];
$accessToken = $input['access_token'];
// Allow user to pass WABA ID directly as fallback
$userProvidedWabaId = $input['business_account_id'] ?? '';

// Call Meta Graph API to verify phone number
$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}?fields=display_phone_number,quality_rating,verified_name,id&access_token={$accessToken}";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$data = json_decode($response, true);

if ($httpCode === 200 && isset($data['id'])) {
    $businessAccountId = $userProvidedWabaId;

    // If user didn't provide WABA ID, try to auto-detect it
    if (empty($businessAccountId)) {
        // Method 1: Try phone_numbers endpoint to find parent WABA
        // GET /{phone_number_id}?fields=... doesn't directly give WABA ID
        // We need to search which WABA owns this phone number
        // The simplest way: use the debug_token or list WABAs from the business

        // Method 2: Try getting WABA ID via owner_business_info → then list WABAs
        $baUrl = "https://graph.facebook.com/v21.0/{$phoneNumberId}?fields=owner_business_info&access_token={$accessToken}";

        $ch2 = curl_init();
        curl_setopt($ch2, CURLOPT_URL, $baUrl);
        curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch2, CURLOPT_SSL_VERIFYPEER, true);
        curl_setopt($ch2, CURLOPT_TIMEOUT, 15);
        $baResponse = curl_exec($ch2);
        curl_close($ch2);

        $baData = json_decode($baResponse, true);
        $businessId = $baData['owner_business_info']['id'] ?? '';

        if (!empty($businessId)) {
            // List WABAs under this business
            $wabaUrl = "https://graph.facebook.com/v21.0/{$businessId}/owned_whatsapp_business_accounts?access_token={$accessToken}";

            $ch3 = curl_init();
            curl_setopt($ch3, CURLOPT_URL, $wabaUrl);
            curl_setopt($ch3, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch3, CURLOPT_SSL_VERIFYPEER, true);
            curl_setopt($ch3, CURLOPT_TIMEOUT, 15);
            $wabaResponse = curl_exec($ch3);
            curl_close($ch3);

            $wabaData = json_decode($wabaResponse, true);

            // Take the first WABA
            if (!empty($wabaData['data'][0]['id'])) {
                $businessAccountId = $wabaData['data'][0]['id'];
            }
        }
    }

    echo json_encode([
        'id' => $data['id'],
        'display_phone_number' => $data['display_phone_number'] ?? null,
        'quality_rating' => $data['quality_rating'] ?? null,
        'verified_name' => $data['verified_name'] ?? null,
        'business_account_id' => $businessAccountId,
    ]);
} else {
    http_response_code($httpCode >= 400 ? $httpCode : 400);
    echo json_encode($data ?: ['error' => ['message' => 'Failed to verify credentials']]);
}
?>