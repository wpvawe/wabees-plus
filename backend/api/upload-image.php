<?php
/**
 * WABEES — Upload Image
 * 
 * Receives an image file via multipart form upload,
 * saves it to a public directory, and returns the URL.
 * Used by the support chat to upload images.
 * 
 * POST: multipart/form-data with 'image' field
 * Response: { "success": true, "url": "https://..." }
 */

require_once __DIR__ . '/_security.php';
require_once __DIR__ . '/../config/site-config.php';

enforce_post();

// Validate file upload
if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    $errorMsg = 'No image uploaded';
    if (isset($_FILES['image'])) {
        switch ($_FILES['image']['error']) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                $errorMsg = 'Image is too large. Max 5MB.';
                break;
            case UPLOAD_ERR_PARTIAL:
                $errorMsg = 'Upload incomplete. Try again.';
                break;
            case UPLOAD_ERR_NO_FILE:
                $errorMsg = 'No image selected.';
                break;
        }
    }
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $errorMsg]);
    exit;
}

$file = $_FILES['image'];

// Validate file type
$allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

if (!in_array($mimeType, $allowedTypes)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Only JPEG, PNG, GIF, and WebP images are allowed']);
    exit;
}

// Validate file size (max 5MB)
$maxSize = 5 * 1024 * 1024; // 5MB
if ($file['size'] > $maxSize) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Image is too large. Max 5MB.']);
    exit;
}

// Rate limit: max 20 uploads per IP per 10 minutes
rate_limit('upload_' . md5($_SERVER['REMOTE_ADDR'] ?? 'unknown'), 20, 600);

// Generate unique filename
$ext = match ($mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    default => 'jpg',
};
$filename = uniqid('support_', true) . '.' . $ext;

// Create uploads directory if it doesn't exist
$uploadDir = __DIR__ . '/../uploads/support/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

$targetPath = $uploadDir . $filename;

// Move uploaded file
if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to save image. Try again.']);
    exit;
}

// Build public URL
$scheme = defined('PUBLIC_SCHEME') ? PUBLIC_SCHEME : ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http');
$host = defined('PUBLIC_HOST') ? PUBLIC_HOST : ($_SERVER['HTTP_HOST'] ?? 'wabees.live');
$publicUrl = $scheme . '://' . $host . '/uploads/support/' . $filename;

echo json_encode([
    'success' => true,
    'url' => $publicUrl,
    'message' => 'Image uploaded successfully',
]);
?>
