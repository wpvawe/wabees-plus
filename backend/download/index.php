<?php
/**
 * WABEES — Landing / Download Page
 * Premium design with 3D bee animation, full bilingual (EN/UR) support,
 * responsive layout, and modern glass-morphism aesthetics.
 */
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

$realDownloads = 0;
if ($_HAS_CONFIG) {
  $docPath = 'system/stats';
  $response = firestore_get($docPath);
  if (isset($response['data']['fields']['totalDownloads']['integerValue'])) {
    $realDownloads = (int) $response['data']['fields']['totalDownloads']['integerValue'];
  } else {
    $realDownloads = 0;
    firestore_set($docPath, ['totalDownloads' => 0]);
  }
}
if ($realDownloads === 0 && !$_HAS_CONFIG) {
  $file = __DIR__ . '/download_count.json';
  if (file_exists($file)) {
    $raw = @file_get_contents($file);
    $val = @json_decode($raw, true);
    if (is_int($val))
      $realDownloads = $val;
  }
}
define('WABEES_DISPLAY_BASE', 1045); // Pre-tracking downloads — must match api.php
$displayCount = WABEES_DISPLAY_BASE + $realDownloads;

// Get real APK file size
$apkPath = __DIR__ . '/wabees.apk';
$apkSizeMB = '';
if (file_exists($apkPath)) {
  $bytes = filesize($apkPath);
  $apkSizeMB = round($bytes / (1024 * 1024), 1) . ' MB';
}

// Get app version from version.txt (auto-generated from pubspec.yaml during build)
$versionFile = __DIR__ . '/version.txt';
$appVersion = 'v1.5.1'; // fallback
if (file_exists($versionFile)) {
  $raw = trim(file_get_contents($versionFile));
  if (!empty($raw)) $appVersion = $raw;
}

