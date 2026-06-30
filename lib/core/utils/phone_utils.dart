/// 📱 PHONE UTILS — Normalize phone numbers to E.164 international format
///
/// Convention: all phone numbers stored/keyed with + prefix, digits only.
/// Examples:
///   "+923001234567"   — Pakistani number (already normalized)
///   "+14155551234"    — US number (already normalized)
///   "+447911123456"   — UK number (already normalized)
///
/// Handles Pakistani local formats as a convenience shortcut:
///   "03001234567"  → "+923001234567"   (local 0-prefix)
///   "3001234567"   → "+923001234567"   (10-digit, starts with 3)
///
/// For all other numbers: strips formatting and prepends + if missing.
class PhoneUtils {
  PhoneUtils._();

  /// Normalize a phone number to E.164 format ("+CountryCodeNumber").
  /// Strips spaces, dashes, parens, dots.
  /// Handles Pakistani local shortcuts (03XX / 3XX).
  /// All other numbers: just clean formatting and ensure + prefix.
  static String normalize(String phone) {
    // 1. Strip all formatting characters (spaces, dashes, parens, dots)
    String cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // 2. Remove leading + for uniform processing
    bool hadPlus = cleaned.startsWith('+');
    if (hadPlus) {
      cleaned = cleaned.substring(1);
    }

    // 3. Remove any remaining non-digit characters
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return '';

    // 4. Pakistani local shortcuts (only when no + prefix was present)
    if (!hadPlus) {
      // "03001234567" (11 digits, starts with 0) → "923001234567"
      if (cleaned.startsWith('0') && cleaned.length == 11) {
        cleaned = '92${cleaned.substring(1)}';
      }
      // "3001234567" (10 digits, starts with 3) → "923001234567"
      else if (cleaned.startsWith('3') && cleaned.length == 10) {
        cleaned = '92$cleaned';
      }
    }

    // 5. Always prefix with + and return
    return '+$cleaned';
  }

  /// Returns true if the phone looks like a valid E.164 number
  /// (7–15 digits after the + sign).
  static bool isValid(String phone) {
    if (!phone.startsWith('+')) return false;
    final digits = phone.substring(1);
    if (digits.length < 7 || digits.length > 15) return false;
    return RegExp(r'^\d+$').hasMatch(digits);
  }
}
