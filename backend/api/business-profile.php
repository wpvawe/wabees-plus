<?php
/**
 * WABEES — WhatsApp Business Profile (Get & Update)
 * 
 * POST /api/business-profile.php
 * Body: { phone_number_id, access_token, action: 'get' | 'update', ...profile_fields }
 * 
 * GET: Returns about, address, description, email, profile_picture_url, websites, vertical
 * UPDATE: Updates specified fields
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
$action = $input['action'] ?? 'get';

if (empty($phoneNumberId) || empty($accessToken)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'phone_number_id and access_token are required']]);
    exit;
}

$url = "https://graph.facebook.com/v21.0/{$phoneNumberId}/whatsapp_business_profile";

if ($action === 'get') {
    // ============ GET PROFILE ============
    $fields = 'about,address,description,email,profile_picture_url,websites,vertical';
    $getUrl = "{$url}?fields={$fields}";

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $getUrl);
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

    // Extract profile from data array
    $profile = [];
    if (isset($data['data']) && is_array($data['data']) && !empty($data['data'])) {
        $profile = $data['data'][0];
    }

    http_response_code($httpCode);
    echo json_encode(['profile' => $profile]);

} else if ($action === 'update') {
    // ============ UPDATE PROFILE ============
    $updatePayload = ['messaging_product' => 'whatsapp'];

    $allowedFields = ['about', 'address', 'description', 'email', 'websites', 'vertical', 'profile_picture_handle'];
    foreach ($allowedFields as $field) {
        if (isset($input[$field])) {
            $updatePayload[$field] = $input[$field];
        }
    }

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($updatePayload));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "Authorization: Bearer {$accessToken}",
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $data = json_decode($response, true) ?? [];

    http_response_code($httpCode);
    echo json_encode($data);

} else {
    http_response_code(400);
    echo json_encode(['error' => ['message' => "Invalid action: $action. Use 'get' or 'update'"]]);
}
?>