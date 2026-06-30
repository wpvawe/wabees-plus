<?php
/**
 * WABEES — Webhook Subscription Checker + Auto-Subscribe
 *
 * Uses App Access Token (META_APP_ID|META_APP_SECRET) to subscribe WABA.
 * GET /api/check-webhook-sub.php?phone_number_id=...&secret=wabees_cache_clear_2024
 */

header('Content-Type: application/json');

$secret = $_GET['secret'] ?? '';
if ($secret !== 'wabees_cache_clear_2024') {
    http_response_code(403);
    echo json_encode(['error' => 'Invalid secret']);
    exit;
}

$phoneNumberId = $_GET['phone_number_id'] ?? '';
if (empty($phoneNumberId)) {
    http_response_code(400);
    echo json_encode(['error' => 'phone_number_id required']);
    exit;
}

require_once __DIR__ . '/../config/firebase-config.php';

$result = [];

// ─── App Access Token (from env vars) ────────────────────────────
$metaAppId     = getenv('META_APP_ID')     ?: '';
$metaAppSecret = getenv('META_APP_SECRET') ?: '';
$appAccessToken = (!empty($metaAppId) && !empty($metaAppSecret))
    ? "$metaAppId|$metaAppSecret"
    : null;
$result['app_token_available'] = !empty($appAccessToken);

// ─── Step 1: Get owner from wa_map ───────────────────────────────
$waMapDoc = firestore_get("wa_map/$phoneNumberId");
$result['wa_map_code'] = $waMapDoc['code'];

if (($waMapDoc['code'] ?? 404) !== 200) {
    echo json_encode(['error' => "wa_map/$phoneNumberId NOT FOUND in Firestore", 'result' => $result]);
    exit;
}

$fields  = $waMapDoc['data']['fields'] ?? [];
$ownerId = $fields['ownerId']['stringValue'] ?? $fields['userId']['stringValue'] ?? null;
$result['ownerId'] = $ownerId;

// ─── Step 2: Get user access token + WABA ID ─────────────────────
$userDoc    = firestore_get("users/$ownerId");
$userFields = $userDoc['data']['fields'] ?? [];
$userToken  = $userFields['whatsappAccessToken']['stringValue'] ?? null;
$result['userToken_found'] = !empty($userToken);

$configDoc    = firestore_get("users/$ownerId/whatsapp_config/config");
$configFields = $configDoc['data']['fields'] ?? [];
$wabaId       = $configFields['businessAccountId']['stringValue'] ?? null;
$result['wabaId']             = $wabaId ?: 'MISSING';
$result['configPhoneNumberId'] = $configFields['phoneNumberId']['stringValue'] ?? 'MISSING';
$result['isConnected']        = $configFields['isConnected']['booleanValue'] ?? false;

// If WABA missing from config, detect via Meta
if (empty($wabaId) && !empty($userToken)) {
    $ownerBiz = _mg("https://graph.facebook.com/v21.0/$phoneNumberId?fields=owner_business_info", $userToken);
    $bizId = $ownerBiz['owner_business_info']['id'] ?? null;
    if ($bizId) {
        $wabaResp = _mg("https://graph.facebook.com/v21.0/$bizId/owned_whatsapp_business_accounts?fields=id", $userToken);
        $wabaId = $wabaResp['data'][0]['id'] ?? null;
        $result['wabaId_auto_detected'] = $wabaId;
    }
}

if (!$wabaId) {
    echo json_encode(['error' => 'Cannot determine WABA ID', 'result' => $result]);
    exit;
}

// ─── Step 3: Check subscription using App Token (or user token) ──
$tokenToUse = $appAccessToken ?: $userToken;
$subCheck = _mg("https://graph.facebook.com/v21.0/$wabaId/subscribed_apps", $tokenToUse);
$result['subscribed_apps_raw'] = $subCheck;

$isSubscribed = !empty($subCheck['data']);
$result['is_webhook_subscribed'] = $isSubscribed;

// ─── Step 4: If NOT subscribed → subscribe ───────────────────────
if (!$isSubscribed) {
    $result['action'] = 'NOT subscribed — attempting subscribe...';

    // Try App Token first
    if ($appAccessToken) {
        $r = _mp("https://graph.facebook.com/v21.0/$wabaId/subscribed_apps", $appAccessToken);
        $result['subscribe_with_app_token'] = $r;
        if (!empty($r['success'])) {
            $result['action_done'] = '✅ SUBSCRIBED with App Token!';
            goto done;
        }
    }

    // Fallback: User token (requires whatsapp_business_management scope)
    if ($userToken) {
        $r2 = _mp("https://graph.facebook.com/v21.0/$wabaId/subscribed_apps", $userToken);
        $result['subscribe_with_user_token'] = $r2;
        if (!empty($r2['success'])) {
            $result['action_done'] = '✅ SUBSCRIBED with User Token!';
        } else {
            $result['action_done'] = '❌ FAILED — token lacks whatsapp_business_management permission';
            $result['MANUAL_FIX'] = "Go to developers.facebook.com → Your App → WhatsApp → Configuration → Webhook → subscribe WABA $wabaId manually. Or reconnect with a System User token.";
        }
    }
} else {
    $result['action_done'] = '✅ Already subscribed!';
    $result['WHY_NOT_WORKING'] = 'WABA is subscribed but webhooks not arriving. Check: 1) Webhook URL in Meta App settings = https://api.wabees.live/api/webhook.php 2) Messages field subscribed in webhook settings';
}

done:
echo json_encode($result, JSON_PRETTY_PRINT);

// ─── Helpers ─────────────────────────────────────────────────────
function _mg($url, $token) {
    $ch = curl_init();
    curl_setopt_array($ch, [CURLOPT_URL=>$url,CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>12,CURLOPT_HTTPHEADER=>["Authorization: Bearer $token"],CURLOPT_IPRESOLVE=>CURL_IPRESOLVE_V4]);
    $r = curl_exec($ch); curl_close($ch);
    return json_decode($r, true) ?: ['raw' => substr($r,0,200)];
}
function _mp($url, $token) {
    $ch = curl_init();
    curl_setopt_array($ch, [CURLOPT_URL=>$url,CURLOPT_RETURNTRANSFER=>true,CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>'',CURLOPT_TIMEOUT=>12,CURLOPT_HTTPHEADER=>["Authorization: Bearer $token"],CURLOPT_IPRESOLVE=>CURL_IPRESOLVE_V4]);
    $r = curl_exec($ch); curl_close($ch);
    return json_decode($r, true) ?: ['raw' => substr($r,0,200)];
}
?>
