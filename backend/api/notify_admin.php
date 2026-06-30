<?php
// Send FCM notifications to all admins for app-side events
require_once __DIR__ . '/../config/firebase-config.php';
require_once __DIR__ . '/../config/firebase-admin.php';

header('Content-Type: application/json');

function get_admins() {
  $results = firestore_query('users', 'role', 'EQUAL', 'admin');
  $admins = [];
  foreach ($results as $r) {
    if (!isset($r['document'])) continue;
    $fields = $r['document']['fields'] ?? [];
    $idParts = explode('/', $r['document']['name']);
    $uid = end($idParts);
    $token = $fields['fcmToken']['stringValue'] ?? null;
    if ($token) $admins[] = ['id' => $uid, 'token' => $token, 'name' => $fields['businessName']['stringValue'] ?? 'Admin'];
  }
  return $admins;
}

function send_fcm_to_token($token, $title, $body, $dataType, $data = []) {
  $adminToken = get_firebase_admin_token();
  if (!$adminToken) return false;
  $projectId = FIREBASE_PROJECT_ID;
  $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
  $payload = [
    'message' => [
      'token' => $token,
      'notification' => ['title' => $title, 'body' => $body],
      'data' => array_merge([
        'type' => $dataType,
        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
      ], $data),
      'android' => [
        'priority' => 'high',
        'notification' => [
          'channel_id' => 'wabees_admin',
          'sound' => 'default',
        ],
      ],
    ],
  ];
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_TIMEOUT, 10);
  curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    "Authorization: Bearer $adminToken",
  ]);
  $resp = curl_exec($ch);
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  return $code >= 200 && $code < 300;
}

$type = $_POST['type'] ?? $_GET['type'] ?? '';
$title = $_POST['title'] ?? $_GET['title'] ?? '';
$body = $_POST['body'] ?? $_GET['body'] ?? '';

if ($type === '') {
  http_response_code(400);
  echo json_encode(['success' => false, 'error' => 'type required']);
  exit;
}

if ($title === '') {
  $title = match($type) {
    'new_user' => 'New User Registration',
    'plan_request' => 'Plan Request',
    'support_message' => 'New Support Message',
    default => 'Notification',
  };
}

$admins = get_admins();
$ok = true;
foreach ($admins as $a) {
  $ok = send_fcm_to_token($a['token'], $title, $body ?: $title, $type) && $ok;
}

echo json_encode(['success' => $ok, 'count' => count($admins)]);
