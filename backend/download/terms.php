<?php $title = 'Terms & Conditions — Wabees'; ?>
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

    .note {
      background: #f8fafc;
      border-left: 4px solid #0ea5e9;
      padding: .75rem 1rem;
      border-radius: 8px
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
      <h1>Terms & Conditions</h1>
      <p><strong>Effective Date:</strong> <?= $today ?> &nbsp; <strong>Last Updated:</strong> <?= $today ?></p>
      <div class="note"><strong>Summary:</strong> Wabees supplies WhatsApp‑based communication software (bots,
        auto‑replies, campaigns, support chat). You are responsible for the content you send and for complying with
        Meta/WhatsApp policies and local laws. Do not use Wabees for spam, harassment or unlawful activity.</div>

      <h2>1) The Service</h2>
      <p>Wabees provides tools to automate and manage business messages over the WhatsApp Cloud API, including:</p>
      <ul>
        <li>Auto‑reply and keyword‑triggered bots with quick‑reply and CTA buttons</li>
        <li>Broadcast campaigns to opted‑in audiences with delivery/read analytics</li>
        <li>Team‑ready support chat and notifications</li>
        <li>Usage dashboards, device/quality health, and anti‑spam protections</li>
      </ul>
      <p>We are a software provider — not a telecom operator or financial institution. Message delivery depends on the
        availability and policies of WhatsApp/Meta and carriers.</p>

      <h2>2) Eligibility & Accounts</h2>
      <ul>
        <li>You must be 18+ and authorized to act for your business.</li>
        <li>You will keep account credentials and access tokens confidential.</li>
        <li>You will provide accurate information and keep it up‑to‑date.</li>
      </ul>

      <h2>3) Acceptable Use</h2>
      <p>You agree to follow WhatsApp Business and Meta platform rules. The following is strictly prohibited:</p>
      <ul>
        <li>Sending unsolicited bulk messages or cold outreach without documented opt‑in</li>
        <li>Harassment, hate speech, threats, obscenity, or any illegal content</li>
        <li>Misrepresenting your identity or spoofing sender details</li>
        <li>Phishing or attempts to collect sensitive personal data without clear consent</li>
        <li>Circumventing WhatsApp rate limits or technical restrictions</li>
      </ul>
      <p>We may rate‑limit or suspend accounts that violate this section to protect platform health and comply with
        policy.</p>

      <h2>4) Customer Data & Permissions</h2>
      <p>You control your data and content. By using Wabees you grant us a limited license to process messages, store
        configuration, and provide analytics solely to run the service you request. You are responsible for acquiring
        consent from your contacts and for honoring opt‑out requests.</p>

      <h2>5) WhatsApp Cloud API & Tokens</h2>
      <ul>
        <li>You supply your own phone number ID and access token; you can revoke them anytime in Meta’s dashboard.</li>
        <li>Revoking tokens disables sending until reconnected.</li>
        <li>You must keep tokens secure and rotate them periodically.</li>
      </ul>

      <h2>6) Fair Use & Limits</h2>
      <p>To keep delivery healthy, Wabees may apply smart pacing and limits. Examples:</p>
      <ul>
        <li>Dynamic throttling to respect WhatsApp quality tiers</li>
        <li>Delivery windows and warnings for template vs. free‑form messages</li>
        <li>Suspension of abusive flows or bots that trigger too frequently</li>
      </ul>

      <h2>7) Payment & Plans</h2>
      <p>If you upgrade to a paid plan, the plan’s features and limits apply. Fees are non‑refundable unless required by
        law. Downgrading or cancellation takes effect at the end of the current billing cycle.</p>

      <h2>8) Service Availability</h2>
      <p>We strive for high availability, but we cannot guarantee uninterrupted service. Planned maintenance or upstream
        outages (Meta, carriers, DNS) may affect delivery. We will make reasonable efforts to inform you of major
        incidents.</p>

      <h2>9) Disclaimers</h2>
      <p>Wabees provides the software “as is” without warranties of merchantability, fitness for a particular purpose,
        or non‑infringement. We do not warrant that messages will always be delivered, read, or acted upon.</p>

      <h2>10) Limitation of Liability</h2>
      <p>To the fullest extent permitted by law, Wabees and its affiliates are not liable for indirect, incidental,
        special, consequential, or punitive damages, or any loss of profits, revenues, or data. Our aggregate liability
        for claims arising out of or related to the service is limited to the amount you paid to Wabees in the 3 months
        preceding the event giving rise to the claim.</p>

      <h2>11) Indemnification</h2>
      <p>You agree to indemnify and hold Wabees harmless from claims arising from: (a) your content; (b) your breach of
        these Terms; or (c) your violation of any law or third‑party rights.</p>

      <h2>12) Suspension & Termination</h2>
      <p>We may suspend or terminate access if we detect abuse, policy violations, or technical harm. You may export
        your data and request deletion at any time via the app or by contacting support.</p>

      <h2>13) Changes to Terms</h2>
      <p>We may update these Terms from time to time. We will post changes with a new “Last Updated” date and, for
        significant changes, notify you in‑app or by email.</p>

      <h2>14) Contact</h2>
      <p>Email: <a href="mailto:info@wabees.live">info@wabees.live</a><br>Website: <a
          href="https://www.wabees.live">https://www.wabees.live</a></p>
      <p><a class="no-underline" href="/">&larr; Back to Download</a></p>
    </section>

    <section class="prose prose-slate lang-ur" dir="rtl" style="display:none">
      <h1>شرائط و ضوابط</h1>
      <p><strong>موثر تاریخ:</strong> <?= $today ?> &nbsp; <strong>آخری اپڈیٹ:</strong> <?= $today ?></p>
      <p><strong>خلاصہ:</strong> Wabees WhatsApp پر مبنی میسجنگ سافٹ ویئر فراہم کرتا ہے (بوٹس، آٹو رپلائی، کیمپئنز،
        سپورٹ چیٹ)۔ آپ بھیجے گئے مواد کے ذمہ دار ہیں اور WhatsApp/Meta پالیسیز اور مقامی قوانین کی پابندی ضروری ہے۔
        اسپیم، ہراسانی یا غیر قانونی سرگرمی ممنوع ہے۔</p>

      <h2>۱) سروس کی نوعیت</h2>
      <ul>
        <li>کی ورڈ/آٹو رپلائی بوٹس، کوئک رپلائی و CTA بٹنز</li>
        <li>آپٹ‑ان آڈیئنس کیلئے براڈکاسٹس اور ڈلیوری/ریڈ اینالیٹکس</li>
        <li>سپورٹ چیٹ، نوٹیفکیشنز اور ڈیوائس ہیلتھ</li>
      </ul>
      <p>ہم سافٹ ویئر پرووائیڈر ہیں؛ ڈیلیوری WhatsApp/Meta اور کیریئرز کی دستیابی و پالیسیز پر منحصر ہے۔</p>

      <h2>۲) اہلیت اور اکاؤنٹس</h2>
      <ul>
        <li>عمر 18+ اور کاروبار کی نمائندگی کا اختیار</li>
        <li>کریڈینشلز اور ایکسس ٹوکن کی حفاظت</li>
        <li>درست اور تازہ معلومات فراہم کرنا</li>
      </ul>

      <h2>۳) قابل قبول استعمال</h2>
      <ul>
        <li>بغیر رضامندی بلک میسجنگ ممنوع</li>
        <li>ہراسانی/نفرت انگیز/غیر قانونی مواد ممنوع</li>
        <li>شناخت میں دھوکہ دہی یا اسپوفنگ ممنوع</li>
        <li>حساس ڈیٹا بغیر اجازت جمع کرنا ممنوع</li>
        <li>WhatsApp کی حدود بائی پاس کرنا ممنوع</li>
      </ul>

      <h2>۴) کسٹمر ڈیٹا اور اجازت</h2>
      <p>آپ اپنے ڈیٹا کے مالک ہیں۔ Wabees کو محدود لائسنس دیتے ہیں تاکہ سروس چل سکے۔ آڈیئنس سے واضح رضامندی لینا اور
        ان‑سبسکرائب کا احترام آپ کی ذمہ داری ہے۔</p>

      <h2>۵) WhatsApp Cloud API اور ٹوکنز</h2>
      <ul>
        <li>فون نمبر آئی ڈی/ٹوکن آپ فراہم کرتے ہیں؛ کسی بھی وقت ریvoke کر سکتے ہیں۔</li>
        <li>ریvoke کے بعد بھیجنا بند ہو جاتا ہے جب تک دوبارہ کنیکٹ نہ کریں۔</li>
        <li>ٹوکن کو باقاعدگی سے rotate اور محفوظ رکھیں۔</li>
      </ul>

      <h2>۶) فیئر یوز اور حدود</h2>
      <p>درست ڈیلیوری کیلئے سمارٹ پیسنگ اور حدیں لاگو ہو سکتی ہیں (ڈائنامک تھروٹلنگ، ونڈوز، mis‑use پر معطلی وغیرہ)۔</p>

      <h2>۷) ادائیگی اور پلانز</h2>
      <p>ادائیگی والے پلانز کی فیچرز/حدود لاگو رہیں گی۔ قانونی تقاضوں کے سوا فیس واپسی نہیں۔ ڈاؤن گریڈ یا کینسل اگلے
        بلنگ سائیکل پر مؤثر ہوگا۔</p>

      <h2>۸) دستیابی</h2>
      <p>ہم اعلیٰ دستیابی کی کوشش کرتے ہیں مگر مسلسل آپریشن کی ضمانت نہیں۔ اپ اسٹریم آؤٹیجز اثر انداز ہو سکتے ہیں۔</p>

      <h2>۹) ڈسکلیمر</h2>
      <p>سروس “جوں کی توں” فراہم کی جاتی ہے؛ ہر میسج کے پہنچنے/پڑھے جانے کی ضمانت نہیں۔</p>

      <h2>۱۰) ذمہ داری کی حد</h2>
      <p>بالغ ترین قانونی حد تک بالواسطہ/نتیجہ خیز نقصانات یا منافع کے نقصان پر ذمہ داری محدود ہے؛ مجموعی ذمہ داری گزشتہ
        3 ماہ کی ادائیگی سے زیادہ نہیں۔</p>

      <h2>۱۱) اندیمنفیکیشن</h2>
      <p>آپ اپنے مواد، ان شرائط کی خلاف ورزی یا کسی قانون/حق کی خلاف ورزی سے پیدا ہونے والے دعوؤں پر Wabees کو بے ضرر
        رکھیں گے۔</p>

      <h2>۱۲) معطلی اور خاتمہ</h2>
      <p>غلط استعمال یا تکنیکی نقصان کی صورت میں سسپنشن/ٹرمنیشن ممکن ہے۔ آپ کسی بھی وقت ڈیٹا ایکسپورٹ/ڈیلیٹ کی درخواست
        دے سکتے ہیں۔</p>

      <h2>۱۳) تبدیلیاں</h2>
      <p>شرائط میں وقتاً فوقتاً تبدیلی ہو سکتی ہے؛ اہم تبدیلیوں پر ایپ یا ای میل کے ذریعے اطلاع دی جائے گی۔</p>

      <h2>۱۴) رابطہ</h2>
      <p>ای میل: <a href="mailto:info@wabees.live">info@wabees.live</a><br>ویب سائٹ: <a
          href="https://www.wabees.live">https://www.wabees.live</a></p>
      <p><a class="no-underline" href="/">← ڈاؤن لوڈ صفحہ</a></p>
    </section>
  </main>
  <script>
    function setLang(l) {
      document.querySelectorAll('.lang-en').forEach(e => e.style.display = l === 'en' ? 'block' : 'none');
      document.querySelectorAll('.lang-ur').forEach(e => e.style.display = l === 'ur' ? 'block' : 'none');
      const be = document.getElementById('btn-en'), bu = document.getElementById('btn-ur');
      if (be && bu) { be.classList.toggle('active', l === 'en'); bu.classList.toggle('active', l === 'ur'); }
      document.documentElement.setAttribute('dir', l === 'ur' ? 'rtl' : 'ltr');
      localStorage.setItem('wabees_lang_terms', l);
    }
    const initLang = localStorage.getItem('wabees_lang_terms') || 'en';
    document.addEventListener('DOMContentLoaded', () => {
      const be = document.getElementById('btn-en'), bu = document.getElementById('btn-ur');
      if (be) be.addEventListener('click', () => setLang('en'));
      if (bu) bu.addEventListener('click', () => setLang('ur'));
      setLang(initLang);
    });
  </script>
</body>

</html>