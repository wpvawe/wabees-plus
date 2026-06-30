<?php $title = 'About Wabees';
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
      <h1>About Wabees</h1>
      <p><strong>Last Updated:</strong> <?= $today ?></p>
      <p>Wabees is a WhatsApp‑first customer communication platform built for small businesses. Our goal is simple: help
        you respond faster, sell smarter, and support better — directly where your customers chat.</p>
      <h2>What We Do</h2>
      <ul>
        <li>Smart auto‑replies and keyword bots</li>
        <li>Campaign broadcasts with delivery and read analytics</li>
        <li>Support chat with team‑ready tools</li>
        <li>Phone health and quality rating insights</li>
      </ul>
      <h2>Our Principles</h2>
      <ul>
        <li>Compliance with WhatsApp Business policies</li>
        <li>Opt‑in audiences and respectful messaging</li>
        <li>Security‑first handling of credentials and data</li>
      </ul>
      <p>Questions? Call <a href="tel:03088498449">0308‑8498449</a> or email <a
          href="mailto:info@wabees.live">info@wabees.live</a>.</p>
      <p><a class="no-underline" href="/">&larr; Back to Home</a></p>
    </section>
    <section class="prose prose-slate lang-ur" dir="rtl" style="display:none">
      <h1>ہمارے بارے میں</h1>
      <p><strong>آخری اپڈیٹ:</strong> <?= $today ?></p>
      <p>Wabees ایک WhatsApp‑اول پلیٹ فارم ہے جو چھوٹے کاروباروں کو تیز جواب، بہتر فروخت اور معیاری سپورٹ میں مدد دیتا
        ہے — وہیں جہاں گاہک بات کرتے ہیں۔</p>
      <h2>ہم کیا کرتے ہیں</h2>
      <ul>
        <li>اسمارٹ آٹو رپلائی اور کی ورڈ بوٹس</li>
        <li>کیمپئن براڈکاسٹس اور اینالیٹکس</li>
        <li>سپورٹ چیٹ اور ٹیم فیچرز</li>
        <li>فون ہیلتھ اور کوالٹی ریٹنگ انسائٹس</li>
      </ul>
      <h2>ہمارے اصول</h2>
      <ul>
        <li>WhatsApp بزنس پالیسیز کی پابندی</li>
        <li>آپٹ‑ان آڈیئنس اور باادب پیغام رسانی</li>
        <li>سکیورٹی فرسٹ کریڈنشل اور ڈیٹا ہینڈلنگ</li>
      </ul>
      <p>رابطہ: <a href="tel:03088498449">0308‑8498449</a> یا <a href="mailto:info@wabees.live">info@wabees.live</a></p>
      <p><a class="no-underline" href="/">← ہوم پر واپسی</a></p>
    </section>
  </main>
  <script>
    function setLang(l) { document.querySelectorAll('.lang-en').forEach(e => e.style.display = l === 'en' ? 'block' : 'none'); document.querySelectorAll('.lang-ur').forEach(e => e.style.display = l === 'ur' ? 'block' : 'none'); document.documentElement.setAttribute('dir', l === 'ur' ? 'rtl' : 'ltr'); localStorage.setItem('wabees_lang_about', l); document.getElementById('btn-en').classList.toggle('active', l === 'en'); document.getElementById('btn-ur').classList.toggle('active', l === 'ur'); }
    document.addEventListener('DOMContentLoaded', () => { const l = localStorage.getItem('wabees_lang_about') || 'en'; setLang(l); document.getElementById('btn-en').onclick = () => setLang('en'); document.getElementById('btn-ur').onclick = () => setLang('ur'); });
  </script>
</body>

</html>