import 'dart:convert';
import 'dart:typed_data';
import '../../data/models/contact/contact_model.dart';

/// 📦 CONTACT CSV EXPORT/IMPORT UTILITY — CSV + Sample File
class ContactCsvHelper {
  // ============ EXPORT TO CSV STRING ============
  static String exportToCsv(List<ContactModel> contacts) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('Phone,Name,Email,Company,Group,Tags,Notes');

    for (final c in contacts) {
      buffer.writeln(
        '${_escape(c.phone)},'
        '${_escape(c.name)},'
        '${_escape(c.email ?? '')},'
        '${_escape(c.company ?? '')},'
        '${_escape(c.group ?? '')},'
        '${_escape(c.tags.join('; '))},'
        '${_escape(c.notes ?? '')}',
      );
    }

    return buffer.toString();
  }

  // ============ EXPORT TO BYTES (for FilePicker.saveFile) ============
  static Uint8List exportToBytes(List<ContactModel> contacts) {
    return Uint8List.fromList(utf8.encode(exportToCsv(contacts)));
  }

  // ============ IMPORT FROM CSV STRING ============
  static List<ContactModel> importFromCsv(String csvString) {
    final lines = const LineSplitter().convert(csvString);
    if (lines.length < 2) return []; // Need header + at least 1 row

    final contacts = <ContactModel>[];

    // Detect header to find column indices
    final headerLine = lines[0].toLowerCase().trim();
    final headers = _parseCsvLine(headerLine);
    final colMap = _buildColumnMap(headers);

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.isEmpty) continue;

      // Get phone — required
      final phone = _normalizePhone(_getField(fields, colMap['phone'] ?? 0).trim());
      if (phone.isEmpty || !_isValidPhone(phone)) continue;

      // Get name — use phone as fallback
      final name = _getField(fields, colMap['name'] ?? 1).trim();

      // Optional fields
      final email = _getField(fields, colMap['email']).trim();
      final company = _getField(fields, colMap['company']).trim();
      final group = _getField(fields, colMap['group']).trim();
      final tagsStr = _getField(fields, colMap['tags']).trim();
      final notes = _getField(fields, colMap['notes']).trim();

      final tags = tagsStr.isEmpty
          ? <String>[]
          : tagsStr
              .split(RegExp(r'[;,]'))
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .take(10)
              .toList();

      contacts.add(ContactModel(
        id: '',
        phone: phone,
        name: _truncate(name.isNotEmpty ? name : phone, 100),
        email: email.isNotEmpty ? _truncate(email, 255) : null,
        company: company.isNotEmpty ? _truncate(company, 100) : null,
        group: group.isNotEmpty ? _truncate(group, 50) : null,
        tags: tags,
        notes: notes.isNotEmpty ? _truncate(notes, 500) : null,
        createdAt: DateTime.now(),
      ));
    }

    return contacts;
  }

  // ============ GENERATE SAMPLE CSV ============
  /// Returns sample CSV content with headers and example rows
  static String generateSampleCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Phone,Name,Email,Company,Group,Tags,Notes');
    buffer.writeln('+923001234567,Ahmed Khan,ahmed@gmail.com,Tech Corp,Customers,vip; lead,Regular customer');
    buffer.writeln('+923009876543,Sara Ali,sara@company.com,Design Studio,Leads,new; interested,Asked about pricing');
    buffer.writeln('03451234567,Usman Malik,,,,friend,');
    return buffer.toString();
  }

  /// Get sample CSV as bytes for FilePicker.saveFile
  static Uint8List generateSampleCsvBytes() {
    return Uint8List.fromList(utf8.encode(generateSampleCsv()));
  }

  // ============ SMART COLUMN DETECTION ============
  static Map<String, int> _buildColumnMap(List<String> headers) {
    final map = <String, int>{};

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (_matchesAny(h, ['phone', 'phonenumber', 'mobile', 'whatsapp', 'number', 'cell', 'contact'])) {
        map['phone'] = i;
      } else if (_matchesAny(h, ['name', 'fullname', 'contactname', 'firstname'])) {
        map['name'] = i;
      } else if (_matchesAny(h, ['email', 'emailaddress', 'mail'])) {
        map['email'] = i;
      } else if (_matchesAny(h, ['company', 'organization', 'org', 'business'])) {
        map['company'] = i;
      } else if (_matchesAny(h, ['group', 'category', 'segment', 'list'])) {
        map['group'] = i;
      } else if (_matchesAny(h, ['tags', 'labels', 'tag', 'label'])) {
        map['tags'] = i;
      } else if (_matchesAny(h, ['notes', 'note', 'comment', 'comments', 'description'])) {
        map['notes'] = i;
      }
    }

    if (!map.containsKey('phone')) map['phone'] = 0;
    if (!map.containsKey('name')) map['name'] = headers.length > 1 ? 1 : 0;

    return map;
  }

  static bool _matchesAny(String value, List<String> options) {
    return options.any((opt) => value == opt || value.contains(opt));
  }

  static String _getField(List<String> fields, int? index) {
    if (index == null || index >= fields.length) return '';
    return fields[index];
  }

  // ============ HELPERS ============
  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());

    return fields;
  }

  static String _normalizePhone(String phone) {
    phone = phone.trim();

    // Handle Excel scientific notation (e.g. 9.23E+11 → 923000000000)
    if (RegExp(r'^[0-9.]+[eE][+\-]?[0-9]+$').hasMatch(phone)) {
      try {
        final n = double.parse(phone);
        phone = n.toStringAsFixed(0);
      } catch (_) {}
    }

    final cleaned = phone.startsWith('+')
        ? '+${phone.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}'
        : phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Already has + prefix and valid length
    if (cleaned.startsWith('+') && cleaned.length >= 12) return cleaned;
    // Pakistani local: 03XXXXXXXXX → +923XXXXXXXXX
    if (cleaned.startsWith('0') && cleaned.length >= 10) {
      return '+92${cleaned.substring(1)}';
    }
    // Pakistani no leading-0: 3XXXXXXXXX → +923XXXXXXXXX
    if (cleaned.startsWith('3') && cleaned.length == 10) {
      return '+92$cleaned';
    }
    // International without +: 92XXXXXXXXXX → +92XXXXXXXXXX
    if (cleaned.startsWith('92') && cleaned.length >= 12 && !cleaned.startsWith('+')) {
      return '+$cleaned';
    }
    // Plain digits 10+
    if (!cleaned.startsWith('+') && cleaned.length >= 10) {
      return '+$cleaned';
    }
    return cleaned;
  }

  static bool _isValidPhone(String phone) {
    if (!phone.startsWith('+')) return false;
    final digits = phone.substring(1);
    if (digits.length < 8 || digits.length > 15) return false;
    return RegExp(r'^\d+$').hasMatch(digits);
  }

  static String _truncate(String value, int maxLength) {
    return value.length > maxLength ? value.substring(0, maxLength) : value;
  }
}
