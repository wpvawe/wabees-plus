<?php
/**
 * WABEES — WhatsApp API Proxy: Create Template
 * 
 * Creates a new message template on Meta WhatsApp Business API
 * POST /api/create-template.php
 * 
 * Body: {
 *   business_account_id, access_token,
 *   name, category, language,
 *   header (optional), body, footer (optional),
 *   buttons (optional)
 * }
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

// Rate limit by business account
$rateLimitId = 'create_tpl_' . ($input['business_account_id'] ?? 'unknown');
rate_limit($rateLimitId, 50, 3600); // 50 creates per hour (Meta limit is 100)

// Validate required fields
require_fields($input, ['business_account_id', 'access_token', 'name', 'category', 'language', 'body']);

$businessAccountId = sanitize_string($input['business_account_id'], 50);
$accessToken = sanitize_string($input['access_token'], 500);
$name = sanitize_template_name($input['name']);
$category = validate_category($input['category']);
$language = validate_language_code($input['language']);
$bodyText = sanitize_string($input['body'], 1024);
$headerText = isset($input['header']) ? sanitize_string($input['header'], 60) : null;
$footerText = isset($input['footer']) ? sanitize_string($input['footer'], 60) : null;

// Validate processed values
if (empty($name)) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Template name must contain only lowercase letters, numbers, and underscores']]);
    exit;
}
if (!$category) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid category. Must be MARKETING, UTILITY, or AUTHENTICATION']]);
    exit;
}
if (!$language) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Invalid language code format']]);
    exit;
}
if (strlen($bodyText) < 1) {
    http_response_code(400);
    echo json_encode(['error' => ['message' => 'Template body cannot be empty']]);
    exit;
}

// Build components array for Meta API
$components = [];

if ($headerText) {
    $components[] = [
        'type' => 'HEADER',
        'format' => 'TEXT',
        'text' => $headerText,
    ];
}

// Body component with variable examples if present
$bodyComponent = [
    'type' => 'BODY',
    'text' => $bodyText,
];

// Accept user-provided variable samples
$variableSamples = isset($input['variable_samples']) && is_array($input['variable_samples'])
    ? $input['variable_samples']
    : [];

// Extract named variables {{name}}, {{order_number}} etc.
preg_match_all('/\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}/', $bodyText, $matches);
if (!empty($matches[0])) {
    $examples = [];
    foreach ($matches[1] as $varName) {
        // Use user sample if provided, otherwise generate a default
        if (isset($variableSamples[$varName]) && !empty($variableSamples[$varName])) {
            $examples[] = sanitize_string($variableSamples[$varName], 100);
        } else {
            $examples[] = "sample_{$varName}";
        }
    }
    $bodyComponent['example'] = ['body_text' => [$examples]];
}
$components[] = $bodyComponent;

if ($footerText) {
    $components[] = [
        'type' => 'FOOTER',
        'text' => $footerText,
    ];
}

// Handle buttons if provided
if (!empty($input['buttons']) && is_array($input['buttons'])) {
    $buttonComponents = [];
    foreach ($input['buttons'] as $btn) {
        if (!isset($btn['type']))
            continue;
        $buttonComponents[] = $btn;
    }
    if (!empty($buttonComponents)) {
        $components[] = [
            'type' => 'BUTTONS',
            'buttons' => $buttonComponents,
        ];
    }
}

// Call Meta API
$url = "https://graph.facebook.com/v21.0/{$businessAccountId}/message_templates";

$payload = [
    'name' => $name,
    'category' => $category,
    'language' => $language,
    'components' => $components,
];

$result = call_meta_api($url, 'POST', $payload, $accessToken);

http_response_code($result['http_code'] >= 200 && $result['http_code'] < 300 ? 200 : $result['http_code']);
echo json_encode($result['data']);
?>