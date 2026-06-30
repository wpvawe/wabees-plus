<?php
header('Content-Type: application/json');
header('Cache-Control: no-store');
header('Access-Control-Allow-Origin: *');

$checks = [
  'php' => PHP_VERSION,
  'time' => gmdate('Y-m-d\TH:i:s\Z'),
  'apcu' => function_exists('apcu_fetch'),
  'fastcgi' => function_exists('fastcgi_finish_request'),
];

$dirs = [
  __DIR__ . '/../uploads/media',
  __DIR__ . '/../uploads/support',
  __DIR__ . '/../logs',
  __DIR__ . '/../cache',
];

$writable = [];
foreach ($dirs as $d) {
  if (!is_dir($d)) @mkdir($d, 0755, true);
  $writable[basename($d)] = is_writable($d);
}

echo json_encode([
  'success' => true,
  'checks' => $checks,
  'writable' => $writable,
  'memory' => round(memory_get_usage() / 1024 / 1024, 2) . 'MB'
]);
?>