// Always use absolute paths — page may be served from / or /download/
$ASSET_BASE = '/download/assets';
$API_PATH = '/download/api.php';
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="facebook-domain-verification" content="jy3u6kbnq3ratwkdzehj6es6qs3qtw" />
  <title>Wabees — WhatsApp Marketing Automation</title>
  <meta name="description"
    content="Automate WhatsApp replies, manage campaigns, and grow your business with Wabees — the most powerful WhatsApp marketing tool for Android.">
  <link rel="icon" type="image/png" href="<?= $ASSET_BASE ?>/images/app_icon.png">
  <?php if (file_exists(__DIR__ . '/assets/css/tailwind.css')): ?>
    <link href="assets/css/tailwind.css" rel="stylesheet">
  <?php else: ?>
    <script src="https://cdn.tailwindcss.com"></script>
  <?php endif; ?>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap"
    rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
  <!-- Three.js for 3D bee -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <style>
    :root {
      --clr-primary: #128C7E;
      --clr-primary-dark: #075E54;
      --clr-accent: #25D366;
      --clr-gold: #FFB800;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: #0a0f1a;
      color: #e2e8f0;
      overflow-x: hidden;
    }

    /* ===== GRADIENTS & EFFECTS ===== */
    .gradient-text {
      background: linear-gradient(135deg, #25D366 0%, #128C7E 50%, #075E54 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }

    .gold-text {
      background: linear-gradient(135deg, #FFB800 0%, #FF8C00 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }

    .glass {
      background: rgba(255, 255, 255, 0.04);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid rgba(255, 255, 255, 0.08);
    }

    .glass-stronger {
      background: rgba(255, 255, 255, 0.07);
      backdrop-filter: blur(30px);
      -webkit-backdrop-filter: blur(30px);
      border: 1px solid rgba(255, 255, 255, 0.12);
    }

    /* ===== HERO BG ===== */
    .hero-bg {
      position: relative;
      background: radial-gradient(ellipse at 30% 0%, rgba(18, 140, 126, 0.15) 0%, transparent 60%),
        radial-gradient(ellipse at 70% 100%, rgba(37, 211, 102, 0.08) 0%, transparent 50%),
        #0a0f1a;
    }

    .hero-bg::before {
      content: '';
      position: absolute;
      inset: 0;
      background: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23128C7E' fill-opacity='0.03'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
      pointer-events: none;
    }

    /* ===== 3D BEE CANVAS ===== */
    #bee-canvas {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      z-index: 99;
      pointer-events: none;
    }

    .content-layer {
      position: relative;
      z-index: 10;
    }

    /* ===== ANIMATIONS ===== */
    @keyframes float {

      0%,
      100% {
        transform: translateY(0)
      }

      50% {
        transform: translateY(-12px)
      }
    }

    @keyframes fadeUp {
      from {
        opacity: 0;
        transform: translateY(30px)
      }

      to {
        opacity: 1;
        transform: translateY(0)
      }
    }

    @keyframes pulse-ring {
      0% {
        transform: scale(0.9);
        opacity: 0.6
      }

      100% {
        transform: scale(1.3);
        opacity: 0
      }
    }

    @keyframes shimmer {
      0% {
        background-position: -200% 0
      }

      100% {
        background-position: 200% 0
      }
    }

    .animate-float {
      animation: float 4s ease-in-out infinite;
    }

    .animate-fade-up {
      animation: fadeUp 0.8s ease-out both;
    }

    .animate-fade-up-d1 {
      animation: fadeUp 0.8s ease-out 0.1s both;
    }

    .animate-fade-up-d2 {
      animation: fadeUp 0.8s ease-out 0.2s both;
    }

    .animate-fade-up-d3 {
      animation: fadeUp 0.8s ease-out 0.3s both;
    }

    .animate-fade-up-d4 {
      animation: fadeUp 0.8s ease-out 0.4s both;
    }

    .shimmer-btn {
      background-size: 200% 100%;
      background-image: linear-gradient(110deg, transparent 25%, rgba(255, 255, 255, 0.1) 50%, transparent 75%);
      animation: shimmer 3s ease-in-out infinite;
    }

    /* ===== DOWNLOAD BUTTON ===== */
    .dl-btn {
      background: linear-gradient(135deg, var(--clr-primary) 0%, var(--clr-primary-dark) 100%);
      transition: all 0.3s ease;
      position: relative;
      overflow: hidden;
    }

    .dl-btn:hover {
      transform: translateY(-3px);
      box-shadow: 0 20px 40px -15px rgba(18, 140, 126, 0.5);
    }

    .dl-btn::after {
      content: '';
      position: absolute;
      inset: 0;
      background-size: 200% 100%;
      background-image: linear-gradient(110deg, transparent 25%, rgba(255, 255, 255, 0.15) 50%, transparent 75%);
      animation: shimmer 3s ease-in-out infinite;
    }

    /* ===== BENEFIT CARDS ===== */
    .benefit-card {
      transition: all 0.3s ease;
    }

    .benefit-card:hover {
      transform: translateY(-4px);
      border-color: rgba(37, 211, 102, 0.3);
      box-shadow: 0 15px 40px -10px rgba(18, 140, 126, 0.15);
    }

    .benefit-card .icon-box {
      transition: all 0.3s ease;
    }

    .benefit-card:hover .icon-box {
      transform: scale(1.1);
    }

    /* ===== GUIDE SECTION ===== */
    .guide-step {
      counter-increment: steps;
      position: relative;
    }

    .guide-step::before {
      content: counter(steps);
      position: absolute;
      left: -40px;
      top: 0;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: linear-gradient(135deg, var(--clr-primary), var(--clr-primary-dark));
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 14px;
    }

    [dir="rtl"] .guide-step::before {
      left: auto;
      right: -40px;
    }

    .guide-step img {
      width: 100%;
      height: auto;
      object-fit: cover;
      border-radius: 12px;
    }

    /* ===== SLIDER ===== */
    .slide {
      scroll-snap-align: start;
    }

    /* ===== LIGHTBOX ===== */
    #lightbox {
      transition: opacity 0.3s ease;
    }

    /* ===== LANG TOGGLE ===== */
    .lang-toggle .active {
      background: var(--clr-primary);
      color: #fff;
      border-color: var(--clr-primary);
    }

    /* ===== NAVBAR ===== */
    .navbar {
      transition: all 0.3s ease;
    }

    .navbar.scrolled {
      background: rgba(10, 15, 26, 0.95);
      box-shadow: 0 4px 30px rgba(0, 0, 0, 0.3);
    }

    /* ===== RTL ===== */
    [dir="rtl"] {
      text-align: right;
    }

    [dir="rtl"] .guide-steps {
      counter-reset: steps;
    }

    /* ===== RESPONSIVE ===== */
    @media (max-width: 640px) {
      .guide-step::before {
        width: 26px;
        height: 26px;
        font-size: 12px;
        left: -34px;
      }

      [dir="rtl"] .guide-step::before {
        right: -34px;
        left: auto;
      }
    }

    /* ===== WHATSAPP FLOATING BUTTON ===== */
    .wa-float-btn {
      position: fixed;
      bottom: 28px;
      left: 28px;
      z-index: 1000;
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: linear-gradient(135deg, #25D366 0%, #128C7E 100%);
      box-shadow: 0 8px 32px rgba(37, 211, 102, 0.4), 0 0 0 0 rgba(37, 211, 102, 0.4);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.3s ease;
      animation: wa-pulse 2s ease-in-out infinite;
      border: none;
    }

    .wa-float-btn:hover {
      transform: scale(1.1);
      box-shadow: 0 12px 40px rgba(37, 211, 102, 0.5);
    }

    .wa-float-btn i {
      font-size: 30px;
      color: #fff;
    }

    @keyframes wa-pulse {

      0%,
      100% {
        box-shadow: 0 8px 32px rgba(37, 211, 102, 0.4), 0 0 0 0 rgba(37, 211, 102, 0.4);
      }

      50% {
        box-shadow: 0 8px 32px rgba(37, 211, 102, 0.4), 0 0 0 12px rgba(37, 211, 102, 0);
      }
    }

    .wa-popup {
      position: fixed;
      bottom: 105px;
      left: 28px;
      z-index: 1001;
      width: 370px;
      max-width: calc(100vw - 32px);
      border-radius: 20px;
      overflow: hidden;
      transform: scale(0.5) translateY(20px);
      opacity: 0;
      pointer-events: none;
      transition: all 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
      box-shadow: 0 25px 60px rgba(0, 0, 0, 0.5);
    }

    .wa-popup.open {
      transform: scale(1) translateY(0);
      opacity: 1;
      pointer-events: auto;
    }

    .wa-popup-header {
      background: linear-gradient(135deg, #075E54 0%, #128C7E 100%);
      padding: 18px 20px;
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .wa-popup-avatar {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: linear-gradient(135deg, #FFB800 0%, #FF8C00 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      font-weight: 800;
      color: #fff;
      flex-shrink: 0;
    }

    .wa-popup-header-info h4 {
      color: #fff;
      font-size: 15px;
      font-weight: 700;
      margin-bottom: 2px;
    }

    .wa-popup-header-info p {
      color: rgba(255, 255, 255, 0.7);
      font-size: 12px;
    }

    .wa-popup-close {
      margin-left: auto;
      background: rgba(255, 255, 255, 0.15);
      border: none;
      color: #fff;
      width: 30px;
      height: 30px;
      border-radius: 50%;
      cursor: pointer;
      font-size: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.2s;
    }

    .wa-popup-close:hover {
      background: rgba(255, 255, 255, 0.25);
    }

    .wa-popup-body {
      background: #0d1520;
      padding: 20px;
    }

    .wa-popup-body .welcome-msg {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 14px;
      padding: 14px 16px;
      color: rgba(255, 255, 255, 0.8);
      font-size: 13px;
      line-height: 1.6;
      margin-bottom: 16px;
    }

    .wa-quick-msgs {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 16px;
    }

    .wa-quick-msg {
      background: rgba(37, 211, 102, 0.08);
      border: 1px solid rgba(37, 211, 102, 0.2);
      color: #25D366;
      padding: 8px 14px;
      border-radius: 20px;
      font-size: 12px;
      cursor: pointer;
      transition: all 0.2s;
      font-weight: 500;
    }

    .wa-quick-msg:hover {
      background: rgba(37, 211, 102, 0.15);
      border-color: rgba(37, 211, 102, 0.4);
      transform: translateY(-1px);
    }

    .wa-input-row {
      display: flex;
      gap: 10px;
      align-items: center;
    }

    .wa-input-row input {
      flex: 1;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: #fff;
      padding: 12px 16px;
      border-radius: 14px;
      font-size: 13px;
      outline: none;
      transition: border-color 0.2s;
      font-family: inherit;
    }

    .wa-input-row input::placeholder {
      color: rgba(255, 255, 255, 0.3);
    }

    .wa-input-row input:focus {
      border-color: rgba(37, 211, 102, 0.5);
    }

    .wa-send-btn {
      width: 46px;
      height: 46px;
      border-radius: 50%;
      background: linear-gradient(135deg, #25D366, #128C7E);
      border: none;
      color: #fff;
      font-size: 18px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
      flex-shrink: 0;
    }

    .wa-send-btn:hover {
      transform: scale(1.08);
      box-shadow: 0 4px 20px rgba(37, 211, 102, 0.4);
    }

    .visitor-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 11px;
      color: rgba(255, 255, 255, 0.4);
    }

    .visitor-badge .dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #25D366;
      animation: dot-pulse 1.5s ease-in-out infinite;
    }

    @keyframes dot-pulse {

      0%,
      100% {
        opacity: 1;
      }

      50% {
        opacity: 0.3;
      }
    }

    @media (max-width: 640px) {
      .wa-float-btn {
        width: 56px;
        height: 56px;
        bottom: 20px;
        left: 20px;
      }

      .wa-float-btn i {
        font-size: 26px;
      }

      .wa-popup {
        bottom: 90px;
        left: 16px;
        width: calc(100vw - 32px);
      }
    }
  </style>
</head>

<body>
  <!-- 3D Bee Canvas -->
  <div id="bee-canvas"></div>

  <div class="content-layer">

    <!-- ===== TOP BAR ===== -->
    <div
      class="bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900 text-white/70 text-xs border-b border-white/5">
      <div class="max-w-7xl mx-auto px-4 py-2 flex flex-col sm:flex-row items-center justify-between gap-2">
        <div class="flex items-center gap-2">
          <i class="fa-solid fa-location-dot text-emerald-400"></i>
          <span class="text-[11px] leading-snug" data-i18n="address">Office # 432, 4th Floor, Mall of Islamabad, Jinnah
            Ave, Blue Area, Islamabad 44000</span>
        </div>
        <a href="tel:03088498449" class="flex items-center gap-2 hover:text-white transition text-[11px]">
          <i class="fa-solid fa-phone text-emerald-400"></i> 0308‑8498449
        </a>
      </div>
    </div>

    <!-- ===== NAVBAR ===== -->
    <nav class="navbar glass sticky top-0 z-50 border-b border-white/5">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16 items-center">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl overflow-hidden shadow-lg ring-2 ring-emerald-500/20">
              <img src="<?= $ASSET_BASE ?>/images/app_icon.png" alt="Wabees Logo" class="w-full h-full object-cover">
            </div>
            <span class="font-bold text-xl text-white">Wabees</span>
          </div>
          <div class="flex items-center gap-3">
            <span id="api-badge"
              class="px-2.5 py-1 rounded-full text-[11px] glass border border-white/10 text-white/50">API:
              Checking…</span>
            <div class="lang-toggle flex gap-1">
              <button id="btn-en"
                class="px-2.5 py-1 rounded-lg border border-white/20 text-xs text-white/70 hover:text-white transition">EN</button>
              <button id="btn-ur"
                class="px-2.5 py-1 rounded-lg border border-white/20 text-xs text-white/70 hover:text-white transition">اردو</button>
            </div>
          </div>
        </div>
      </div>
    </nav>

    <!-- ===== HERO SECTION ===== -->
    <section class="hero-bg min-h-[90vh] flex items-center justify-center px-4 py-16 sm:py-20">
      <div class="max-w-5xl w-full text-center space-y-8">

        <!-- App Icon -->
        <div class="relative mx-auto w-28 h-28 sm:w-36 sm:h-36 animate-float">
          <div class="absolute inset-0 bg-emerald-500 rounded-[28px] blur-2xl opacity-25"></div>
          <div class="absolute -inset-2 rounded-[32px] animate-pulse"
            style="animation: pulse-ring 2.5s ease-out infinite; border: 2px solid rgba(37,211,102,0.2);"></div>
          <img src="<?= $ASSET_BASE ?>/images/app_icon.png" alt="Wabees"
            class="relative w-full h-full object-cover rounded-[28px] shadow-2xl ring-4 ring-white/10">
        </div>

        <!-- Title -->
        <div class="space-y-4 animate-fade-up">
          <h1 id="hero-title"
            class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-tight tracking-tight"></h1>
          <p id="hero-sub" class="max-w-2xl mx-auto text-base sm:text-lg text-white/50 leading-relaxed"></p>
        </div>

        <!-- Download Button -->
        <div class="animate-fade-up-d2 max-w-sm mx-auto">
          <a href="javascript:void(0)" onclick="startDownloadProcess()" id="download-btn"
            class="dl-btn w-full flex items-center justify-center gap-4 px-8 py-5 text-white rounded-2xl shadow-2xl">
            <i class="fa-brands fa-android text-3xl text-emerald-300 relative z-10"></i>
            <div class="text-left relative z-10">
              <div id="dl-line1" class="text-xs font-medium text-emerald-200/70 uppercase tracking-wider">Download for
              </div>
              <div id="dl-line2" class="text-xl font-bold">Android</div>
            </div>
          </a>
        </div>

        <!-- Stats -->
        <div class="animate-fade-up-d3 flex flex-nowrap justify-center gap-1.5 sm:gap-2 overflow-x-auto px-2">
          <div class="glass rounded-full px-2.5 py-1 flex items-center gap-1 text-[10px] sm:text-xs whitespace-nowrap">
            <i class="fa-solid fa-download text-emerald-400 text-[9px] sm:text-[11px]"></i>
            <span id="download-count" class="font-bold text-white"><?php echo number_format($displayCount); ?></span>
            <span class="text-white/40 hidden sm:inline">Downloads</span>
          </div>
          <div class="glass rounded-full px-2.5 py-1 flex items-center gap-1 text-[10px] sm:text-xs whitespace-nowrap">
            <i class="fa-solid fa-code-branch text-yellow-400 text-[9px] sm:text-[11px]"></i>
            <span class="font-bold text-white"><?php echo $appVersion; ?></span>
          </div>
          <div class="glass rounded-full px-2.5 py-1 flex items-center gap-1 text-[10px] sm:text-xs whitespace-nowrap">
            <i class="fa-solid fa-hard-drive text-cyan-400 text-[9px] sm:text-[11px]"></i>
            <span class="font-bold text-white"><?php echo $apkSizeMB; ?></span>
          </div>
          <div class="glass rounded-full px-2.5 py-1 flex items-center gap-1 text-[10px] sm:text-xs whitespace-nowrap">
            <i class="fa-solid fa-clock text-purple-400 text-[9px] sm:text-[11px]"></i>
            <span class="font-bold text-white"><?php echo date('M j'); ?></span>
          </div>
        </div>

        <!-- Status Area -->
        <div id="status-area"
          class="h-20 flex flex-col items-center justify-center transition-all duration-300 opacity-0 pointer-events-none">
          <div id="timer-box" class="hidden flex-col items-center gap-2">
            <div class="w-8 h-8 border-4 border-white/10 border-t-emerald-500 rounded-full animate-spin"></div>
            <p class="text-sm text-white/50 font-medium"><span id="countdown-prefix">Downloading in</span> <span
                id="countdown" class="text-white font-bold">5</span><span id="countdown-suffix">s...</span></p>
          </div>
          <div id="success-msg" class="hidden flex-col items-center gap-1 text-center">
            <div class="text-emerald-400 font-medium flex items-center gap-2">
              <i class="fa-solid fa-circle-check"></i>
              <span id="started-text">Downloading started...</span>
            </div>
            <p class="text-xs text-white/30 mt-1">
              <span id="direct-prefix">If download doesn't start automatically,</span><br>
              <a href="#" id="direct-link" class="text-emerald-400 hover:underline font-medium"><span
                  id="direct-link-text">click here for direct link</span></a>
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== BENEFITS ===== -->
    <section class="py-16 sm:py-20 px-4">
      <div class="max-w-6xl mx-auto">
        <h2 id="benefits-title" class="text-2xl sm:text-3xl font-bold text-white text-center mb-10 animate-fade-up">Why
          Choose Wabees?</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <div class="benefit-card glass-stronger rounded-2xl p-6 animate-fade-up">
            <div class="icon-box w-12 h-12 rounded-xl bg-emerald-500/10 flex items-center justify-center mb-4">
              <i class="fa-solid fa-robot text-xl text-emerald-400"></i>
            </div>
            <h3 id="b1-title" class="font-semibold text-white text-lg mb-2">Smart Automations</h3>
            <p id="b1-sub" class="text-sm text-white/40 leading-relaxed">Auto-replies, keyword bots, and templates to
              save time and boost conversions.</p>
          </div>
          <div class="benefit-card glass-stronger rounded-2xl p-6 animate-fade-up-d1">
            <div class="icon-box w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center mb-4">
              <i class="fa-solid fa-bullhorn text-xl text-blue-400"></i>
            </div>
            <h3 id="b2-title" class="font-semibold text-white text-lg mb-2">Campaign Manager</h3>
            <p id="b2-sub" class="text-sm text-white/40 leading-relaxed">Send targeted broadcasts with delivery and read
              insights.</p>
          </div>
          <div class="benefit-card glass-stronger rounded-2xl p-6 animate-fade-up-d2">
            <div class="icon-box w-12 h-12 rounded-xl bg-orange-500/10 flex items-center justify-center mb-4">
              <i class="fa-solid fa-shield-halved text-xl text-orange-400"></i>
            </div>
            <h3 id="b3-title" class="font-semibold text-white text-lg mb-2">Anti‑ban Safety</h3>
            <p id="b3-sub" class="text-sm text-white/40 leading-relaxed">Built‑in limits and safe‑send patterns to keep
              your number healthy.</p>
          </div>
          <div class="benefit-card glass-stronger rounded-2xl p-6 animate-fade-up-d3">
            <div class="icon-box w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center mb-4">
              <i class="fa-solid fa-chart-line text-xl text-purple-400"></i>
            </div>
            <h3 id="b4-title" class="font-semibold text-white text-lg mb-2">Analytics</h3>
            <p id="b4-sub" class="text-sm text-white/40 leading-relaxed">Track usage, messaging limits and growth in
              real time.</p>
          </div>
          <div class="benefit-card glass-stronger rounded-2xl p-6 animate-fade-up-d4">
            <div class="icon-box w-12 h-12 rounded-xl bg-pink-500/10 flex items-center justify-center mb-4">
              <i class="fa-solid fa-headset text-xl text-pink-400"></i>
            </div>
            <h3 id="b5-title" class="font-semibold text-white text-lg mb-2">Priority Support</h3>
            <p id="b5-sub" class="text-sm text-white/40 leading-relaxed">In‑app support chat for quick help and plan
              approvals.</p>
          </div>
          <div class="benefit-card glass-stronger rounded-2xl p-6 animate-fade-up-d4">
            <div class="icon-box w-12 h-12 rounded-xl bg-cyan-500/10 flex items-center justify-center mb-4">
              <i class="fa-solid fa-lock text-xl text-cyan-400"></i>
            </div>
            <h3 id="b6-title" class="font-semibold text-white text-lg mb-2">Secure by Design</h3>
            <p id="b6-sub" class="text-sm text-white/40 leading-relaxed">No direct file links; downloads stream via
              secure endpoint.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== SCREENSHOTS ===== -->
    <section class="py-16 sm:py-20 px-4"
      style="background: radial-gradient(ellipse at 50% 50%, rgba(18,140,126,0.06) 0%, transparent 60%);">
      <div class="max-w-6xl mx-auto">
        <div class="flex items-center justify-between mb-6">
          <h2 id="screenshots-title" class="text-2xl sm:text-3xl font-bold text-white">Screenshots</h2>
          <div class="flex items-center gap-2">
            <button id="prevBtn" class="p-2.5 rounded-xl glass hover:bg-white/10 transition" aria-label="Previous">
              <i class="fa-solid fa-chevron-left text-white/60"></i>
            </button>
            <button id="nextBtn" class="p-2.5 rounded-xl glass hover:bg-white/10 transition" aria-label="Next">
              <i class="fa-solid fa-chevron-right text-white/60"></i>
            </button>
          </div>
        </div>
        <div class="relative overflow-hidden rounded-2xl glass-stronger">
          <div id="sliderTrack" class="flex transition-transform duration-500 ease-out will-change-transform">
            <div class="slide p-3"><img src="<?= $ASSET_BASE ?>/screenshots/ss1.jpeg" alt="Screenshot 1" loading="lazy"
                class="slide-img block w-full h-auto rounded-xl shadow-lg cursor-zoom-in"></div>
            <div class="slide p-3"><img src="<?= $ASSET_BASE ?>/screenshots/ss2.jpeg" alt="Screenshot 2" loading="lazy"
                class="slide-img block w-full h-auto rounded-xl shadow-lg cursor-zoom-in"></div>
            <div class="slide p-3"><img src="<?= $ASSET_BASE ?>/screenshots/ss3.jpeg" alt="Screenshot 3" loading="lazy"
                class="slide-img block w-full h-auto rounded-xl shadow-lg cursor-zoom-in"></div>
            <div class="slide p-3"><img src="<?= $ASSET_BASE ?>/screenshots/ss4.jpeg" alt="Screenshot 4" loading="lazy"
                class="slide-img block w-full h-auto rounded-xl shadow-lg cursor-zoom-in"></div>
            <div class="slide p-3"><img src="<?= $ASSET_BASE ?>/screenshots/ss5.jpeg" alt="Screenshot 5" loading="lazy"
                class="slide-img block w-full h-auto rounded-xl shadow-lg cursor-zoom-in"></div>
          </div>
          <div id="dots" class="absolute bottom-4 left-0 right-0 flex justify-center gap-2"></div>
        </div>
      </div>
    </section>

    <!-- Lightbox -->
    <div id="lightbox" class="fixed inset-0 z-50 hidden items-center justify-center bg-black/90">
      <button id="lightboxClose"
        class="absolute top-4 right-4 px-3 py-2 rounded-lg glass hover:bg-white/10 text-white border border-white/10">
        <i class="fa-solid fa-xmark"></i>
      </button>
      <img id="lightboxImg" src="" alt="Preview" class="max-w-[92vw] max-h-[92vh] rounded-xl shadow-2xl">
    </div>

    <!-- ===== SETUP GUIDE ===== -->
    <section class="py-16 sm:py-20 px-4">
      <div class="max-w-4xl mx-auto">
        <div class="glass-stronger rounded-3xl p-6 sm:p-10">
          <h2 id="guide-title" class="text-2xl sm:text-3xl font-bold text-white mb-2">WhatsApp Cloud API Setup Guide
          </h2>
          <p id="guide-sub" class="text-white/40 text-sm mb-8">Follow these steps to connect your WhatsApp Business API
            with Wabees.</p>

          <!-- Quick Copy Values -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
            <div class="glass rounded-xl p-4">
              <div id="label-webhook" class="text-xs uppercase tracking-wider text-emerald-400 font-semibold mb-1">
                Webhook URL</div>
              <pre
                class="text-white text-sm select-all overflow-x-auto whitespace-pre-wrap break-all">https://api.wabees.live/api/webhook.php</pre>
            </div>
            <div class="glass rounded-xl p-4">
              <div id="label-token" class="text-xs uppercase tracking-wider text-emerald-400 font-semibold mb-1">Verify
                Token</div>
              <pre class="text-white text-sm select-all overflow-x-auto">wabees_webhook_verify_2024</pre>
            </div>
          </div>

          <!-- Steps -->
          <div class="guide-steps space-y-6 pl-12" style="counter-reset: steps;">
            <div class="guide-step">
              <p id="guide-s1" class="text-white/70 text-sm mb-3">Open Meta Developer → Your App → WhatsApp →
                Configuration.</p>
              <div class="rounded-xl overflow-hidden border border-white/10 bg-white/5">
                <img src="<?= $ASSET_BASE ?>/guide/step1.png" alt="Step 1" loading="lazy" class="block w-full h-auto">
              </div>
            </div>
            <div class="guide-step">
              <p id="guide-s2" class="text-white/70 text-sm mb-3">Under Webhooks, set Callback URL to <code
                  class="text-emerald-400 text-xs">https://api.wabees.live/api/webhook.php</code> and Verify Token to
                <code class="text-emerald-400 text-xs">wabees_webhook_verify_2024</code>, then click Verify and Save.
              </p>
              <div class="rounded-xl overflow-hidden border border-white/10 bg-white/5">
                <img src="<?= $ASSET_BASE ?>/guide/step2.png" alt="Step 2" loading="lazy" class="block w-full h-auto">
              </div>
            </div>
            <div class="guide-step">
              <p id="guide-s3" class="text-white/70 text-sm mb-3">In Webhooks → Subscriptions, enable the <strong
                  class="text-white">messages</strong> field for your WhatsApp Business Account.</p>
              <div class="rounded-xl overflow-hidden border border-white/10 bg-white/5">
                <img src="<?= $ASSET_BASE ?>/guide/step3.jpeg" alt="Step 3" loading="lazy" class="block w-full h-auto">
              </div>
            </div>
            <div class="guide-step">
              <p id="guide-s4" class="text-white/70 text-sm mb-3">Send a test message to your connected number. You can
                also WhatsApp <strong class="text-white">+923088498449</strong> with the word <strong
                  class="text-white">HELP</strong> to see the help menu.</p>
              <div class="rounded-xl overflow-hidden border border-white/10 bg-white/5">
                <img src="<?= $ASSET_BASE ?>/guide/step4.jpeg" alt="Step 4" loading="lazy" class="block w-full h-auto">
              </div>
            </div>
          </div>

          <div id="guide-note" class="mt-8 text-xs text-white/30 glass rounded-xl p-4">
            Note: Domain has moved to <span class="text-emerald-400">wabees.live</span>. API endpoints are served from
            <span class="text-emerald-400">api.wabees.live</span>. The verify token above must match exactly in the Meta
            console.
          </div>
        </div>
      </div>
    </section>

    <!-- ===== SECURITY BADGES ===== -->
    <section class="pb-12 px-4">
      <div class="max-w-2xl mx-auto flex flex-wrap justify-center gap-6">
        <div class="flex items-center gap-2 text-white/40 text-sm">
          <i class="fa-solid fa-shield-halved text-emerald-400"></i>
          <span id="sb1">100% Secure</span>
        </div>
        <div class="flex items-center gap-2 text-white/40 text-sm">
          <i class="fa-solid fa-bolt text-yellow-400"></i>
          <span id="sb2">Fast Download</span>
        </div>
        <div class="flex items-center gap-2 text-white/40 text-sm">
          <i class="fa-solid fa-check-circle text-blue-400"></i>
          <span id="sb3">Verified</span>
        </div>
      </div>
    </section>

    <!-- ===== FOOTER ===== -->
    <footer class="border-t border-white/5 py-8 bg-black/30">
      <div class="max-w-7xl mx-auto px-4 text-white/30 text-sm">
        <div class="flex flex-col md:flex-row items-center justify-between gap-4">
          <div class="text-center md:text-left flex items-center gap-3 flex-wrap justify-center md:justify-start">
            <span>&copy; <?php echo date('Y'); ?> Wabees. All rights reserved.</span>
            <span class="visitor-badge"><span class="dot"></span><i class="fa-solid fa-eye"
                style="font-size:10px;color:rgba(255,255,255,0.3)"></i><span id="daily-visitors">â€”</span> today</span>
          </div>
          <div class="flex flex-wrap items-center justify-center md:justify-end gap-x-4 gap-y-2">
            <a href="/download/about.php" class="hover:text-white transition">About Us</a>
            <span class="text-white/10 hidden md:inline">|</span>
            <a href="/download/contact.php" class="hover:text-white transition">Contact Us</a>
            <span class="text-white/10 hidden md:inline">|</span>
            <a href="/download/privacy.php" class="hover:text-white transition">Privacy Policy</a>
            <span class="text-white/10 hidden md:inline">|</span>
            <a href="/download/terms.php" class="hover:text-white transition">Terms & Conditions</a>
            <span class="text-white/10 hidden md:inline">|</span>
            <a href="/download/data-deletion.php" class="hover:text-white transition">Data Deletion</a>
          </div>
        </div>
      </div>
    </footer>

  </div><!-- /content-layer -->

  <script>
    let isDownloading = false;

    // ===== FULL BILINGUAL i18n =====
    (function () {
      const t = {
        en: {
          heroTitle: 'Power Up Your<br><span class="gradient-text">WhatsApp Business</span>',
          heroSub: 'Automate replies, manage campaigns, and grow your business with the most powerful WhatsApp marketing tool for Android.',
          benefitsTitle: 'Why Choose Wabees?',
          screenshots: 'Screenshots',
          dl1: 'Download for', dl2: 'Android', downloads: 'Downloads',
          cdPrefix: 'Downloading in', cdSuffix: 's...',
          started: 'Downloading started...',
          directPrefix: "If download doesn't start automatically,",
          directLink: 'click here for direct link',
          guideTitle: 'WhatsApp Cloud API Setup Guide',
          guideSub: 'Follow these steps to connect your WhatsApp Business API with Wabees.',
          labelWebhook: 'Webhook URL', labelToken: 'Verify Token',
          guideS1: 'Open Meta Developer → Your App → WhatsApp → Configuration.',
          guideS2: 'Under Webhooks, set Callback URL to <code class="text-emerald-400 text-xs">https://api.wabees.live/api/webhook.php</code> and Verify Token to <code class="text-emerald-400 text-xs">wabees_webhook_verify_2024</code>, then click Verify and Save.',
          guideS3: 'In Webhooks → Subscriptions, enable the <strong class="text-white">messages</strong> field for your WhatsApp Business Account.',
          guideS4: 'Send a test message to your connected number. You can also WhatsApp <strong class="text-white">+923088498449</strong> with the word <strong class="text-white">HELP</strong> to see the help menu.',
          guideNote: 'Note: Domain has moved to <span class="text-emerald-400">wabees.live</span>. API endpoints are served from <span class="text-emerald-400">api.wabees.live</span>. The verify token above must match exactly in the Meta console.',
          benefits: [
            ['Smart Automations', 'Auto-replies, keyword bots, and templates to save time and boost conversions.'],
            ['Campaign Manager', 'Send targeted broadcasts with delivery and read insights.'],
            ['Anti‑ban Safety', 'Built‑in limits and safe‑send patterns to keep your number healthy.'],
            ['Analytics', 'Track usage, messaging limits and growth in real time.'],
            ['Priority Support', 'In‑app support chat for quick help and plan approvals.'],
            ['Secure by Design', 'No direct file links; downloads stream via secure endpoint.']
          ],
          sb: ['100% Secure', 'Fast Download', 'Verified']
        },
        ur: {
          heroTitle: 'اپنے<br><span class="gradient-text">واٹس ایپ بزنس</span> کو بہتر بنائیں',
          heroSub: 'اسمارٹ آٹو رپلائی، کی ورڈ بوٹس اور کیمپئن مینجمنٹ کے ساتھ کسٹمرز تک تیز اور مؤثر رسائی حاصل کریں۔',
          benefitsTitle: 'Wabees کیوں؟',
          screenshots: 'اسکرین شاٹس',
          dl1: 'ڈاؤن لوڈ کریں برائے', dl2: 'اینڈرائیڈ', downloads: 'ڈاؤن لوڈز',
          cdPrefix: 'ڈاؤن لوڈ شروع ہو رہا ہے', cdSuffix: ' سیکنڈ میں…',
          started: 'ڈاؤن لوڈ شروع ہوگیا…',
          directPrefix: 'اگر ڈاؤن لوڈ خودکار طور پر شروع نہ ہو تو',
          directLink: 'براہِ راست لنک کے لئے یہاں کلک کریں',
          guideTitle: 'واٹس ایپ کلاؤڈ API سیٹ اپ گائیڈ',
          guideSub: 'ان مراحل پر عمل کریں تاکہ اپنا واٹس ایپ بزنس API Wabees سے منسلک کریں۔',
          labelWebhook: 'ویب ہُک URL', labelToken: 'تصدیقی ٹوکن',
          guideS1: 'Meta Developer کھولیں ← آپ کی ایپ ← WhatsApp ← Configuration۔',
          guideS2: 'Webhooks کے تحت، Callback URL میں <code class="text-emerald-400 text-xs">https://api.wabees.live/api/webhook.php</code> لکھیں اور Verify Token میں <code class="text-emerald-400 text-xs">wabees_webhook_verify_2024</code> لکھیں، پھر Verify and Save پر کلک کریں۔',
          guideS3: 'Webhooks ← Subscriptions میں، اپنے WhatsApp Business Account کے لیے <strong class="text-white">messages</strong> فیلڈ کو فعال کریں۔',
          guideS4: 'اپنے منسلک نمبر پر ٹیسٹ میسج بھیجیں۔ آپ <strong class="text-white">+923088498449</strong> پر <strong class="text-white">HELP</strong> بھی لکھ سکتے ہیں تاکہ ہیلپ مینو دیکھ سکیں۔',
          guideNote: 'نوٹ: ڈومین <span class="text-emerald-400">wabees.live</span> پر منتقل ہو چکا ہے۔ API اینڈ پوائنٹس <span class="text-emerald-400">api.wabees.live</span> سے فراہم کیے جاتے ہیں۔ اوپر دیا گیا تصدیقی ٹوکن Meta کنسول میں بالکل ویسے ہی لگائیں۔',
          benefits: [
            ['سمارٹ آٹومیشنز', 'آٹو رپلائز، کی ورڈ بوٹس اور ٹیمپلیٹس سے وقت بچائیں اور کنورژن بہتر بنائیں۔'],
            ['کیمپئن مینیجر', 'ٹارگٹڈ براڈکاسٹس بھیجیں اور ڈیلیوری/ریڈ انسائٹس دیکھیں۔'],
            ['اینٹی بین سیفٹی', 'محفوظ بھیجنے کے پیٹرنز اور حدیں تاکہ نمبر صحت مند رہے۔'],
            ['اینالیٹکس', 'استعمال، میسجنگ حدود اور ترقی حقیقی وقت میں دیکھیں۔'],
            ['ترجیحی معاونت', 'سریع مدد اور پلان اپروول کے لئے اِن ایپ سپورٹ چیٹ۔'],
            ['محفوظ ڈیزائن', 'براہِ راست فائل لنکس کے بغیر، ڈاؤن لوڈ محفوظ اینڈ پوائنٹ سے۔']
          ],
          sb: ['100% محفوظ', 'تیز ڈاؤن لوڈ', 'تصدیق شدہ']
        }
      };
      function set(id, html) { const el = document.getElementById(id); if (el) el.innerHTML = html; }
      function applyLang(l) {
        const d = t[l] || t.en;
        set('hero-title', d.heroTitle);
        set('hero-sub', d.heroSub);
        set('benefits-title', d.benefitsTitle);
        set('screenshots-title', d.screenshots);
        set('dl-line1', d.dl1); set('dl-line2', d.dl2);
        set('downloads-label', d.downloads);
        set('countdown-prefix', d.cdPrefix);
        set('countdown-suffix', ' ' + d.cdSuffix);
        set('started-text', d.started);
        set('direct-prefix', d.directPrefix);
        set('direct-link-text', d.directLink);
        // Benefits
        for (let i = 1; i <= 6; i++) {
          set(`b${i}-title`, d.benefits[i - 1][0]);
          set(`b${i}-sub`, d.benefits[i - 1][1]);
        }
        // Security badges
        set('sb1', d.sb[0]); set('sb2', d.sb[1]); set('sb3', d.sb[2]);
        // Guide section (FULL translation)
        set('guide-title', d.guideTitle);
        set('guide-sub', d.guideSub);
        set('label-webhook', d.labelWebhook);
        set('label-token', d.labelToken);
        set('guide-s1', d.guideS1);
        set('guide-s2', d.guideS2);
        set('guide-s3', d.guideS3);
        set('guide-s4', d.guideS4);
        set('guide-note', d.guideNote);
        // RTL
        document.documentElement.setAttribute('dir', l === 'ur' ? 'rtl' : 'ltr');
        localStorage.setItem('wabees_lang_home', l);
        const ben = document.getElementById('btn-en'), bur = document.getElementById('btn-ur');
        if (ben && bur) {
          ben.classList.toggle('active', l === 'en');
          bur.classList.toggle('active', l === 'ur');
        }
      }
      window.applyLang = applyLang;
      document.addEventListener('DOMContentLoaded', () => {
        applyLang(localStorage.getItem('wabees_lang_home') || 'en');
        document.getElementById('btn-en')?.addEventListener('click', () => applyLang('en'));
        document.getElementById('btn-ur')?.addEventListener('click', () => applyLang('ur'));
      });
    })();

    // ===== SLIDER =====
    (function () {
      const track = document.getElementById('sliderTrack');
      if (!track) return;
      const slides = Array.from(track.querySelectorAll('.slide'));
      const dotsWrap = document.getElementById('dots');
      const prevBtn = document.getElementById('prevBtn');
      const nextBtn = document.getElementById('nextBtn');
      const lightbox = document.getElementById('lightbox');
      const lightboxImg = document.getElementById('lightboxImg');
      const lightboxClose = document.getElementById('lightboxClose');
      let page = 0, perView = 1, slideW = 0, pages = 1;
      function compute() {
        const container = track.parentElement;
        perView = window.innerWidth >= 1024 ? 3 : window.innerWidth >= 640 ? 2 : 1;
        slideW = Math.floor(container.clientWidth / perView);
        slides.forEach(s => { s.style.width = slideW + 'px'; s.style.flex = `0 0 ${slideW}px`; });
        pages = Math.max(1, Math.ceil(slides.length / perView));
        page = Math.min(page, pages - 1);
        update();
        if (dotsWrap) {
          dotsWrap.innerHTML = '';
          for (let i = 0; i < pages; i++) {
            const b = document.createElement('button'); b.type = 'button';
            b.className = 'w-2.5 h-2.5 rounded-full bg-white/20 transition';
            b.addEventListener('click', () => { page = i; update(); });
            dotsWrap.appendChild(b);
          }
        }
        paintDots();
      }
      function paintDots() { if (!dotsWrap) return; dotsWrap.querySelectorAll('button').forEach((b, i) => b.className = 'w-2.5 h-2.5 rounded-full transition ' + (i === page ? 'bg-emerald-400' : 'bg-white/20')); }
      function update() { track.style.transform = `translateX(-${page * slideW * perView}px)`; paintDots(); }
      prevBtn?.addEventListener('click', () => { page = (page - 1 + pages) % pages; update(); });
      nextBtn?.addEventListener('click', () => { page = (page + 1) % pages; update(); });
      window.addEventListener('resize', compute);
      track.querySelectorAll('.slide-img').forEach(img => {
        img.addEventListener('click', () => { lightboxImg.src = img.src; lightbox.classList.remove('hidden'); lightbox.classList.add('flex'); });
      });
      function closeLB() { lightbox.classList.add('hidden'); lightbox.classList.remove('flex'); lightboxImg.src = ''; }
      lightboxClose?.addEventListener('click', closeLB);
      lightbox?.addEventListener('click', e => { if (e.target === lightbox) closeLB(); });
      document.addEventListener('keydown', e => { if (e.key === 'Escape') closeLB(); });
      compute();
    })();

    // ===== DOWNLOAD =====
    function startDownloadProcess() {
      if (isDownloading) return;
      isDownloading = true;
      const btn = document.getElementById('download-btn'), statusArea = document.getElementById('status-area'),
        timerBox = document.getElementById('timer-box'), countdownEl = document.getElementById('countdown'),
        successMsg = document.getElementById('success-msg'), directLink = document.getElementById('direct-link');
      statusArea.classList.remove('opacity-0', 'pointer-events-none');
      timerBox.classList.remove('hidden'); timerBox.classList.add('flex');
      btn.classList.add('opacity-75', 'cursor-wait');
      let timeLeft = 5;
      const timer = setInterval(() => {
        timeLeft--; countdownEl.textContent = timeLeft;
        if (timeLeft <= 0) { clearInterval(timer); triggerDL(); }
      }, 1000);
      function triggerDL() {
        fetch('/download/api.php?action=track_download')
          .then(r => r.json())
          .then(data => {
            if (data.success && data.url) {
              timerBox.classList.add('hidden'); timerBox.classList.remove('flex');
              successMsg.classList.remove('hidden'); successMsg.classList.add('flex');
              directLink.href = data.url;
              window.location.href = data.url;
              const c = document.getElementById('download-count');
              c.textContent = (parseInt(c.textContent.replace(/,/g, '')) + 1).toLocaleString();
            } else { alert('Download failed. Please try again.'); isDownloading = false; }
          })
          .catch(() => { isDownloading = false; });
      }
    }

    // ===== API HEALTH =====
    (function () {
      const badge = document.getElementById('api-badge');
      if (!badge) return;
      async function ping() {
        try {
          const res = await fetch('https://api.wabees.live/health.php', { cache: 'no-store', mode: 'cors' });
          if (!res.ok) throw 0;
          const data = await res.json();
          const ok = data?.success === true;
          badge.textContent = ok ? 'API: Online' : 'API: Offline';
          badge.className = 'px-2.5 py-1 rounded-full text-[11px] border ' + (ok ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400' : 'bg-red-500/10 border-red-500/20 text-red-400');
        } catch (_) {
          badge.textContent = 'API: Offline';
          badge.className = 'px-2.5 py-1 rounded-full text-[11px] border bg-red-500/10 border-red-500/20 text-red-400';
        }
      }
      document.addEventListener('DOMContentLoaded', () => { ping(); setInterval(ping, 60000); });
    })();

    // ===== NAVBAR SCROLL =====
    (function () {
      const nav = document.querySelector('.navbar');
      window.addEventListener('scroll', () => {
        nav.classList.toggle('scrolled', window.scrollY > 50);
      });
    })();


    // ===== 3D BEE ANIMATION (Premium Stylized Golden) =====
    (function () {
      const isMobile = window.innerWidth < 768;
      const container = document.getElementById('bee-canvas');
      if (!container) return;
      const scene = new THREE.Scene();
      const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 100);
      camera.position.set(0, 0, 12);
      camera.lookAt(0, 0, 0);
      const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
      renderer.setSize(window.innerWidth, window.innerHeight);
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, isMobile ? 1.5 : 2));
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.2;
      container.appendChild(renderer.domElement);

      // Lighting
      scene.add(new THREE.AmbientLight(0x334466, 0.5));
      const keyL = new THREE.DirectionalLight(0xffeedd, 1.2);
      keyL.position.set(3, 5, 4);
      scene.add(keyL);
      const rimL = new THREE.PointLight(0x25D366, 0.8, 20);
      rimL.position.set(-3, 2, -2);
      scene.add(rimL);
      const warmL = new THREE.PointLight(0xffaa00, 0.6, 15);
      warmL.position.set(2, -1, 3);
      scene.add(warmL);

      // ===== REALISTIC BEE =====
      const bee = new THREE.Group();

      // Natural bee materials
      const yellowMat = new THREE.MeshStandardMaterial({
        color: 0xDAA520, emissive: 0x6B4C00, emissiveIntensity: 0.1,
        roughness: 0.65, metalness: 0.15
      });
      const blackMat = new THREE.MeshStandardMaterial({
        color: 0x2C1810, emissive: 0x000000, emissiveIntensity: 0.0,
        roughness: 0.7, metalness: 0.1
      });
      const brownMat = new THREE.MeshStandardMaterial({
        color: 0x8B4513, emissive: 0x3D1F00, emissiveIntensity: 0.08,
        roughness: 0.6, metalness: 0.12
      });

      // Abdomen (slim)
      const abdGeo = new THREE.SphereGeometry(1, 24, 18);
      abdGeo.scale(0.50, 0.32, 0.55);
      const abdomen = new THREE.Mesh(abdGeo, yellowMat);
      abdomen.position.set(0, 0, -0.35);
      bee.add(abdomen);

      // Black stripes on abdomen
      const sGeo = new THREE.TorusGeometry(0.32, 0.035, 8, 32);
      [-0.15, 0.0, 0.15].forEach(z => {
        const s = new THREE.Mesh(sGeo, blackMat);
        s.scale.set(0.95, 0.75, 0.35);
        s.position.set(0, 0, z - 0.35);
        bee.add(s);
      });

      // Thorax (dark brown/black — fuzzy look)
      const thorGeo = new THREE.SphereGeometry(1, 20, 16);
      thorGeo.scale(0.35, 0.32, 0.32);
      const thorax = new THREE.Mesh(thorGeo, brownMat);
      thorax.position.set(0, 0.02, 0.25);
      bee.add(thorax);

      // Thorax fuzz (tiny dark bumps for fuzzy texture)
      const fuzzMat = new THREE.MeshStandardMaterial({ color: 0x5C3A1E, roughness: 0.8, metalness: 0.05 });
      for (let i = 0; i < 12; i++) {
        const fuzz = new THREE.Mesh(new THREE.SphereGeometry(0.04, 6, 6), fuzzMat);
        const a = (i / 12) * Math.PI * 2;
        fuzz.position.set(Math.cos(a) * 0.22, Math.sin(a) * 0.2 + 0.02, 0.25 + Math.sin(a * 2) * 0.05);
        bee.add(fuzz);
      }

      // Head (dark brown like real bee)
      const headGeo = new THREE.SphereGeometry(1, 20, 16);
      headGeo.scale(0.22, 0.2, 0.22);
      const head = new THREE.Mesh(headGeo, brownMat);
      head.position.set(0, 0.04, 0.52);
      bee.add(head);

      // Eyes
      const eyeGeo = new THREE.SphereGeometry(0.12, 12, 10);
      const eyeMat = new THREE.MeshStandardMaterial({
        color: 0x220000, emissive: 0x880000, emissiveIntensity: 0.6,
        roughness: 0.05, metalness: 0.95
      });
      [[-0.12, 0.08, 0.62], [0.12, 0.08, 0.62]].forEach(p => {
        const eye = new THREE.Mesh(eyeGeo, eyeMat);
        eye.position.set(...p);
        bee.add(eye);
      });

      // Antennae
      const antMat = new THREE.MeshStandardMaterial({ color: 0x8B6914, roughness: 0.2, metalness: 0.7 });
      [-1, 1].forEach(side => {
        const antGroup = new THREE.Group();
        const seg1 = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.015, 0.2, 6), antMat);
        seg1.position.set(0, 0.1, 0);
        antGroup.add(seg1);
        const seg2 = new THREE.Mesh(new THREE.CylinderGeometry(0.008, 0.012, 0.18, 6), antMat);
        seg2.position.set(0, 0.22, 0.05);
        seg2.rotation.x = 0.5;
        antGroup.add(seg2);
        const tip = new THREE.Mesh(new THREE.SphereGeometry(0.025, 8, 6), antMat);
        tip.position.set(0, 0.3, 0.12);
        antGroup.add(tip);
        antGroup.position.set(side * 0.06, 0.12, 0.55);
        antGroup.rotation.z = side * 0.3;
        antGroup.rotation.x = -0.4;
        bee.add(antGroup);
      });

      // Wings
      const wingGeo = new THREE.BufferGeometry();
      const wv = new Float32Array([0, 0, 0, 0.6, 0.3, 0.1, 0.5, 0.6, 0.05, 0.15, 0.55, 0, 0, 0, 0, 0.5, 0.6, 0.05]);
      wingGeo.setAttribute('position', new THREE.BufferAttribute(wv, 3));
      wingGeo.computeVertexNormals();
      const wingMat = new THREE.MeshStandardMaterial({
        color: 0xccddff, transparent: true, opacity: 0.6,
        roughness: 0.1, metalness: 0.3, side: THREE.DoubleSide,
        emissive: 0x88bbff, emissiveIntensity: 0.25
      });

      const wingGroups = [];

      // Front wings
      [-1, 1].forEach(side => {
        const wg = new THREE.Group();
        const w = new THREE.Mesh(wingGeo, wingMat);
        w.scale.set(side * 1.6, 1.5, 1);
        wg.add(w);
        wg.position.set(side * 0.1, 0.15, 0.15);
        wg.userData.side = side;
        bee.add(wg);
        wingGroups.push(wg);
      });

      // Hind wings
      const hWingGeo = new THREE.BufferGeometry();
      const hwv = new Float32Array([0, 0, 0, 0.35, 0.15, 0.05, 0.3, 0.35, 0.02, 0.08, 0.3, 0, 0, 0, 0, 0.3, 0.35, 0.02]);
      hWingGeo.setAttribute('position', new THREE.BufferAttribute(hwv, 3));
      hWingGeo.computeVertexNormals();
      [-1, 1].forEach(side => {
        const wg = new THREE.Group();
        const w = new THREE.Mesh(hWingGeo, wingMat);
        w.scale.set(side * 1.3, 1.3, 1);
        wg.add(w);
        wg.position.set(side * 0.08, 0.12, -0.05);
        wg.userData.side = side;
        bee.add(wg);
        wingGroups.push(wg);
      });

      // Legs (clearly visible with joints and feet)
      const legMat = new THREE.MeshStandardMaterial({ color: 0x3D2B00, emissive: 0x1A1200, emissiveIntensity: 0.3, roughness: 0.3, metalness: 0.8 });
      const jointMat = new THREE.MeshStandardMaterial({ color: 0xCC9200, emissive: 0x664900, emissiveIntensity: 0.3, roughness: 0.15, metalness: 0.85 });
      [[-0.22, 0.22], [0, 0.28], [0.22, 0.18]].forEach(([zOff, len]) => {
        [-1, 1].forEach(side => {
          const leg = new THREE.Group();
          // Coxa (hip joint)
          const coxa = new THREE.Mesh(new THREE.SphereGeometry(0.035, 8, 8), jointMat);
          coxa.position.set(0, 0, 0);
          leg.add(coxa);
          // Femur (upper leg)
          const femur = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.025, len, 8), legMat);
          femur.position.set(0, -len / 2, 0);
          leg.add(femur);
          // Knee joint
          const knee = new THREE.Mesh(new THREE.SphereGeometry(0.03, 8, 8), jointMat);
          knee.position.set(0, -len, 0);
          leg.add(knee);
          // Tibia (lower leg)
          const tibia = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.018, len * 0.9, 8), legMat);
          tibia.position.set(0, -len - len * 0.35, 0);
          tibia.rotation.x = 0.5;
          leg.add(tibia);
          // Foot
          const foot = new THREE.Mesh(new THREE.SphereGeometry(0.022, 6, 6), legMat);
          foot.position.set(0, -len - len * 0.65, len * 0.15);
          leg.add(foot);
          leg.position.set(side * 0.2, -0.12, zOff);
          leg.rotation.z = side * 0.55;
          leg.rotation.x = 0.35;
          bee.add(leg);
        });
      });

      // Stinger
      const stinger = new THREE.Mesh(
        new THREE.ConeGeometry(0.04, 0.18, 6),
        new THREE.MeshStandardMaterial({ color: 0xCC9200, roughness: 0.15, metalness: 0.8 })
      );
      stinger.rotation.x = Math.PI / 2;
      stinger.position.set(0, -0.03, -0.72);
      bee.add(stinger);

      // Scale
      const beeScale = isMobile ? 0.38 : 0.55;
      bee.scale.set(beeScale, beeScale, beeScale);
      scene.add(bee);

      // Glow sprite
      const glowCanvas = document.createElement('canvas');
      glowCanvas.width = 64; glowCanvas.height = 64;
      const gctx = glowCanvas.getContext('2d');
      const grad = gctx.createRadialGradient(32, 32, 0, 32, 32, 32);
      grad.addColorStop(0, 'rgba(255,184,0,0.6)');
      grad.addColorStop(0.5, 'rgba(255,184,0,0.15)');
      grad.addColorStop(1, 'rgba(255,184,0,0)');
      gctx.fillStyle = grad;
      gctx.fillRect(0, 0, 64, 64);
      const glowTex = new THREE.CanvasTexture(glowCanvas);
      const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, transparent: true, opacity: 0.5 }));
      glow.scale.set(3, 3, 1);
      bee.add(glow);

      // Mouse tracking
      const mouseTarget = { x: 0, y: 0 };
      const mouseSmooth = { x: 0, y: 0 };
      window.addEventListener('mousemove', e => {
        mouseTarget.x = (e.clientX / window.innerWidth) * 2 - 1;
        mouseTarget.y = -(e.clientY / window.innerHeight) * 2 + 1;
      });

      // ===== ANIMATION WITH LANDING =====
      let time = 0;
      const currentPos = new THREE.Vector3(0, 0, 0);
      const targetPos = new THREE.Vector3(0, 0, 0);
      const velocity = new THREE.Vector3(0, 0, 0);
      const prevPos = new THREE.Vector3(0, 0, 0);
      const smoothRot = { y: 0, z: 0, x: 0 };

      // Landing state machine
      let beeState = 'flying';
      let stateTimer = 0;
      let nextFlyDuration = 12 + Math.random() * 6;
      let nextRestDuration = 4 + Math.random() * 2;

      function getWaBtnWorldPos() {
        const btn = document.querySelector('.wa-float-btn');
        if (!btn) return { x: -5, y: -4, z: 1 };
        const rect = btn.getBoundingClientRect();
        const ndcX = (rect.left + rect.width / 2) / window.innerWidth * 2 - 1;
        const ndcY = -((rect.top + rect.height / 2) / window.innerHeight * 2 - 1);
        // Proper projection: account for camera FOV and aspect ratio
        const aspect = window.innerWidth / window.innerHeight;
        const fovRad = (50 / 2) * Math.PI / 180;
        const dist = 12; // camera z position
        const halfH = Math.tan(fovRad) * dist;
        const halfW = halfH * aspect;
        return { x: ndcX * halfW, y: ndcY * halfH, z: 2 };
      }

      function animate() {
        requestAnimationFrame(animate);
        time += 0.016;
        stateTimer += 0.016;
        const t = time;

        mouseSmooth.x += (mouseTarget.x - mouseSmooth.x) * 0.03;
        mouseSmooth.y += (mouseTarget.y - mouseSmooth.y) * 0.03;

        // State transitions
        if (beeState === 'flying' && stateTimer > nextFlyDuration) {
          beeState = 'landing'; stateTimer = 0;
        } else if (beeState === 'resting' && stateTimer > nextRestDuration) {
          beeState = 'takeoff'; stateTimer = 0;
          nextFlyDuration = 12 + Math.random() * 6;
          nextRestDuration = 4 + Math.random() * 2;
        } else if (beeState === 'takeoff' && stateTimer > 1.0) {
          beeState = 'flying'; stateTimer = 0;
        }

        let wingSpeed = 45;

        if (beeState === 'flying') {
          const rangeX = isMobile ? 5.0 : 8.0;
          const rangeY = isMobile ? 3.5 : 5.0;
          const pathX = Math.sin(t * 0.4) * rangeX + Math.sin(t * 1.1) * 0.8 + Math.cos(t * 0.7) * 0.4;
          const pathY = Math.cos(t * 0.55) * rangeY + Math.sin(t * 0.85) * 0.5 + Math.cos(t * 1.3) * 0.3;
          const pathZ = Math.sin(t * 0.3) * 1.5 + Math.cos(t * 0.6) * 0.5;
          const mWorldX = mouseSmooth.x * 6;
          const mWorldY = mouseSmooth.y * 4;
          const attraction = 0.35;
          targetPos.set(pathX + (mWorldX - pathX) * attraction, pathY + (mWorldY - pathY) * attraction, pathZ);
        } else if (beeState === 'landing') {
          const waPos = getWaBtnWorldPos();
          targetPos.set(waPos.x, waPos.y + 0.3, waPos.z);
          const dist = currentPos.distanceTo(targetPos);
          wingSpeed = 25 + dist * 10;
          if (dist < 0.3) { beeState = 'resting'; stateTimer = 0; }
        } else if (beeState === 'resting') {
          const waPos = getWaBtnWorldPos();
          targetPos.set(waPos.x, waPos.y + 0.15, waPos.z);
          wingSpeed = 8;
        } else if (beeState === 'takeoff') {
          const waPos = getWaBtnWorldPos();
          const lp = Math.min(stateTimer / 1.0, 1);
          targetPos.set(waPos.x + lp * 3, waPos.y + lp * 4, waPos.z - lp);
          wingSpeed = 35 + lp * 15;
        }

        const lerpSpeed = beeState === 'landing' ? 0.04 : beeState === 'resting' ? 0.08 : 0.025;
        currentPos.lerp(targetPos, lerpSpeed);
        bee.position.copy(currentPos);

        // Rotation
        velocity.subVectors(currentPos, prevPos);
        const speed = velocity.length();

        if (beeState === 'resting') {
          smoothRot.y += (0 - smoothRot.y) * 0.05;
          smoothRot.z += (0 - smoothRot.z) * 0.08;
          smoothRot.x += (0 - smoothRot.x) * 0.08;
        } else if (speed > 0.001) {
          const targetRotY = Math.atan2(velocity.x, velocity.z);
          const targetRotZ = -velocity.x * 6;
          const targetRotX = velocity.y * 3;
          smoothRot.y += (targetRotY - smoothRot.y) * 0.05;
          smoothRot.z += (targetRotZ - smoothRot.z) * 0.05;
          smoothRot.x += (targetRotX - smoothRot.x) * 0.05;
        }
        bee.rotation.y = smoothRot.y;
        bee.rotation.z = Math.max(-0.4, Math.min(0.4, smoothRot.z));
        bee.rotation.x = Math.max(-0.25, Math.min(0.25, smoothRot.x));
        prevPos.copy(currentPos);

        // Wing flapping
        const amp = beeState === 'resting' ? 0.15 : 0.7;
        for (let i = 0; i < wingGroups.length; i++) {
          const w = wingGroups[i];
          const side = w.userData.side || 1;
          w.rotation.x = Math.sin(t * wingSpeed + side * 0.5) * amp;
        }

        // Body bob
        const bobAmp = beeState === 'resting' ? 0.005 : 0.015;
        bee.position.y += Math.sin(t * 8) * bobAmp;

        glow.material.opacity = 0.5 + Math.sin(t * 3) * 0.15;

        renderer.render(scene, camera);
      }
      animate();

      window.addEventListener('resize', () => {
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
      });
    })();

    // ===== WHATSAPP POPUP =====
    document.addEventListener('DOMContentLoaded', function () {
      const btn = document.querySelector('.wa-float-btn');
      const popup = document.getElementById('wa-popup');
      const closeBtn = document.getElementById('wa-popup-close');
      const input = document.getElementById('wa-msg-input');
      const sendBtn = document.getElementById('wa-send-btn');
      const quickMsgs = document.querySelectorAll('.wa-quick-msg');
      const phone = '923003522143';
      if (!btn || !popup) return;
      btn.addEventListener('click', () => { popup.classList.toggle('open'); });
      closeBtn?.addEventListener('click', () => { popup.classList.remove('open'); });
      quickMsgs.forEach(qm => {
        qm.addEventListener('click', () => { input.value = qm.dataset.msg; input.focus(); });
      });
      function sendMsg() {
        const msg = input.value.trim();
        if (!msg) { input.focus(); return; }
        window.open(`https://wa.me/${phone}?text=${encodeURIComponent(msg)}`, '_blank');
        input.value = ''; popup.classList.remove('open');
      }
      sendBtn?.addEventListener('click', sendMsg);
      input?.addEventListener('keydown', e => { if (e.key === 'Enter') sendMsg(); });
      document.addEventListener('click', e => {
        if (!popup.contains(e.target) && !btn.contains(e.target)) popup.classList.remove('open');
      });
    });

    // ===== DAILY VISITOR COUNTER (resets at midnight PKT) =====
    document.addEventListener('DOMContentLoaded', function () {
      const el = document.getElementById('daily-visitors');
      if (!el) return;

      // Use Pakistan time (UTC+5) for date so reset happens at midnight PKT
      const now = new Date();
      const pktOffset = 5 * 60; // UTC+5 in minutes
      const pktTime = new Date(now.getTime() + (pktOffset + now.getTimezoneOffset()) * 60000);
      const today = pktTime.toISOString().slice(0, 10);

      const visitedKey = 'wabees_visited_' + today;
      const isNewVisit = !localStorage.getItem(visitedKey);

      // Show 1 minimum while loading
      el.textContent = '1';

      // Clean old localStorage keys (previous days)
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith('wabees_visited_') && key !== visitedKey) {
          localStorage.removeItem(key);
        }
      }

      // Call server API (tracks unique daily visits)
      fetch('/download/api.php?action=visitor_count&date=' + today + (isNewVisit ? '&new=1' : ''))
        .then(r => r.json())
        .then(d => {
          if (isNewVisit) localStorage.setItem(visitedKey, '1');
          const realCount = parseInt(d.count) || 1;
          el.textContent = Math.max(1, realCount).toLocaleString();
        })
        .catch(() => {
          el.textContent = '1';
        });
    });
  </script>

  <!-- ===== WHATSAPP FLOATING BUTTON + POPUP ===== -->
  <div id="wa-popup" class="wa-popup">
    <div class="wa-popup-header">
      <div class="wa-popup-avatar">W</div>
      <div class="wa-popup-header-info">
        <h4>Wabees Support</h4>
        <p>Usually replies within minutes</p>
      </div>
      <button id="wa-popup-close" class="wa-popup-close"><i class="fa-solid fa-xmark"></i></button>
    </div>
    <div class="wa-popup-body">
      <div class="welcome-msg">
        &#x1F44B; Hi! How can we help you today? Send us a message or pick a quick option below.
      </div>
      <div class="wa-quick-msgs">
        <button class="wa-quick-msg" data-msg="I want to know about Wabees pricing">&#x1F4B0; Pricing</button>
        <button class="wa-quick-msg" data-msg="I need help setting up Wabees">&#x1F527; Setup Help</button>
        <button class="wa-quick-msg" data-msg="I'm facing an issue with the app">&#x1F41B; Report Issue</button>
        <button class="wa-quick-msg" data-msg="I want to buy Wabees premium plan">&#x2B50; Buy Premium</button>
        <button class="wa-quick-msg" data-msg="How do I connect WhatsApp Cloud API?">&#x1F517; API Setup</button>
        <button class="wa-quick-msg" data-msg="I have a custom request">&#x1F4AC; Custom Request</button>
      </div>
      <div class="wa-input-row">
        <input type="text" id="wa-msg-input" placeholder="Type your message..." autocomplete="off">
        <button id="wa-send-btn" class="wa-send-btn"><i class="fa-solid fa-paper-plane"></i></button>
      </div>
    </div>
  </div>
  <button class="wa-float-btn" aria-label="WhatsApp Support">
    <i class="fa-brands fa-whatsapp"></i>
  </button>

</body>

</html>