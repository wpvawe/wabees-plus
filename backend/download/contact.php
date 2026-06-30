<?php $title = 'Contact Wabees';
$today = date('d-m-Y'); ?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?= $title ?></title>
  <link rel="icon" type="image/png" href="assets/images/app_icon.png">
  <?php if (file_exists(__DIR__ . '/assets/css/tailwind.css')): ?>
    <link href="assets/css/tailwind.css" rel="stylesheet">
  <?php else: ?>
    <script src="https://cdn.tailwindcss.com"></script>
  <?php endif; ?>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
    .lang-toggle .active {
      background: #059669;
      color: #fff
    }

    .prose h2 {
      margin-top: 1.5rem
    }
  </style>
</head>

<body class="bg-slate-50 text-slate-800">
  <header class="bg-slate-900 text-white text-xs">
    <div class="max-w-5xl mx-auto px-4 py-2 flex flex-col sm:flex-row items-center justify-between gap-2">
      <div class="flex items-center gap-2"><i class="fa-solid fa-location-dot text-green-400"></i><span>Office # 432,
          Mall of Islamabad, Blue Area, Islamabad 44000</span></div>
      <a href="tel:03088498449" class="hover:underline flex items-center gap-2"><i
          class="fa-solid fa-phone text-green-400"></i>0308‑8498449</a>
    </div>
  </header>
  <div class="max-w-3xl mx-auto px-4 mt-4 flex justify-end gap-2 lang-toggle">
    <button id="btn-en" class="px-3 py-1 rounded border border-slate-300 text-xs">English</button>
    <button id="btn-ur" class="px-3 py-1 rounded border border-slate-300 text-xs">اردو</button>
  </div>
  <main class="max-w-3xl mx-auto px-4 py-8">
    <section class="prose prose-slate lang-en">
      <h1>Contact Us</h1>
      <p><strong>Support Hours:</strong> Mon–Sat, 10:00–18:00 (PKT)</p>
      <ul>
        <li><strong>Phone:</strong> <a href="tel:03088498449">0308‑8498449</a></li>
        <li><strong>Email:</strong> <a href="mailto:info@wabees.live">info@wabees.live</a></li>
        <li><strong>Office:</strong> Office # 432, Mall of Islamabad, Blue Area, Islamabad 44000</li>
      </ul>
      <h2>Get Help Faster</h2>
      <ol>
        <li>Open the app → Support → Start a chat</li>
        <li>Share your WhatsApp Phone Number ID (if connection issue)</li>
        <li>Add a short video or screenshot if possible</li>
      </ol>
      <p><a class="no-underline" href="/">&larr; Back to Home</a></p>
    </section>
    <section class="prose prose-slate lang-ur" dir="rtl" style="display:none">
      <h1>رابطہ کریں</h1>
      <p><strong>سپورٹ اوقات:</strong> پیر–ہفتہ، 10:00–18:00 (PKT)</p>
      <ul>
        <li><strong>فون:</strong> <a href="tel:03088498449">0308‑8498449</a></li>
        <li><strong>ای میل:</strong> <a href="mailto:info@wabees.live">info@wabees.live</a></li>
        <li><strong>دفتر:</strong> آفس # 432، مال آف اسلام آباد، بلیو ایریا، اسلام آباد 44000</li>
      </ul>
      <h2>فوری مدد حاصل کریں</h2>
      <ol>
        <li>ایپ کھولیں → سپورٹ → چیٹ شروع کریں</li>
        <li>WhatsApp فون نمبر آئی ڈی شیئر کریں (اگر کنکشن کا مسئلہ ہو)</li>
        <li>ممکن ہو تو مختصر ویڈیو یا اسکرین شاٹ شامل کریں</li>
      </ol>
      <p><a class="no-underline" href="/">← ہوم پر واپسی</a></p>
    </section>
  </main>
  <script>
    function setLang(l) { document.querySelectorAll('.lang-en').forEach(e => e.style.display = l === 'en' ? 'block' : 'none'); document.querySelectorAll('.lang-ur').forEach(e => e.style.display = l === 'ur' ? 'block' : 'none'); document.documentElement.setAttribute('dir', l === 'ur' ? 'rtl' : 'ltr'); localStorage.setItem('wabees_lang_contact', l); document.getElementById('btn-en').classList.toggle('active', l === 'en'); document.getElementById('btn-ur').classList.toggle('active', l === 'ur'); }
    document.addEventListener('DOMContentLoaded', () => { const l = localStorage.getItem('wabees_lang_contact') || 'en'; setLang(l); document.getElementById('btn-en').onclick = () => setLang('en'); document.getElementById('btn-ur').onclick = () => setLang('ur'); });
  </script>
</body>

</html>