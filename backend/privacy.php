<?php
header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy – WABEES</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; color: #1e293b; line-height: 1.7; padding: 24px; max-width: 800px; margin: 0 auto; }
        h1 { font-size: 28px; margin-bottom: 8px; color: #0f172a; }
        h2 { font-size: 20px; margin: 24px 0 12px; color: #0f172a; }
        p, li { font-size: 15px; margin-bottom: 12px; color: #334155; }
        .date { color: #64748b; font-size: 13px; margin-bottom: 24px; }
        ul { padding-left: 24px; }
    </style>
</head>
<body>
    <h1>Privacy Policy</h1>
    <p class="date">Last updated: March 2026</p>

    <h2>1. Information We Collect</h2>
    <p>We collect the following information when you use WABEES:</p>
    <ul>
        <li><strong>Account Information:</strong> Name, email address, phone number.</li>
        <li><strong>WhatsApp Configuration:</strong> WhatsApp Business API credentials (Phone Number ID, Access Token).</li>
        <li><strong>Messages:</strong> Message content, media files, and metadata sent through the platform.</li>
        <li><strong>Contacts:</strong> Contact names, phone numbers, and tags.</li>
        <li><strong>Usage Data:</strong> Analytics, message counts, and feature usage.</li>
    </ul>

    <h2>2. How We Use Your Information</h2>
    <ul>
        <li>To provide and maintain the WABEES service.</li>
        <li>To send and receive messages through the WhatsApp Business API.</li>
        <li>To display analytics and usage statistics.</li>
        <li>To process subscriptions and payments.</li>
        <li>To improve our service and user experience.</li>
    </ul>

    <h2>3. Data Storage</h2>
    <ul>
        <li>Your data is stored securely on Google Firebase (Firestore).</li>
        <li>Media files are processed through WhatsApp's servers.</li>
        <li>We use encryption in transit (HTTPS/TLS) for all communications.</li>
    </ul>

    <h2>4. Data Sharing</h2>
    <p>We do not sell your personal data. We share data only with:</p>
    <ul>
        <li><strong>Meta/WhatsApp:</strong> As required to deliver messages through the WhatsApp Business API.</li>
        <li><strong>Firebase/Google:</strong> For data storage and authentication.</li>
    </ul>

    <h2>5. Data Retention</h2>
    <p>Your data is retained as long as your account is active. You can request data deletion by contacting us or using the account deletion feature in the app.</p>

    <h2>6. Your Rights</h2>
    <ul>
        <li>Access your personal data through the app.</li>
        <li>Request deletion of your account and data.</li>
        <li>Export your contacts and message history.</li>
    </ul>

    <h2>7. Security</h2>
    <p>We implement industry-standard security measures including encrypted connections, secure authentication, and access controls to protect your data.</p>

    <h2>8. Third-Party Services</h2>
    <p>WABEES integrates with:</p>
    <ul>
        <li>Meta WhatsApp Business Cloud API</li>
        <li>Google Firebase (Authentication, Firestore, Cloud Messaging)</li>
        <li>Google Cloud Run (API hosting)</li>
    </ul>

    <h2>9. Children's Privacy</h2>
    <p>WABEES is not intended for use by individuals under 18. We do not knowingly collect data from minors.</p>

    <h2>10. Changes to This Policy</h2>
    <p>We may update this Privacy Policy from time to time. We will notify you of significant changes through the app.</p>

    <h2>11. Contact Us</h2>
    <p>For privacy-related questions, contact us through the app's support feature.</p>
</body>
</html>
