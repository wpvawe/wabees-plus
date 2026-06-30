<?php
header('Content-Type: text/plain');
require_once __DIR__ . '/../config/firebase-config.php';

// Show ALL AI-related log lines from today
$logFile = __DIR__ . '/../logs/webhook_' . date('Y-m-d') . '.log';
if (!file_exists($logFile)) {
    echo "No log file for today\n";
    exit;
}
$lines = file($logFile, FILE_IGNORE_NEW_LINES);
echo "Total lines: " . count($lines) . "\n\n";

// Find all AI_BOT lines
echo "=== AI_BOT LINES ===\n";
foreach ($lines as $i => $line) {
    if (stripos($line, 'AI_BOT') !== false || stripos($line, 'ai_bot') !== false || stripos($line, 'deepseek') !== false) {
        echo $line . "\n";
    }
}

echo "\n=== LAST 20 LINES ===\n";
$last = array_slice($lines, -20);
foreach ($last as $line) {
    echo $line . "\n";
}
