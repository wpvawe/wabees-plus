<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/firebase-config.php';

$userId = $_GET['userId'] ?? '';
$phone = $_GET['phone'] ?? '';

if (empty($userId) || empty($phone)) {
    echo json_encode(['error' => 'userId and phone required']);
    exit;
}

// Check conversation document
$convPath = "users/$userId/conversations/$phone";
$resp = firestore_get($convPath);
$fields = $resp['data']['fields'] ?? [];

$result = [
    'convCode' => $resp['code'] ?? 'null',
    'contactName' => $fields['contactName']['stringValue'] ?? 'NOT_SET',
    'contactPhone' => $fields['contactPhone']['stringValue'] ?? 'NOT_SET',
    'lastMessage' => $fields['lastMessage']['stringValue'] ?? 'NOT_SET',
];

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
