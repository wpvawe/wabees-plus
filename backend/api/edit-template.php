<?php
/**
 * WABEES — WhatsApp API Proxy: Edit Template
 * 
 * Edits an existing message template on Meta WhatsApp Business API.
 * Only body/header/footer text can be changed (Meta restriction).
 * POST /api/edit-template.php
 * 
 * Body: {
 *   access_token, template_id,
 *   header (optional), body, footer (optional),
 *   category (optional — for re-categorization)
 * }
 * 
 * Note: Meta allows max 10 edits per 30 days for approved templates.
 *       Rejected/Paused templates can be edited unlimited times.
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
$rateLimitId = 'edit_tpl_' . ($input['template_id'] ?? 'unknown');
rate_limit($rateLimitId, 10, 3600); // 10 edits per hour per template

// Validate required fields
require_fields($input, ['access_token', 'template_id', 'body']);

$accessToken = sanitize_string($input['access_token'], 500);
$templateId = sanitize_string($input['template_id'], 50);
$bodyText = sanitize_string($input['body'], 1024);
$headerText = isset($input['header']) ? sanitize_string($input['header'], 60) : null;
$footerText = isset($input['footer']) ? sanitize_string($input['footer'], 60) : null;
$category = isset($input['category']) ? validate_category($input['category']) : null;

if (strlen($bodyText) < 1) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Template body cannot be empty']]);
    exit;
}

// Build updated components
$components = [];

if ($headerText) {
    $components[] = [
        'type' => 'HEADER',
        'format' => 'TEXT',
        'text' => $headerText,
    ];
}

$bodyComponent = [
    'type' => 'BODY',
    'text' => $bodyText,
];

// Re-generate example values for variables
preg_match_all('/\{\{(\d+)\}\}/', $bodyText, $matches);
if (!empty($matches[0])) {
    $examples = array_map(function ($num) {
        return "sample_{$num}";
    }, $matches[1]);
    $bodyComponent['example'] = ['body_text' => [$examples]];
}
$components[] = $bodyComponent;

if ($footerText) {
    $components[] = [
        'type' => 'FOOTER',
        'text' => $footerText,
    ];
}

// Call Meta API to update template
$url = "https://graph.facebook.com/v21.0/{$templateId}";

$payload = ['components' => $components];
if ($category) {
    $payload['category'] = $category;
}

$result = call_meta_api($url, 'POST', $payload, $accessToken);

http_response_code($result['http_code'] >= 200 && $result['http_code'] < 300 ? 200 : $result['http_code']);
echo json_encode($result['data']);
?>