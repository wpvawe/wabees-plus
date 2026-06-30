/// 📱 PHONE VALIDATOR
class PhoneValidator {
  PhoneValidator._();

  static final RegExp _phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$');

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!_phoneRegex.hasMatch(cleaned)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }
}
