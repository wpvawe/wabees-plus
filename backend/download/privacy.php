<?php
$title = 'Privacy Policy — Wabees';
?>
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

    .card {
      background: #fff;
      border: 1px solid #e5e7eb;
      border-radius: 12px;
      padding: 1rem
    }

    .kbd {
      background: #f1f5f9;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: .1rem .4rem;
      font-size: .85em
    }

    .lang-toggle .active {
      background: #059669;
      color: #fff
    }

    [dir="rtl"] .prose ul {
      padding-right: 1rem
    }

    [dir="rtl"] .prose ol {
      padding-right: 1rem
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
  <div class="max-w-3xl mx-auto px-4 mt-4 flex justify-end lang-toggle gap-2">
    <button id="btn-en" class="px-3 py-1 rounded border border-slate-300">English</button>
    <button id="btn-ur" class="px-3 py-1 rounded border border-slate-300">اردو</button>
  </div>
  <main class="max-w-3xl mx-auto px-4 py-6">
    <section class="prose prose-slate lang-en">
      <h1>Privacy Policy</h1>
      <p><strong>Effective Date:</strong> <?= $today ?> &nbsp; <strong>Last Updated:</strong> <?= $today ?></p>

      <p>Thank you for choosing <strong>Wabees</strong>. We build WhatsApp‑first customer communication tools —
        including smart auto‑replies, keyword bots, campaign broadcasts, and support chat — to help small businesses
        talk to customers faster and better. This Privacy Policy explains what information we collect, why we collect
        it, how we use it, and the choices you have. It applies to our website, Android app, APIs, and any related pages
        hosted under <span class="kbd">wabees.live</span>.</p>

      <h2>1) What We Collect</h2>
      <div class="card">
        <h3>Account & Business Profile</h3>
        <ul>
          <li>Owner contact details (name, email, phone)</li>
          <li>Business details (brand name, optional logo URL)</li>
          <li>Authentication metadata (UIDs, tokens, timestamp)</li>
        </ul>
        <h3>Messaging & Usage</h3>
        <ul>
          <li>Conversation summaries (contact number, last message time, unread counts)</li>
          <li>Message metadata (direction, status, timestamps, media types)</li>
          <li>WhatsApp connection configuration (phone number ID, access token you supply)</li>
        </ul>
        <h3>Bot & Campaign Content</h3>
        <ul>
          <li>Bot names, triggers, quick‑reply button text, CTA titles/links</li>
          <li>Campaign names, audiences, delivery metrics (sent, delivered, read)</li>
        </ul>
        <h3>Device & Diagnostics</h3>
        <ul>
          <li>Device model, OS version, app version</li>
          <li>IP address and standard server logs</li>
          <li>Crash reports and performance telemetry (to fix bugs and improve reliability)</li>
        </ul>
      </div>

      <h2>2) How We Use Your Information</h2>
      <ol>
        <li><strong>Core features:</strong> deliver messages, trigger bots, run broadcasts, and show analytics you
          explicitly request.</li>
        <li><strong>Security:</strong> detect abuse, rate‑limit suspicious activity, safeguard accounts, and prevent
          spam.</li>
        <li><strong>Improvements:</strong> analyze anonymized usage patterns to make sending faster and safer.</li>
        <li><strong>Support:</strong> help you diagnose delivery issues and answer queries via in‑app support.</li>
        <li><strong>Compliance:</strong> respect WhatsApp Platform policies and applicable local laws.</li>
      </ol>
      <p>We do <strong>not</strong> sell your personal information. We only share what is necessary to operate the
        service (for example with Firebase and WhatsApp Cloud API as your chosen processors).</p>

      <h2>3) Legal Grounds & Consent</h2>
      <p>We process data based on your <strong>consent</strong> (when you connect WhatsApp or create bots),
        <strong>contractual necessity</strong> (to provide the service you signed up for), and <strong>legitimate
          interests</strong> (to keep systems secure and reliable). Where required, we will ask for explicit consent and
        allow you to revoke it at any time.</p>

      <h2>4) Data You Choose to Connect</h2>
      <p>When you connect your <strong>WhatsApp Cloud API</strong> credentials, you instruct Wabees to send messages on
        your behalf. We store the phone number ID and access token you provide in your secure project area to deliver
        your messages. You can revoke or rotate these tokens at any time from Meta Developer settings; doing so
        immediately disables new sends until you reconnect.</p>

      <h2>5) Retention & Deletion</h2>
      <ul>
        <li><strong>Messages:</strong> Stored for your own history and analytics. You can delete conversations,
          individual messages, or your full account data.</li>
        <li><strong>Logs:</strong> Minimal server logs are retained for security and troubleshooting for a limited
          period.</li>
        <li><strong>Backups:</strong> Point‑in‑time backups exist for disaster recovery and are cycled regularly.</li>
      </ul>
      <p>To request permanent deletion of your data, use the in‑app option or email <a
          href="mailto:info@wabees.live">info@wabees.live</a>. We will confirm and process deletions except where law
        requires retention (e.g., fraud investigations).</p>

      <h2>6) Your Rights</h2>
      <ul>
        <li>Access the data we hold about you</li>
        <li>Request corrections of inaccurate information</li>
        <li>Export your data in a portable format</li>
        <li>Object to or restrict certain processing</li>
        <li>Request deletion, subject to lawful exceptions</li>
      </ul>
      <p>We aim to respond to verified requests within 7 working days.</p>

      <h2>7) Security Practices</h2>
      <ul>
        <li>Transport encryption (HTTPS) for all network traffic</li>
        <li>Scoped access controls and audit trails</li>
        <li>Token‑based authentication with optional session invalidation</li>
        <li>Defense‑in‑depth around project credentials you provide</li>
      </ul>
      <p>No platform is 100% immune to risk. You can help protect your account by keeping tokens secret, using trusted
        devices, and rotating credentials periodically.</p>

      <h2>8) Cookies & Similar Technologies</h2>
      <p>We use minimal cookies for session continuity, analytics, and CSRF protection on the website. You may disable
        cookies in your browser; some features may not function as expected.</p>

      <h2>9) Third‑Party Services</h2>
      <ul>
        <li><strong>Firebase</strong> for authentication, real‑time data, and storage</li>
        <li><strong>WhatsApp Cloud API</strong> for message delivery per your credentials</li>
        <li><strong>Hosting</strong> (e.g., Hostinger) for secure API endpoints and static assets</li>
      </ul>
      <p>These providers act as processors under their own privacy terms. We share only what is necessary to run Wabees.
      </p>

      <h2>10) Children’s Privacy</h2>
      <p>Wabees is intended for business use by individuals aged 18+. We do not knowingly collect data from children.
      </p>

      <h2>11) Changes to This Policy</h2>
      <p>We may update this policy to reflect changes in technology or regulations. We will post updates here with a new
        “Last Updated” date and, where material, notify you in‑app.</p>

      <h2>12) Contact</h2>
      <p>Email: <a href="mailto:info@wabees.live">info@wabees.live</a><br>Website: <a
          href="https://www.wabees.live">www.wabees.live</a></p>
      <p><a class="no-underline" href="/">&larr; Back to Download</a></p>
    </section>

    <section class="prose prose-slate lang-ur" dir="rtl" style="display:none">
      <h1>رازداری پالیسی</h1>
      <p><strong>موثر تاریخ:</strong> <?= $today ?> &nbsp; <strong>آخری اپڈیٹ:</strong> <?= $today ?></p>
      <p><strong>Wabees</strong> ایک WhatsApp‑اول کسٹمر کمیونیکیشن پلیٹ فارم ہے جو سمارٹ آٹو رپلائی، کی ورڈ بوٹس، کیمپئن
        براڈکاسٹس اور سپورٹ چیٹ جیسی سہولیات فراہم کرتا ہے۔ یہ پالیسی بتاتی ہے کہ ہم کونسی معلومات اکٹھی کرتے ہیں، کیوں
        کرتے ہیں، کیسے استعمال کرتے ہیں، اور آپ کے کیا اختیارات ہیں۔ یہ پالیسی ہماری ویب سائٹ، اینڈرائیڈ ایپ، APIs اور
        <span class="kbd">wabees.live</span> کے تحت آنے والے صفحات پر لاگو ہے۔</p>

      <h2>۱) ہم کون سی معلومات جمع کرتے ہیں</h2>
      <ul>
        <li><strong>اکاؤنٹ اور بزنس پروفائل:</strong> نام، ای میل، فون، برانڈ نیم، لوگو یو آر ایل، تصدیقی میٹا ڈیٹا</li>
        <li><strong>میسجنگ اور استعمال:</strong> گفتگو کا خلاصہ، میسج میٹا ڈیٹا (ڈائریکشن، اسٹیٹس، ٹائم اسٹیمپ)،
          WhatsApp کنکشن کنفیگریشن</li>
        <li><strong>بوٹس اور کیمپئن:</strong> بوٹ نام، ٹرگرز، کوئک رپلائی بٹن متن، CTA ٹائٹلز/لنکس، آڈیئنس اور ڈلیوری
          میٹرکس</li>
        <li><strong>ڈیوائس اور ڈائیگناسٹکس:</strong> ڈیوائس ماڈل، او ایس ورژن، ایپ ورژن، آئی پی، لاگز، کریش رپورٹس</li>
      </ul>

      <h2>۲) معلومات کا استعمال</h2>
      <ol>
        <li><strong>بنیادی فیچرز:</strong> میسج ڈیلیوری، بوٹ ٹرگرز، براڈکاسٹس، اینالیٹکس</li>
        <li><strong>سکیورٹی:</strong> غلط استعمال کی نشاندہی، ریٹ‑لمٹنگ، اکاؤنٹ سیفٹی</li>
        <li><strong>بہتری:</strong> گمنام استعمال کے پیٹرنز سے کارکردگی میں اضافہ</li>
        <li><strong>سپورٹ:</strong> ڈیلیوری مسائل کی ڈائیگنوسس اور رہنمائی</li>
        <li><strong>تعمیل:</strong> WhatsApp پالیسیز اور مقامی قوانین کی پابندی</li>
      </ol>
      <p>ہم آپ کا ذاتی ڈیٹا فروخت نہیں کرتے۔ صرف ضروری معلومات پروسیسرز (Firebase، WhatsApp Cloud API) کے ساتھ شیئر کی
        جاتی ہے تاکہ سروس چل سکے۔</p>

      <h2>۳) قانونی بنیاد اور رضامندی</h2>
      <p>ہم آپ کی رضامندی، معاہداتی ضرورت اور جائز مفاد کی بنیاد پر ڈیٹا پروسیس کرتے ہیں۔ جہاں ضروری ہو واضح رضامندی لی
        جاتی ہے اور آپ اسے واپس لے سکتے ہیں۔</p>

      <h2>۴) کنکشن ڈیٹا</h2>
      <p>جب آپ WhatsApp Cloud API اسناد فراہم کرتے ہیں تو آپ Wabees کو اپنی طرف سے پیغامات بھیجنے کی ہدایت دیتے ہیں۔ فون
        نمبر آئی ڈی اور ایکسس ٹوکن آپ کے پروجیکٹ ایریا میں محفوظ رکھے جاتے ہیں؛ آپ کسی بھی وقت ٹوکن ریvoke/rotate کر
        سکتے ہیں۔</p>

      <h2>۵) ریٹینشن اور ڈیلیشن</h2>
      <ul>
        <li><strong>پیغامات:</strong> تاریخ اور اینالیٹکس کیلئے محفوظ۔ آپ گفتگو، پیغامات یا مکمل اکاؤنٹ حذف کر سکتے ہیں۔
        </li>
        <li><strong>لاگز:</strong> محدود مدت کیلئے سکیورٹی اور ٹربل شوٹنگ کی خاطر رکھا جاتا ہے۔</li>
        <li><strong>بیک اپس:</strong> ڈزاسٹر ریکوری کیلئے پوائنٹ‑ان‑ٹائم بیک اپس موجود ہوتے ہیں اور باقاعدگی سے گھمائے
          جاتے ہیں۔</li>
      </ul>
      <p>مستقل حذف کیلئے ایپ کے ذریعے یا <a href="mailto:info@wabees.live">info@wabees.live</a> پر درخواست دیں۔ قانونی
        تقاضوں کی صورت میں کچھ ریکارڈ برقرار رہ سکتے ہیں۔</p>

      <h2>۶) آپ کے حقوق</h2>
      <ul>
        <li>اپنا ڈیٹا دیکھنے اور درستگی کی درخواست</li>
        <li>ڈیٹا ایکسپورٹ</li>
        <li>کچھ پروسیسنگ پر اعتراض/حد بندی</li>
        <li>حذف کی درخواست (قانونی استثناؤں کے ساتھ)</li>
      </ul>

      <h2>۷) سکیورٹی</h2>
      <ul>
        <li>HTTPS اینکرپشن</li>
        <li>اسکوپڈ ایکسس کنٹرولز اور آڈٹ ٹریلز</li>
        <li>ٹوکن بیسڈ آتھنٹیکیشن</li>
        <li>کریڈینشلز کیلئے ڈیفنس‑ان‑ڈیپتھ</li>
      </ul>

      <h2>۸) کوکیز</h2>
      <p>سیشن، اینالیٹکس اور CSRF سکیورٹی کیلئے کم سے کم کوکیز استعمال کی جاتی ہیں۔</p>

      <h2>۹) تھرڈ پارٹی سروسز</h2>
      <p>Firebase، WhatsApp Cloud API اور ہوسٹنگ پرووائیڈرز اپنی شرائط کے تحت پروسیسرز کے طور پر کام کرتے ہیں۔</p>

      <h2>۱۰) بچوں کی رازداری</h2>
      <p>Wabees صرف بالغ کاروباری صارفین کیلئے ہے۔ بچوں کا ڈیٹا دانستہ طور پر جمع نہیں کیا جاتا۔</p>

      <h2>۱۱) تبدیلیاں</h2>
      <p>پالیسی میں تبدیلیاں یہاں شائع کی جائیں گی اور ضرورت پڑنے پر ایپ میں اطلاع دی جائے گی۔</p>

      <h2>۱۲) رابطہ</h2>
      <p>ای میل: <a href="mailto:info@wabees.live">info@wabees.live</a><br>ویب سائٹ: <a
          href="https://www.wabees.live">www.wabees.live</a></p>
      <p><a class="no-underline" href="/">← ڈاؤن لوڈ صفحہ پر واپسی</a></p>
    </section>
</body>
<script>
  function setLang(l) {
    document.querySelectorAll('.lang-en').forEach(e => e.style.display = l === 'en' ? 'block' : 'none');
    document.querySelectorAll('.lang-ur').forEach(e => e.style.display = l === 'ur' ? 'block' : 'none');
    document.getElementById('btn-en').classList.toggle('active', l === 'en');
    document.getElementById('btn-ur').classList.toggle('active', l === 'ur');
    document.documentElement.setAttribute('dir', l === 'ur' ? 'rtl' : 'ltr');
    localStorage.setItem('wabees_lang', l);
  }
  document.getElementById('btn-en').addEventListener('click', () => setLang('en'));
  document.getElementById('btn-ur').addEventListener('click', () => setLang('ur'));
  setLang(localStorage.getItem('wabees_lang') || 'en');
</script>

</html>

</html>