<?php
/**
 * WABEES — Verify Password Reset Code
 * 
 * Checks that the OTP code matches what's stored in Firestore,
 * hasn't expired, and hasn't been used or exceeded attempt limit.
 * 
 * POST body: { "email": "user@example.com", "code": "123456" }
 * Response:  { "success": true, "message": "Code verified" }
 */

require_once __DIR__ . '/_security.php';
require_once __DIR__ . '/../config/firebase-config.php';

enforce_post();

// Parse input
$input = json_decode(file_get_contents('php://input'), true);
$email = sanitize_string($input['email'] ?? '');
$code = sanitize_string($input['code'] ?? '');

if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid email']);
    exit;
}

if (empty($code) || strlen($code) !== 6 || !ctype_digit($code)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Please enter a valid 6-digit code']);
    exit;
}

check_honeypot($input);

// Rate limit verification attempts: max 10 per email per 10 minutes
rate_limit('verify_' . md5($email), 10, 600);

// Fetch stored code from Firestore
$docPath = 'password_reset_codes/' . md5($email);
$docResp = firestore_get($docPath);
$docJson = $docResp['data'] ?? null;
if (!$docJson || !isset($docJson['fields'])) {
    echo json_encode(['success' => false, 'message' => 'No reset code found. Request a new one.']);
    exit;
}

// Extract Firestore field values safely
$fields = $docJson['fields'];
$getStr = function($k) use ($fields) {
    if (!isset($fields[$k])) return '';
    $v = $fields[$k];
    if (isset($v['stringValue'])) return $v['stringValue'];
    if (isset($v['integerValue'])) return strval($v['integerValue']);
    return '';
};
$getInt = function($k) use ($fields, $getStr) {
    $raw = $getStr($k);
    return intval($raw);
};
$getBool = function($k) use ($fields) {
    if (!isset($fields[$k])) return false;
    $v = $fields[$k];
    if (isset($v['booleanValue'])) return (bool)$v['booleanValue'];
    return false;
};

$storedData = [
  'email' => $getStr('email'),
  'code' => $getStr('code'),
  'expiresAt' => $getInt('expiresAt'),
  'attempts' => $getInt('attempts'),
  'used' => $getBool('used'),
];

// Check if already used
$used = $storedData['used'] ?? false;
if ($used) {
    echo json_encode(['success' => false, 'message' => 'This code has already been used. Request a new one.']);
    exit;
}

// Check expiry
$expiresAt = intval($storedData['expiresAt'] ?? 0);
if (time() > $expiresAt) {
    echo json_encode(['success' => false, 'message' => 'Code has expired. Request a new one.']);
    exit;
}

// Check attempt count
$attempts = intval($storedData['attempts'] ?? 0);
if ($attempts >= 5) {
    echo json_encode(['success' => false, 'message' => 'Too many failed attempts. Request a new code.']);
    exit;
}

// Increment attempts
firestore_set($docPath, array_merge($storedData, ['attempts' => $attempts + 1]));

// Verify code
$storedCode = $storedData['code'] ?? '';
if ($code !== $storedCode) {
    $remaining = 4 - $attempts;
    echo json_encode([
        'success' => false,
        'message' => "Incorrect code. $remaining attempts remaining.",
    ]);
    exit;
}

// Code matches — mark as used
firestore_set($docPath, array_merge($storedData, [
    'used' => true,
    'verifiedAt' => date('c'),
]));

echo json_encode([
    'success' => true,
    'message' => 'Code verified successfully',
]);
?>
