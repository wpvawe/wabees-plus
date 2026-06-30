<?php
/**
 * WABEES — Remove Agent / Agent Self-Disconnect (Server-Side)
 * 
 * Securely removes an agent using service account (bypasses Firestore rules).
 * POST /api/remove-agent.php
 * Body: { owner_id, agent_id, mode: "remove"|"self_disconnect" }
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
$agentId = $input['agent_id'] ?? '';
$mode = $input['mode'] ?? 'remove'; // 'remove' or 'self_disconnect'

if (empty($ownerId) || empty($agentId)) {
    http_response_code(400);
    echo json_encode(['error' => 'owner_id and agent_id are required']);
    exit;
}

// Verify the agent exists in owner's agents subcollection
$existingAgent = firestore_get("users/$ownerId/agents/$agentId");
if ($existingAgent['code'] >= 400 || empty($existingAgent['data']['fields'])) {
    http_response_code(404);
    echo json_encode(['error' => 'Agent not found']);
    exit;
}

// 1. Remove agent from owner's agents subcollection
$deleteUrl = "https://firestore.googleapis.com/v1/projects/" . FIREBASE_PROJECT_ID
    . "/databases/(default)/documents/users/$ownerId/agents/$agentId";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $deleteUrl);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);
curl_setopt($ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
curl_setopt($ch, CURLOPT_HTTPHEADER, get_firebase_auth_headers());
curl_exec($ch);
curl_close($ch);

// 2. Clear agent's dataOwner + WA connection
firestore_set("users/$agentId", [
    'dataOwner' => '',
    'whatsappConnected' => false,
    'whatsappPhoneNumberId' => '',
]);

// 3. Delete agent's whatsapp_config
$deleteConfigUrl = "https://firestore.googleapis.com/v1/projects/" . FIREBASE_PROJECT_ID
    . "/databases/(default)/documents/users/$agentId/whatsapp_config/config";

$ch2 = curl_init();
curl_setopt($ch2, CURLOPT_URL, $deleteConfigUrl);
curl_setopt($ch2, CURLOPT_CUSTOMREQUEST, 'DELETE');
curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch2, CURLOPT_TIMEOUT, 15);
curl_setopt($ch2, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
curl_setopt($ch2, CURLOPT_HTTPHEADER, get_firebase_auth_headers());
curl_exec($ch2);
curl_close($ch2);

$actionLabel = $mode === 'self_disconnect' ? 'disconnected' : 'removed';
echo json_encode([
    'success' => true,
    'message' => "Agent $actionLabel successfully",
]);
?>
