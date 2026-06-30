import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/whatsapp/whatsapp_api_response.dart';

/// 📡 WHATSAPP API DATASOURCE
/// All calls go through Hostinger proxy — NOT direct to Meta API
class WhatsappApiDs {
  late final Dio _dio;

  // ⚠️ API base domain
  static const String _baseUrl = 'https://api.wabees.live/api';

  WhatsappApiDs() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // NOTE: Do NOT set Content-Type here — Dio auto-sets it:
      //   • 'application/json' for Map data
      //   • 'multipart/form-data' for FormData (media uploads)
      // Setting it here breaks multipart uploads.
    ));

    // Request/Response Logging (debug only)
    if (!kReleaseMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  // ============ VERIFY CONNECTION ============
  Future<WhatsappApiResponse> verifyConnection({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/verify-token.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Connection failed'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ SEND TEXT MESSAGE ============
  Future<WhatsappApiResponse> sendTextMessage({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '/send-message.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'to': to,
          'type': 'text',
          'message': message,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to send message'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ SEND TEMPLATE MESSAGE ============
  Future<WhatsappApiResponse> sendTemplateMessage({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String templateName,
    required String languageCode,
    List<Map<String, dynamic>>? components,
  }) async {
    try {
      final response = await _dio.post(
        '/send-message.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'to': to,
          'type': 'template',
          'template_name': templateName,
          'language_code': languageCode,
          'components': components,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to send template'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ GET TEMPLATES ============
  Future<WhatsappApiResponse> getTemplates({
    required String businessAccountId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/get-templates.php',
        data: {
          'business_account_id': businessAccountId,
          'access_token': accessToken,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to fetch templates'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ CREATE TEMPLATE (Meta API) ============
  Future<WhatsappApiResponse> createTemplate({
    required String businessAccountId,
    required String accessToken,
    required String name,
    required String category,
    required String language,
    required String body,
    String? header,
    String? footer,
    Map<String, String>? variableSamples,
    Map<String, String>? variableTypes,
    List<Map<String, dynamic>>? buttons,
  }) async {
    try {
      final response = await _dio.post(
        '/create-template.php',
        data: {
          'business_account_id': businessAccountId,
          'access_token': accessToken,
          'name': name,
          'category': category,
          'language': language,
          'body': body,
          if (header != null && header.isNotEmpty) 'header': header,
          if (footer != null && footer.isNotEmpty) 'footer': footer,
          if (variableSamples != null && variableSamples.isNotEmpty)
            'variable_samples': variableSamples,
          if (variableTypes != null && variableTypes.isNotEmpty)
            'variable_types': variableTypes,
          if (buttons != null && buttons.isNotEmpty)
            'buttons': buttons,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to create template'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ EDIT TEMPLATE (Meta API) ============
  Future<WhatsappApiResponse> editTemplate({
    required String accessToken,
    required String templateId,
    required String body,
    String? header,
    String? footer,
    String? category,
  }) async {
    try {
      final response = await _dio.post(
        '/edit-template.php',
        data: {
          'access_token': accessToken,
          'template_id': templateId,
          'body': body,
          if (header != null && header.isNotEmpty) 'header': header,
          if (footer != null && footer.isNotEmpty) 'footer': footer,
          if (category != null) 'category': category,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to edit template'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ DELETE TEMPLATE (Meta API — DIRECT CALL) ============
  Future<WhatsappApiResponse> deleteTemplate({
    required String businessAccountId,
    required String accessToken,
    required String templateName,
  }) async {
    try {
      final metaDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) => true, // Accept all to read error bodies
      ));

      final url = 'https://graph.facebook.com/v21.0/$businessAccountId/message_templates';

      debugPrint('🗑️ DELETE template "$templateName" from WABA: $businessAccountId');
      debugPrint('🗑️ URL: $url?name=$templateName');

      final response = await metaDio.delete(
        url,
        queryParameters: {
          'name': templateName,
          'access_token': accessToken,
        },
      );

      debugPrint('🗑️ Status: ${response.statusCode}');
      debugPrint('🗑️ Response: ${response.data}');

      // Check HTTP status FIRST
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        // Error response
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('error')) {
          return WhatsappApiResponse.fromJson(data);
        }
        return WhatsappApiResponse.error(
          'Meta API returned status $statusCode: ${response.data}',
        );
      }

      // Status 200 — check response body
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          return WhatsappApiResponse.fromJson(data);
        }
        if (data['success'] == true) {
          debugPrint('🗑️ ✅ Template "$templateName" deleted from Meta');
          return const WhatsappApiResponse(success: true, message: 'Template deleted');
        }
        // Unknown response format — treat as error
        return WhatsappApiResponse.error(
          'Unexpected response from Meta: $data',
        );
      }

      // Non-map response — treat as error
      return WhatsappApiResponse.error(
        'Unexpected response format from Meta: ${response.data}',
      );
    } on DioException catch (e) {
      debugPrint('🗑️ ❌ DioException: ${e.message}');
      debugPrint('🗑️ ❌ Response: ${e.response?.data}');
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        return WhatsappApiResponse.fromJson(data);
      }
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to delete template'));
    } catch (e) {
      debugPrint('🗑️ ❌ Exception: $e');
      return WhatsappApiResponse.error('Failed to delete template: $e');
    }
  }



  // ============ SEND MEDIA MESSAGE ============
  Future<WhatsappApiResponse> sendMediaMessage({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String mediaType, // image, video, document, audio
    String? mediaUrl,
    String? mediaId,
    String? caption,
    bool? isVoice, // true = send as real WA voice note
  }) async {
    try {
      final Map<String, dynamic> data = {
        'phone_number_id': phoneNumberId,
        'access_token': accessToken,
        'to': to,
        'type': mediaType,
        'caption': caption,
      };
      if (mediaId != null && mediaId.isNotEmpty) {
        data['media_id'] = mediaId;
      }
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        data['media_url'] = mediaUrl;
      }
      // Send voice notes as real WhatsApp voice messages (waveform UI)
      if (mediaType == 'audio' && (isVoice ?? false)) {
        data['is_voice'] = true;
      }

      final response = await _dio.post(
        '/send-message.php',
        data: data,
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to send media'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ GET INSIGHTS (Quality + Limits + Templates) ============
  Future<WhatsappApiResponse> getInsights({
    required String phoneNumberId,
    required String accessToken,
    String? businessAccountId,
  }) async {
    try {
      final response = await _dio.post(
        '/get-insights.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          if (businessAccountId != null && businessAccountId.isNotEmpty)
            'business_account_id': businessAccountId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to fetch insights'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ GET MONTHLY ANALYTICS ============
  Future<WhatsappApiResponse> getAnalytics({
    required String businessAccountId,
    required String accessToken,
    required String phoneNumberId,
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    try {
      final response = await _dio.post(
        '/get-analytics.php',
        data: {
          'business_account_id': businessAccountId,
          'access_token': accessToken,
          'phone_number_id': phoneNumberId,
          'start': startTimestamp,
          'end': endTimestamp,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to fetch analytics'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }


  // ============ MARK MESSAGE AS READ ============
  Future<WhatsappApiResponse> markMessageRead({
    required String phoneNumberId,
    required String accessToken,
    required String messageId,
  }) async {
    try {
      final response = await _dio.post(
        '/mark-read.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'message_id': messageId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to send read receipt'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ DELETE (UNSEND) MESSAGE ============
  Future<WhatsappApiResponse> deleteWhatsAppMessage({
    required String phoneNumberId,
    required String accessToken,
    required String messageId,
  }) async {
    try {
      final response = await _dio.post(
        '/delete-message.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'message_id': messageId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to delete message'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ GET PHONE HEALTH ============
  Future<WhatsappApiResponse> getPhoneHealth({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/phone-health.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to fetch phone health'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ BUSINESS PROFILE ============
  Future<WhatsappApiResponse> getBusinessProfile({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/business-profile.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'action': 'get',
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to fetch business profile'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  Future<WhatsappApiResponse> updateBusinessProfile({
    required String phoneNumberId,
    required String accessToken,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final response = await _dio.post(
        '/business-profile.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'action': 'update',
          ...profileData,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to update business profile'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ UPLOAD MEDIA ============
  Future<WhatsappApiResponse> uploadMedia({
    required String filePath,
    required String mediaType,
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'type': mediaType,
        'phone_number_id': phoneNumberId,
        'access_token': accessToken,
      });
      final response = await _dio.post('/upload-media.php', data: formData);
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to upload file'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  // ============ UPDATE BASE URL ============

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  // ============ FRIENDLY ERROR MESSAGES ============
  String _friendlyDioError(DioException e, String fallback) {
    // Try to extract server-provided message
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String && msg.isNotEmpty) return msg;
      // Meta API nested error
      final metaError = data['error'];
      if (metaError is Map) {
        final metaMsg = metaError['message'];
        if (metaMsg is String && metaMsg.isNotEmpty) return metaMsg;
      }
    }

    // Map HTTP status codes to user-friendly messages
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Invalid Phone Number ID or Access Token. Please check and try again';
        case 401:
          return 'Access Token is invalid or expired. Generate a new one';
        case 403:
          return 'Access denied. Check your app permissions';
        case 404:
          return 'Resource not found (404). Please check your configuration';
        case 429:
          return 'Too many requests. Please wait and try again';
        case 500:
        case 502:
        case 503:
          return 'Server is temporarily unavailable. Try again later';
      }
    }

    // Connection-level errors
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your internet';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network';
      default:
        return fallback;
    }
  }



  // ============ DETECT BUSINESSES ============
  Future<WhatsappApiResponse> detectBusinesses({
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/whatsapp-detect-businesses.php',
        data: {'access_token': accessToken},
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(
          _friendlyDioError(e, 'Failed to detect businesses'));
    } catch (e) {
      return WhatsappApiResponse.error('Failed to detect businesses');
    }
  }

  // ============ DETECT WABAs ============
  Future<WhatsappApiResponse> detectWabas({
    required String accessToken,
    required String businessId,
  }) async {
    try {
      final response = await _dio.post(
        '/whatsapp-detect-wabas.php',
        data: {
          'access_token': accessToken,
          'business_id': businessId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(
          _friendlyDioError(e, 'Failed to detect WABAs'));
    } catch (e) {
      return WhatsappApiResponse.error('Failed to detect WABAs');
    }
  }

  // ============ DETECT PHONE NUMBERS ============
  Future<WhatsappApiResponse> detectPhones({
    required String accessToken,
    required String wabaId,
  }) async {
    try {
      final response = await _dio.post(
        '/whatsapp-detect-phones.php',
        data: {
          'access_token': accessToken,
          'waba_id': wabaId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(
          _friendlyDioError(e, 'Failed to detect phone numbers'));
    } catch (e) {
      return WhatsappApiResponse.error('Failed to detect phone numbers');
    }
  }

  // ============ SMART CONNECT ============
  Future<WhatsappApiResponse> smartConnect({
    required String accessToken,
    required String phoneNumberId,
  }) async {
    try {
      final response = await _dio.post(
        '/whatsapp-smart-connect.php',
        data: {
          'access_token': accessToken,
          'phone_number_id': phoneNumberId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(
          _friendlyDioError(e, 'Smart connect failed'));
    } catch (e) {
      return WhatsappApiResponse.error('Smart connect failed');
    }
  }

  // ============ SUBSCRIBE TO META WEBHOOKS ============
  /// CRITICAL: Must be called after every new number connection.
  /// Without this, Meta does NOT deliver incoming messages to the webhook.
  /// Calls POST /{phone_number_id}/subscribed_apps via backend proxy.
  Future<WhatsappApiResponse> subscribeWebhook({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/subscribe-webhook.php',
        data: {
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('[WABEES] subscribeWebhook error: ${e.message}');
      return WhatsappApiResponse.error(
          _friendlyDioError(e, 'Webhook subscription failed'));
    } catch (e) {
      debugPrint('[WABEES] subscribeWebhook exception: $e');
      return WhatsappApiResponse.error('Webhook subscription failed: $e');
    }
  }

  // ============ MESSAGE LINKS (wa.me/message/XXX) ============
  Future<WhatsappApiResponse> getMessageLinks({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/message-links.php',
        data: {
          'action': 'list',
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to fetch message links'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  Future<WhatsappApiResponse> createMessageLink({
    required String phoneNumberId,
    required String accessToken,
    required String prefilledMessage,
  }) async {
    try {
      final response = await _dio.post(
        '/message-links.php',
        data: {
          'action': 'create',
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'prefilled_message': prefilledMessage,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to create message link'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }

  Future<WhatsappApiResponse> deleteMessageLink({
    required String phoneNumberId,
    required String accessToken,
    required String linkId,
  }) async {
    try {
      final response = await _dio.post(
        '/message-links.php',
        data: {
          'action': 'delete',
          'phone_number_id': phoneNumberId,
          'access_token': accessToken,
          'link_id': linkId,
        },
      );
      return WhatsappApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return WhatsappApiResponse.error(_friendlyDioError(e, 'Failed to delete message link'));
    } catch (e) {
      return WhatsappApiResponse.error('Something went wrong. Please try again');
    }
  }
}
