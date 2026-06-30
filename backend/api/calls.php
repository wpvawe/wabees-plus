<?php
/**
 * WABEES — WhatsApp Calling API Proxy
 * 
 * Handles voice call operations via Meta WhatsApp Cloud API:
 * - Connect (initiate outbound call)
 * - Accept (answer incoming call)
 * - Reject (decline incoming call)
 * - Terminate (end active call)
 * - Check permissions (can we call this user?)
 * - Request permission (ask user for call permission)
 */

require_once __DIR__ . '/../config/firebase-config.php';
require_once __DIR__ . '/../config/firebase-admin.php';
require_once __DIR__ . '/_security.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

if ($method !== 'POST' && $method !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Auth check
$uid = verify_firebase_token();
if (!$uid) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Get WhatsApp config for this user (handles dataOwner/agent pattern)
$ownerDoc = firestore_get("users/$uid");
$ownerData = $ownerDoc['data']['fields'] ?? $ownerDoc['fields'] ?? [];
$ownerId = $ownerData['dataOwner']['stringValue'] ?? $uid;

// Read config from owner's whatsapp_config subcollection
$configDoc = firestore_get("users/$ownerId/whatsapp_config/config");
$configFields = $configDoc['data']['fields'] ?? $configDoc['fields'] ?? [];
$accessToken = $configFields['accessToken']['stringValue'] ?? '';
$phoneNumberId = $configFields['phoneNumberId']['stringValue'] ?? '';

// Fallback: try from user document directly
if (empty($accessToken)) {
    $accessToken = $ownerData['whatsappAccessToken']['stringValue'] ?? '';
}
if (empty($phoneNumberId)) {
    $phoneNumberId = $ownerData['whatsappPhoneNumberId']['stringValue'] ?? '';
}

if (empty($accessToken) || empty($phoneNumberId)) {
    http_response_code(400);
    echo json_encode(['error' => 'WhatsApp config not found. Please connect your WhatsApp number first.']);
    exit;
}

$apiVersion = 'v22.0';
$baseUrl = "https://graph.facebook.com/$apiVersion/$phoneNumberId";

// ============ GET: Check call permissions ============
if ($method === 'GET') {
    $to = $_GET['to'] ?? '';
    if (empty($to)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing "to" phone number']);
        exit;
    }
    
    $url = "$baseUrl/call_permissions?to=$to";
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Authorization: Bearer $accessToken",
        ],
        CURLOPT_TIMEOUT => 10,
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    http_response_code($httpCode);
    echo $response;
    exit;
}

// ============ POST: Call actions ============
$input = json_decode(file_get_contents('php://input'), true);
$action = $input['action'] ?? '';

if (!in_array($action, ['connect', 'accept', 'reject', 'terminate', 'pre_accept', 'request_permission'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid action. Must be: connect, accept, reject, terminate, pre_accept, or request_permission']);
    exit;
}

// ============ Request Call Permission ============
if ($action === 'request_permission') {
    $to = $input['to'] ?? '';
    if (empty($to)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing "to" phone number']);
        exit;
    }
    
    // Send an interactive message asking for call permission
    $url = "$baseUrl/messages";
    $body = [
        'messaging_product' => 'whatsapp',
        'to' => preg_replace('/[^0-9]/', '', $to),
        'type' => 'interactive',
        'interactive' => [
            'type' => 'call_permission_request',
            'body' => [
                'text' => $input['message'] ?? 'We would like to call you. Please grant us permission to make voice calls.',
            ],
        ],
    ];
    
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($body),
        CURLOPT_HTTPHEADER => [
            "Authorization: Bearer $accessToken",
            'Content-Type: application/json',
        ],
        CURLOPT_TIMEOUT => 10,
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    // Log call permission request in Firestore
    $callLogId = 'call_' . time() . '_' . rand(1000, 9999);
    firestore_set("users/$ownerId/call_logs/$callLogId", [
        'type' => ['stringValue' => 'permission_request'],
        'to' => ['stringValue' => $to],
        'status' => ['stringValue' => 'requested'],
        'createdAt' => ['timestampValue' => date('c')],
    ]);
    
    http_response_code($httpCode);
    echo $response;
    exit;
}

// ============ Connect / Accept / Reject / Terminate ============
$url = "$baseUrl/calls";
$body = ['messaging_product' => 'whatsapp', 'action' => $action];

// For connect (outbound call): need 'to' + SDP offer
if ($action === 'connect') {
    $to = $input['to'] ?? '';
    $sdp = $input['sdp'] ?? '';
    if (empty($to)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing "to" phone number for connect']);
        exit;
    }
    $body['to'] = preg_replace('/[^0-9]/', '', $to);
    $body['messaging_product'] = 'whatsapp';
    if (!empty($sdp)) {
        $body['session'] = ['sdp' => $sdp];
    }
}

// For accept: need call_id + SDP answer
if ($action === 'accept' || $action === 'pre_accept') {
    $callId = $input['call_id'] ?? '';
    $sdp = $input['sdp'] ?? '';
    if (empty($callId)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing "call_id"']);
        exit;
    }
    $body['call_id'] = $callId;
    if (!empty($sdp)) {
        $body['session'] = ['sdp' => $sdp];
    }
}

// For reject/terminate: need call_id
if ($action === 'reject' || $action === 'terminate') {
    $callId = $input['call_id'] ?? '';
    if (empty($callId)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing "call_id"']);
        exit;
    }
    $body['call_id'] = $callId;
}

// Make API call to Meta
$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode($body),
    CURLOPT_HTTPHEADER => [
        "Authorization: Bearer $accessToken",
        'Content-Type: application/json',
    ],
    CURLOPT_TIMEOUT => 15,
]);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$responseData = json_decode($response, true) ?? [];

// Log call action in Firestore
$callLogId = $input['call_id'] ?? ('call_' . time() . '_' . rand(1000, 9999));
$logData = [
    'action' => ['stringValue' => $action],
    'status' => ['stringValue' => ($httpCode >= 200 && $httpCode < 300) ? 'success' : 'failed'],
    'httpCode' => ['integerValue' => (string)$httpCode],
    'updatedAt' => ['timestampValue' => date('c')],
];
if ($action === 'connect') {
    $logData['type'] = ['stringValue' => 'outgoing'];
    $logData['to'] = ['stringValue' => $input['to'] ?? ''];
    $logData['createdAt'] = ['timestampValue' => date('c')];
    // Store call_id from response if available
    if (!empty($responseData['call_id'])) {
        $callLogId = $responseData['call_id'];
        $logData['callId'] = ['stringValue' => $responseData['call_id']];
    }
}
firestore_set("users/$ownerId/call_logs/$callLogId", $logData, true); // merge

http_response_code($httpCode);
echo $response;
