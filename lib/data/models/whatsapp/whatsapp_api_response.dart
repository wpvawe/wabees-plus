/// 📱 WHATSAPP API RESPONSE MODEL
class WhatsappApiResponse {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? messageId; // wamid from Meta API

  const WhatsappApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errorCode,
    this.messageId,
  });

  factory WhatsappApiResponse.fromJson(Map<String, dynamic> json) {
    // Meta API error format — handle both Map and String error values
    if (json.containsKey('error')) {
      final rawError = json['error'];
      String errorMessage = 'Unknown error';
      String? errorCode;

      if (rawError is Map<String, dynamic>) {
        errorMessage = rawError['message'] ?? 'Unknown error';
        errorCode = rawError['code']?.toString();
      } else if (rawError is String) {
        errorMessage = rawError;
      }

      return WhatsappApiResponse(
        success: false,
        message: errorMessage,
        errorCode: errorCode,
        data: json,
      );
    }

    // Extract wamid from Meta API success response
    String? wamid;
    try {
      final messages = json['messages'];
      if (messages is List && messages.isNotEmpty) {
        wamid = messages[0]['id']?.toString();
      }
    } catch (_) {}

    return WhatsappApiResponse(
      success: true,
      message: 'Success',
      data: json,
      messageId: wamid,
    );
  }

  factory WhatsappApiResponse.error(String message) {
    return WhatsappApiResponse(
      success: false,
      message: message,
    );
  }
}
