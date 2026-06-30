<?php $title = 'Data Deletion Policy — Wabees'; ?>
<?php $today = date('d-m-Y'); ?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?= $title ?></title>
  <link rel="icon" type="image/png" href="assets/images/app_icon.png">
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
    .prose h2 {
      margin-top: 1.5rem
    }

    .step {
      display: flex;
      gap: .75rem;
      margin: .5rem 0
    }

    .step .num {
      background: #0ea5e9;
      color: #fff;
      border-radius: 999px;
      width: 24px;
      height: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: .85rem
    }

    .lang-toggle .active {
      background: #059669;
      color: #fff
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
      <h1>Data Deletion Policy</h1>
      <p><strong>Effective Date:</strong> <?= $today ?> &nbsp; <strong>Last Updated:</strong> <?= $today ?></p>
      <p>We respect your right to control your data. This policy explains what can be deleted, how to request deletion,
        how long it takes, and what exceptions may apply. It applies to all data processed through Wabees (website, app,
        and APIs).</p>

      <h2>What You Can Delete</h2>
      <ul>
        <li><strong>Messages & Conversations:</strong> Delete individual messages or entire threads from within the app.
        </li>
        <li><strong>Bots & Campaigns:</strong> Remove bot definitions, quick‑reply texts, and campaign configurations.
        </li>
        <li><strong>Contacts:</strong> Remove customer profiles and tags you created in Wabees.</li>
        <li><strong>Account Data:</strong> Request full account deletion (see steps below).</li>
      </ul>
      <p>Note: Deleting content in Wabees does not recall messages already delivered to recipients’ devices via
        WhatsApp.</p>

      <h2>How to Request Full Account Deletion</h2>
      <div class="step">
        <div class="num">1</div>
        <div>Open the app and use <strong>Profile → Delete Account</strong>, or email us from your registered email
          address.</div>
      </div>
      <div class="step">
        <div class="num">2</div>
        <div>Email subject: <em>“Delete My Wabees Account”</em> to <a
            href="mailto:info@wabees.live">info@wabees.live</a> and include your registered phone and UID (if
          available).</div>
      </div>
      <div class="step">
        <div class="num">3</div>
        <div>We will verify ownership and confirm the request. After verification, the deletion workflow begins.</div>
      </div>

      <h2>Deletion Timeline</h2>
      <ul>
        <li><strong>Verification:</strong> 1–3 working days</li>
        <li><strong>Primary data purge:</strong> Within 7 working days after verification</li>
        <li><strong>Backups:</strong> Rolling backups are automatically purged on their normal cycle</li>
      </ul>

      <h2>What We Delete</h2>
      <ul>
        <li>Account profile and identifiers stored in our databases</li>
        <li>Conversations, messages, and media URLs stored by Wabees</li>
        <li>Bots, campaigns, and analytics linked solely to your account</li>
      </ul>

      <h2>What May Be Retained</h2>
      <ul>
        <li>Minimal security logs required for fraud prevention or auditing</li>
        <li>Records required by law or to resolve open disputes</li>
        <li>Content already delivered to WhatsApp recipients (outside our control)</li>
      </ul>

      <h2>Data in Backups</h2>
      <p>Backups are encrypted and used only for disaster recovery. Deleted data will no longer be available for
        production use and will disappear automatically from backups as they expire.</p>

      <h2>Third‑Party Dependencies</h2>
      <p>When you connect WhatsApp Cloud API, some operational records live on Meta’s infrastructure. Revoking your
        tokens in Meta Developer settings stops all new delivery immediately. Our deletion process removes your data
        from Wabees; you may also contact Meta to manage data on their side according to their policies.</p>

      <h2>Contact</h2>
      <p>Email: <a href="mailto:info@wabees.live">info@wabees.live</a><br>Website: <a
          href="https://www.wabees.live">https://www.wabees.live</a></p>
      <h2>Data Retention</h2>
      <p>User records are kept only as long as required for legal, auditing, or operational reasons. Once no longer
        needed, all data is permanently deleted from our systems.</p>
      <h2>Automatic Deletion</h2>
      <p>Inactive accounts older than 12 months may be deleted automatically for security and compliance.</p>
      <h2>Exceptions</h2>
      <p>Certain data (like repayment records) may be retained if required by law or financial regulations.</p>
      <p><a class="no-underline" href="/">&larr; Back to Download</a></p>
    </section>
    <section class="prose prose-slate lang-ur" dir="rtl" style="display:none">
      <h1>ڈیٹا ڈیلیشن پالیسی</h1>
      <p><strong>موثر تاریخ:</strong> <?= $today ?> &nbsp; <strong>آخری اپڈیٹ:</strong> <?= $today ?></p>
      <p>ہم آپ کے ڈیٹا پر آپ کے اختیار کا احترام کرتے ہیں۔ اس پالیسی میں بتایا گیا ہے کہ Wabees میں کون سا ڈیٹا حذف کیا
        جا سکتا ہے، درخواست کیسے دی جاتی ہے، اس میں کتنا وقت لگتا ہے اور کن صورتوں میں استثنا ہو سکتا ہے۔ یہ پالیسی ویب
        سائٹ، ایپ اور APIs کے ذریعے ہونے والی تمام پروسیسنگ پر لاگو ہے۔</p>
      <h2>کیا حذف کیا جا سکتا ہے</h2>
      <ul>
        <li><strong>پیغامات اور گفتگو:</strong> ایپ سے انفرادی پیغامات یا پوری چیٹ حذف کریں۔</li>
        <li><strong>بوٹس اور کیمپئنز:</strong> بوٹ کی تعریفیں، کوئک رپلائی ٹیکسٹ اور کیمپئن کنفیگریشنز ہٹا دیں۔</li>
        <li><strong>رابطے:</strong> وہ کسٹمر پروفائلز اور ٹیگز ہٹا دیں جو آپ نے بنائے ہیں۔</li>
        <li><strong>اکاؤنٹ ڈیٹا:</strong> مکمل اکاؤنٹ ڈیلیشن کی درخواست دیں (ذیل کے مراحل دیکھیں)۔</li>
      </ul>
      <p>نوٹ: Wabees میں حذف کرنا اُن پیغامات کو واپس نہیں لیتا جو WhatsApp کے ذریعے وصول کنندگان کے ڈیوائسز تک پہنچ چکے
        ہوں۔</p>
      <h2>مکمل اکاؤنٹ حذف کرنے کا طریقہ</h2>
      <div class="step">
        <div class="num">1</div>
        <div>ایپ میں <strong>Profile → Delete Account</strong> استعمال کریں یا اپنے رجسٹرڈ ای میل پتے سے ہمیں ای میل
          کریں۔</div>
      </div>
      <div class="step">
        <div class="num">2</div>
        <div>موضوع لکھیں: <em>“Delete My Wabees Account”</em> اور <a href="mailto:info@wabees.live">info@wabees.live</a>
          پر اپنا رجسٹرڈ فون اور (ممکن ہو تو) UID بھیجیں۔</div>
      </div>
      <div class="step">
        <div class="num">3</div>
        <div>ہم ملکیت کی تصدیق کریں گے اور پھر حذف کرنے کا عمل شروع ہو جائے گا۔</div>
      </div>
      <h2>حذف کرنے کا ٹائم لائن</h2>
      <ul>
        <li><strong>تصدیق:</strong> 1–3 ورکنگ ڈیز</li>
        <li><strong>پرائمری ڈیٹا حذف:</strong> تصدیق کے بعد 7 ورکنگ ڈیز کے اندر</li>
        <li><strong>بیک اپس:</strong> رولنگ بیک اپس اپنے مقررہ چکر پر خود بخود صاف ہو جاتے ہیں</li>
      </ul>
      <h2>ہم کیا حذف کرتے ہیں</h2>
      <ul>
        <li>اکاؤنٹ پروفائل اور شناختی ریکارڈ</li>
        <li>گفتگو، پیغامات اور میڈیا یو آر ایل جو Wabees میں محفوظ ہوں</li>
        <li>بوٹس، کیمپئنز اور آپ کے اکاؤنٹ سے منسلک اینالیٹکس</li>
      </ul>
      <h2>کیا برقرار رہ سکتا ہے</h2>
      <ul>
        <li>دھوکہ دہی سے بچاؤ اور آڈٹ کیلئے کم از کم سکیورٹی لاگز</li>
        <li>قانونی تقاضوں یا جاری تنازعات کیلئے مطلوبہ ریکارڈ</li>
        <li>وہ مواد جو WhatsApp وصول کنندگان تک پہنچ چکا ہو (ہمارے اختیار سے باہر)</li>
      </ul>
      <h2>بیک اپس میں ڈیٹا</h2>
      <p>بیک اپس خفیہ ہوتے ہیں اور صرف ڈیزاسٹر ریکوری کیلئے استعمال ہوتے ہیں۔ حذف شدہ ڈیٹا پروڈکشن میں دستیاب نہیں رہتا
        اور بیک اپس سے اُن کے چکر مکمل ہونے پر خود بخود غائب ہو جاتا ہے۔</p>
      <h2>تھرڈ پارٹی انحصارات</h2>
      <p>جب آپ WhatsApp Cloud API جوڑتے ہیں تو کچھ عملی ریکارڈ Meta کے انفراسٹرکچر پر ہوتے ہیں۔ Meta Developer سیٹنگز
        میں ٹوکن ریvoke کرنے سے نئی ترسیل فوراً رک جاتی ہے۔ ہمارا حذف کرنے کا عمل Wabees سے آپ کا ڈیٹا ہٹا دیتا ہے؛ آپ
        Meta سے بھی اُن کے اصولوں کے مطابق رابطہ کر سکتے ہیں۔</p>
      <h2>رابطہ</h2>
      <p>ای میل: <a href="mailto:info@wabees.live">info@wabees.live</a><br>ویب سائٹ: <a
          href="https://www.wabees.live">https://www.wabees.live</a></p>
      <p><a class="no-underline" href="/">← ڈاؤن لوڈ صفحہ</a></p>
    </section>
  </main>
  <script>
    (function () {
      function setLang(l) {
        document.querySelectorAll('.lang-en').forEach(e => e.style.display = l === 'en' ? 'block' : 'none');
        document.querySelectorAll('.lang-ur').forEach(e => e.style.display = l === 'ur' ? 'block' : 'none');
        document.documentElement.setAttribute('dir', l === 'ur' ? 'rtl' : 'ltr');
        localStorage.setItem('wabees_lang_dd', l);
        const be = document.getElementById('btn-en'), bu = document.getElementById('btn-ur');
        if (be && bu) { be.classList.toggle('active', l === 'en'); bu.classList.toggle('active', l === 'ur'); }
      }
      document.addEventListener('DOMContentLoaded', () => {
        const l = localStorage.getItem('wabees_lang_dd') || 'en';
        setLang(l);
        const be = document.getElementById('btn-en'), bu = document.getElementById('btn-ur');
        if (be) be.addEventListener('click', () => setLang('en'));
        if (bu) bu.addEventListener('click', () => setLang('ur'));
      });
    })();
  </script>
</body>

</html>