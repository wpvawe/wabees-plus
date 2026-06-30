<?php
/**
 * WABEES — Add Agent by Email (Server-Side)
 * 
 * Securely adds an agent by email using service account (bypasses Firestore rules).
 * POST /api/add-agent.php
 * Body: { owner_id, agent_email }
 */

require_once __DIR__ . '/../config/firebase-config.php';

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
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$ownerId = $input['owner_id'] ?? '';
$agentEmail = strtolower(trim($input['agent_email'] ?? ''));

if (empty($ownerId) || empty($agentEmail)) {
    http_response_code(400);
    echo json_encode(['error' => 'owner_id and agent_email are required']);
    exit;
}

// 1. Verify the owner exists and has WhatsApp connected
$ownerResult = firestore_get("users/$ownerId");
if ($ownerResult['code'] >= 400 || empty($ownerResult['data']['fields'])) {
    http_response_code(404);
    echo json_encode(['error' => 'Owner not found']);
    exit;
}
$ownerFields = $ownerResult['data']['fields'];
$ownerConnected = ($ownerFields['whatsappConnected']['booleanValue'] ?? false) === true;
$ownerPhoneId = $ownerFields['whatsappPhoneNumberId']['stringValue'] ?? '';

if (!$ownerConnected || empty($ownerPhoneId)) {
    http_response_code(400);
    echo json_encode(['error' => 'You must have WhatsApp connected to add agents']);
    exit;
}

// Check owner is actually an owner (no dataOwner = is owner)
$ownerDataOwner = $ownerFields['dataOwner']['stringValue'] ?? '';
if (!empty($ownerDataOwner)) {
    http_response_code(403);
    echo json_encode(['error' => 'Only the owner can add agents. You are currently an agent.']);
    exit;
}

// 2. Find user by email
$queryResult = firestore_query('users', 'email', 'EQUAL', $agentEmail);
$agentDoc = null;
$agentId = null;

if (is_array($queryResult)) {
    foreach ($queryResult as $result) {
        if (isset($result['document'])) {
            $agentDoc = $result['document'];
            // Extract doc ID from name path
            $nameParts = explode('/', $agentDoc['name']);
            $agentId = end($nameParts);
            break;
        }
    }
}

if ($agentDoc === null || $agentId === null) {
    http_response_code(404);
    echo json_encode(['error' => 'No registered user found with this email. They must register on WABEES first.']);
    exit;
}

$agentFields = $agentDoc['fields'] ?? [];

// 3. Can't add yourself
if ($agentId === $ownerId) {
    http_response_code(400);
    echo json_encode(['error' => 'You cannot add yourself as an agent']);
    exit;
}

// 4. Check if already an agent of this owner
$existingAgent = firestore_get("users/$ownerId/agents/$agentId");
if ($existingAgent['code'] === 200 && !empty($existingAgent['data']['fields'])) {
    http_response_code(409);
    echo json_encode(['error' => 'This user is already your agent']);
    exit;
}

// 5. Check if agent of another owner
$existingDataOwner = $agentFields['dataOwner']['stringValue'] ?? '';
if (!empty($existingDataOwner) && $existingDataOwner !== $ownerId) {
    http_response_code(409);
    echo json_encode(['error' => 'This user is already an agent of another WhatsApp number. They must leave first.']);
    exit;
}

// 6. Check if user has their own WhatsApp connected (is an owner)
$agentWaConnected = ($agentFields['whatsappConnected']['booleanValue'] ?? false) === true;
$agentPhoneId = $agentFields['whatsappPhoneNumberId']['stringValue'] ?? '';
$agentHasNoOwner = empty($existingDataOwner);
if ($agentWaConnected && $agentHasNoOwner && !empty($agentPhoneId)) {
    http_response_code(409);
    echo json_encode(['error' => 'This user already has their own WhatsApp connected. They must disconnect it first.']);
    exit;
}

// === ALL CHECKS PASSED — Add as agent ===

// 7. Set dataOwner + connection info on agent's user doc
firestore_set("users/$agentId", [
    'dataOwner' => $ownerId,
    'whatsappConnected' => true,
    'whatsappPhoneNumberId' => $ownerPhoneId,
]);

// 8. Add to owner's agents subcollection
firestore_set("users/$ownerId/agents/$agentId", [
    'email'    => $agentEmail,
    'joinedAt' => gmdate('Y-m-d\TH:i:s\Z'),   // ISO string → auto-detected as timestampValue
    'addedBy'  => 'owner',
    'agentId'  => $agentId,
    'name'     => $agentFields['businessName']['stringValue'] ?? '',
]);

// 9. Copy WhatsApp config to agent
$ownerConfig = firestore_get("users/$ownerId/whatsapp_config/config");
if ($ownerConfig['code'] === 200 && !empty($ownerConfig['data']['fields'])) {
    $configFields = $ownerConfig['data']['fields'];
    $configData = [];
    foreach ($configFields as $key => $val) {
        if (isset($val['stringValue'])) {
            $configData[$key] = $val['stringValue'];
        } elseif (isset($val['booleanValue'])) {
            $configData[$key] = $val['booleanValue'];
        } elseif (isset($val['integerValue'])) {
            $configData[$key] = (int)$val['integerValue'];
        }
    }
    if (!empty($configData)) {
        firestore_set("users/$agentId/whatsapp_config/config", $configData);
    }
}

echo json_encode([
    'success' => true,
    'message' => "Agent $agentEmail added successfully",
    'agentId' => $agentId,
]);
?>
