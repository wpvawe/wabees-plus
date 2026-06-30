<?php
/**
 * WABEES Backend — API Health Check
 * GET /api/index.php — returns API status
 */

header('Content-Type: application/json');

echo json_encode([
    'status' => 'ok',
    'app' => 'WABEES WhatsApp API',
    'version' => '1.1.2',
    'endpoints' => [
        'POST /api/verify-token.php' => 'Verify WhatsApp credentials',
        'POST /api/send-message.php' => 'Send WhatsApp message',
        'POST /api/get-templates.php' => 'Fetch message templates',
        'GET/POST /api/webhook.php' => 'WhatsApp webhook handler',
    ],
    'timestamp' => date('c'),
]);
?>