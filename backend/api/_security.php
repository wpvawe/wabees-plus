<?php
/**
 * WABEES — Shared Security Middleware
 * 
 * Include this file at the top of every API endpoint.
 * Provides: CORS, method enforcement, honeypot detection,
 * rate limiting (file-based), and input sanitization helpers.
 */

// ============ CORS ============
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ============ METHOD ENFORCEMENT ============
function enforce_post()
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => ['message' => 'Method not allowed']]);
        exit;
    }
}

// ============ HONEYPOT DETECTION ============
function check_honeypot($input)
{
    // If a hidden "website" or "url" field is filled, it's a bot
    $honeypot_fields = ['website', 'url', 'homepage', 'fax'];
    foreach ($honeypot_fields as $field) {
        if (!empty($input[$field])) {
            // Silently reject — don't reveal honeypot
            http_response_code(200);
            echo json_encode(['success' => true, 'message' => 'OK']);
            exit;
        }
    }
}

// ============ RATE LIMITING (file-based) ============
function rate_limit($identifier, $max_requests = 30, $window_seconds = 60)
{
    $rate_dir = sys_get_temp_dir() . '/wabees_rate/';
    if (!is_dir($rate_dir)) {
        @mkdir($rate_dir, 0755, true);
    }

    $safe_id = preg_replace('/[^a-zA-Z0-9_]/', '_', $identifier);
    $file = $rate_dir . $safe_id . '.json';

    $now = time();
    $data = [];

    if (file_exists($file)) {
        $raw = @file_get_contents($file);
        $data = json_decode($raw, true) ?: [];
    }

    // Clean old entries outside window
    $data = array_filter($data, function ($ts) use ($now, $window_seconds) {
        return ($now - $ts) < $window_seconds;
    });

    if (count($data) >= $max_requests) {
        http_response_code(429);
        echo json_encode([
            'error' => ['message' => 'Too many requests. Please try again later.'],
        ]);
        exit;
    }

    $data[] = $now;
    @file_put_contents($file, json_encode(array_values($data)), LOCK_EX);
}

// ============ INPUT VALIDATION HELPERS ============
function require_fields($input, $required_fields)
{
    $missing = [];
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || (is_string($input[$field]) && trim($input[$field]) === '')) {
            $missing[] = $field;
        }
    }
    if (!empty($missing)) {
        http_response_code(400);
        echo json_encode([
            'error' => ['message' => 'Missing required fields: ' . implode(', ', $missing)],
        ]);
        exit;
    }
}

function sanitize_string($value, $max_length = 1000)
{
    if (!is_string($value))
        return '';
    $value = trim($value);
    $value = mb_substr($value, 0, $max_length);
    // Remove null bytes
    $value = str_replace("\0", '', $value);
    return $value;
}

function sanitize_template_name($name)
{
    // Meta requires: lowercase, alphanumeric + underscores only
    $name = strtolower(trim($name));
    $name = preg_replace('/[^a-z0-9_]/', '_', $name);
    $name = preg_replace('/_+/', '_', $name); // collapse multiple underscores
    $name = trim($name, '_');
    return mb_substr($name, 0, 512);
}

function validate_category($category)
{
    $allowed = ['MARKETING', 'UTILITY', 'AUTHENTICATION'];
    $upper = strtoupper(trim($category));
    return in_array($upper, $allowed) ? $upper : null;
}

function validate_language_code($code)
{
    // Basic check: 2-5 chars, letters and underscores
    $code = trim($code);
    if (preg_match('/^[a-z]{2}(_[A-Z]{2})?$/', $code)) {
        return $code;
    }
    return null;
}

// ============ META API HELPER ============
function call_meta_api($url, $method = 'GET', $data = null, $access_token = null)
{
    $ch = curl_init();

    $headers = ['Content-Type: application/json'];
    if ($access_token) {
        $headers[] = "Authorization: Bearer {$access_token}";
    }

    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_HTTPHEADER => $headers,
    ]);

    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
    } elseif ($method === 'DELETE') {
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'DELETE');
    }

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($error) {
        return ['http_code' => 0, 'data' => ['error' => ['message' => "Connection error: {$error}"]]];
    }

    return [
        'http_code' => $httpCode,
        'data' => json_decode($response, true) ?: ['error' => ['message' => 'Invalid response from Meta API']],
    ];
}
?>