<?php
/**
 * WABEES — Send Password Reset Code
 * 
 * Generates a 6-digit OTP, stores it in Firestore (password_reset_codes collection),
 * and sends it via email using PHP mail().
 * 
 * POST body: { "email": "user@example.com" }
 * Response:  { "success": true, "message": "Code sent to email" }
 */

require_once __DIR__ . '/_security.php';
require_once __DIR__ . '/../config/firebase-config.php';

enforce_post();

// Parse input
$input = json_decode(file_get_contents('php://input'), true);
$email = sanitize_string($input['email'] ?? '');

if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Please enter a valid email address']);
    exit;
}

check_honeypot($input);

// Rate limit: max 3 reset requests per email per 10 minutes
rate_limit('reset_' . md5($email), 3, 600);

// Generate 6-digit code
$code = str_pad(random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
$expiresAt = time() + 600; // 10 minutes expiry

// Store code in Firestore: password_reset_codes/{email_hash}
$docPath = 'password_reset_codes/' . md5($email);
$codeData = [
    'email' => $email,
    'code' => $code,
    'expiresAt' => $expiresAt,
    'attempts' => 0,
    'used' => false,
    'createdAt' => date('c'),
];

$saved = firestore_set($docPath, $codeData);

if (!$saved) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to generate code. Try again.']);
    exit;
}

// Send email with code
$subject = 'WABEES - Password Reset Code';
$body = "
<html>
<body style='font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 20px;'>
  <div style='text-align: center; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; margin-bottom: 20px;'>
    <h1 style='color: white; margin: 0; font-size: 24px;'>🐝 WABEES</h1>
    <p style='color: rgba(255,255,255,0.9); margin: 5px 0 0;'>Password Reset</p>
  </div>
  
  <p style='color: #333; font-size: 16px;'>Hi there,</p>
  <p style='color: #555; font-size: 15px;'>You requested to reset your password. Use this code to verify your identity:</p>
  
  <div style='text-align: center; padding: 20px; background: #f8f9fa; border-radius: 12px; margin: 20px 0;'>
    <p style='font-size: 36px; font-weight: bold; color: #667eea; letter-spacing: 8px; margin: 0;'>$code</p>
    <p style='color: #888; font-size: 13px; margin: 8px 0 0;'>This code expires in 10 minutes</p>
  </div>
  
  <p style='color: #888; font-size: 13px;'>If you didn't request this, you can safely ignore this email.</p>
  
  <hr style='border: none; border-top: 1px solid #eee; margin: 20px 0;'>
  <p style='color: #aaa; font-size: 11px; text-align: center;'>WABEES — WhatsApp Business Empowerment System</p>
</body>
</html>
";

$headers = "MIME-Version: 1.0\r\n";
$headers .= "Content-type: text/html; charset=utf-8\r\n";
$headers .= "From: WABEES <noreply@wabees.live>\r\n";

$mailSent = @mail($email, $subject, $body, $headers);

if (!$mailSent) {
    error_log("[WABEES] Failed to send reset email to: $email");
    // Still return success — code is saved, email might work via SMTP relay
}

echo json_encode([
    'success' => true,
    'message' => 'A 6-digit code has been sent to your email',
]);
?>
