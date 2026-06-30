<?php
/**
 * WABEES — Download API
 * Handles tracking and serving download URL
 */
// Robust config loader (works in /download or web root)
function _load_firebase_config()
{
  $candidates = [
    __DIR__ . '/../config/firebase-config.php',
    __DIR__ . '/config/firebase-config.php',
    __DIR__ . '/../../backend/config/firebase-config.php',
  ];
  foreach ($candidates as $p) {
    $real = realpath($p);
    if ($real && file_exists($real)) {
      require_once $real;
      return true;
    }
  }
  return false;
}
$_HAS_CONFIG = _load_firebase_config();

$action = $_GET['action'] ?? '';
define('WABEES_DISPLAY_BASE', 1045); // Pre-tracking downloads — must match index.php

// ============ ACTION: TRACK DOWNLOAD ============
if ($action === 'track_download') {
  header('Content-Type: application/json');
  $docPath = 'system/stats';

  // 1. Get current count
  $current = 0;
  if ($_HAS_CONFIG) {
    $response = firestore_get($docPath);
    if (isset($response['data']['fields']['totalDownloads']['integerValue'])) {
      $current = (int) $response['data']['fields']['totalDownloads']['integerValue'];
    }
  } else {
    // Local file fallback when Firestore config is unavailable
    $file = __DIR__ . '/download_count.json';
    if (file_exists($file)) {
      $raw = @file_get_contents($file);
      $val = @json_decode($raw, true);
      if (is_int($val))
        $current = $val;
    }
  }

  // 2. Increment count
  $newCount = $current + 1;
  if ($_HAS_CONFIG) {
    firestore_set($docPath, ['totalDownloads' => $newCount]);
  } else {
    @file_put_contents(__DIR__ . '/download_count.json', json_encode($newCount));
  }

  // 3. Return streaming URL (relative path — avoids mixed content behind LB)
  $downloadUrl = '/download/api.php?action=stream_file';

  echo json_encode([
    'success' => true,
    'count' => $newCount + WABEES_DISPLAY_BASE, // Display count (base + real)
    'url' => $downloadUrl
  ]);
  exit;
}

// ============ ACTION: GET COUNT ONLY ============
if ($action === 'get_count') {
  header('Content-Type: application/json');
  $docPath = 'system/stats';
  $current = 0;
  if ($_HAS_CONFIG) {
    $response = firestore_get($docPath);
    if (isset($response['data']['fields']['totalDownloads']['integerValue'])) {
      $current = (int) $response['data']['fields']['totalDownloads']['integerValue'];
    }
  } else {
    $file = __DIR__ . '/download_count.json';
    if (file_exists($file)) {
      $raw = @file_get_contents($file);
      $val = @json_decode($raw, true);
      if (is_int($val))
        $current = $val;
    }
  }
  echo json_encode(['count' => $current + WABEES_DISPLAY_BASE]);
  exit;
}


// ============ ACTION: VISITOR COUNT (ATOMIC) ============
if ($action === 'visitor_count') {
  header('Content-Type: application/json');
  header('Access-Control-Allow-Origin: *');
  $date = $_GET['date'] ?? date('Y-m-d');
  $date = preg_replace('/[^0-9-]/', '', $date);
  $count = 0;

  if ($_HAS_CONFIG) {
    $docPath = 'site_stats/visitors_' . $date;
    $fullDocName = 'projects/' . FIREBASE_PROJECT_ID . '/databases/(default)/documents/' . $docPath;

    // Increment atomically if new visit (no read-then-write race condition)
    if (isset($_GET['new'])) {
      $writes = [
        [
          'transform' => [
            'document' => $fullDocName,
            'fieldTransforms' => [[
              'fieldPath' => 'count',
              'increment' => ['integerValue' => '1'],
            ]],
          ],
        ],
      ];
      $commitResult = firestore_commit($writes);

      // Read back the updated count
      if (($commitResult['code'] ?? 500) < 400) {
        $response = firestore_get($docPath);
        $count = (int) ($response['data']['fields']['count']['integerValue'] ?? 1);
      } else {
        // Commit failed — try to read existing count
        $response = firestore_get($docPath);
        $count = (int) ($response['data']['fields']['count']['integerValue'] ?? 0);
        $count = max(1, $count);
      }
    } else {
      // Just read current count
      $response = firestore_get($docPath);
      $count = (int) ($response['data']['fields']['count']['integerValue'] ?? 0);
    }
  } else {
    // Fallback to tmp file
    $countFile = sys_get_temp_dir() . '/wabees_visitors_' . $date . '.json';
    if (file_exists($countFile))
      $count = (int) @file_get_contents($countFile);
    if (isset($_GET['new'])) {
      $count++;
      @file_put_contents($countFile, $count);
    }
  }

  echo json_encode(['count' => max(1, $count), 'date' => $date]);
  exit;
}
// ============ ACTION: STREAM FILE (SECURE) ============
if ($action === 'stream_file') {
  $filePath = __DIR__ . '/wabees.apk';

  if (!file_exists($filePath)) {
    header("HTTP/1.0 404 Not Found");
    echo "File not found.";
    exit;
  }

  // Serve file headers
  header('Content-Description: File Transfer');
  header('Content-Type: application/vnd.android.package-archive');
  header('Content-Disposition: attachment; filename="wabees.apk"'); // Clean filename for user
  header('Expires: 0');
  header('Cache-Control: must-revalidate');
  header('Pragma: public');
  header('Content-Length: ' . filesize($filePath));

  // Clear output buffer
  while (ob_get_level() > 0) {
    ob_end_clean();
  }

  // Stream file in chunks to avoid Cloud Run memory limits
  ob_implicit_flush(true);
  $handle = fopen($filePath, 'rb');
  if ($handle) {
    while (!feof($handle)) {
      echo fread($handle, 8192);
      flush();
    }
    fclose($handle);
  }
  exit;
}

header('Content-Type: application/json');
echo json_encode(['error' => 'Invalid action']);
?>