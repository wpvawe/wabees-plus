<?php
/**
 * WABEES — WhatsApp API Proxy: Delete Template
 * 
 * Deletes a message template from Meta WhatsApp Business API.
 * WARNING: This deletes ALL language versions of the template.
 * Deleted template names cannot be reused for 30 days.
 * POST /api/delete-template.php
 * 
 * Body: { business_account_id, access_token, template_name }
 */

require_once __DIR__ . '/_security.php';

enforce_post();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid JSON body']]);
    exit;
}

check_honeypot($input);

// Rate limit
$rateLimitId = 'delete_tpl_' . ($input['business_account_id'] ?? 'unknown');
rate_limit($rateLimitId, 20, 3600); // 20 deletes per hour

// Validate
require_fields($input, ['business_account_id', 'access_token', 'template_name']);

$businessAccountId = sanitize_string($input['business_account_id'], 50);
$accessToken = sanitize_string($input['access_token'], 500);
$templateName = sanitize_template_name($input['template_name']);

if (empty($templateName)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid template name']]);
    exit;
}

// Call Meta API — DELETE method
// For DELETE requests, Meta requires access_token as URL query parameter
$url = "https://graph.facebook.com/v21.0/{$businessAccountId}/message_templates"
    . "?name=" . urlencode($templateName)
    . "&access_token=" . urlencode($accessToken);

$result = call_meta_api($url, 'DELETE', null, null);

http_response_code($result['http_code'] >= 200 && $result['http_code'] < 300 ? 200 : $result['http_code']);
echo json_encode($result['data']);
?>