<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/firebase-config.php';

$secret = $_GET['s'] ?? '';
if ($secret !== 'wabees2025debug') { http_response_code(403); echo json_encode(['error'=>'forbidden']); exit; }

$cnic = $_GET['cnic'] ?? '3430146825747';

$results = [];

// akhuwatguide
$ch1 = curl_init();
curl_setopt_array($ch1, [
    CURLOPT_URL => 'https://akhuwatguide.com/wp-json/alm/v1/loan-check?cnic=' . $cnic,
    CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10,
    CURLOPT_HTTPHEADER => ['Authorization: Bearer alm_qa5R2phEjHf0zYgqBzj1LA48xslp69Z9LfIx'],
    CURLOPT_SSL_VERIFYPEER => false,
]);
$r1 = curl_exec($ch1); $c1 = curl_getinfo($ch1, CURLINFO_HTTP_CODE); curl_close($ch1);

// akhuwatorg
$ch2 = curl_init();
curl_setopt_array($ch2, [
    CURLOPT_URL => 'https://akhuwatorg.com/api/loan-check?cnic=' . $cnic,
    CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10,
    CURLOPT_HTTPHEADER => ['Authorization: Bearer akw_K6pL9mX2nQr4vT8wYjZ3sD7hF1cA5uB0'],
    CURLOPT_SSL_VERIFYPEER => false,
]);
$r2 = curl_exec($ch2); $c2 = curl_getinfo($ch2, CURLINFO_HTTP_CODE); curl_close($ch2);

echo json_encode([
    'akhuwatguide' => ['http' => $c1, 'raw' => json_decode($r1, true)],
    'akhuwatorg'   => ['http' => $c2, 'raw' => json_decode($r2, true)],
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
