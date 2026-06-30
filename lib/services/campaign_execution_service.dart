import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repositories/whatsapp_repository.dart';
import '../data/repositories/campaign_repository.dart';
import '../data/repositories/plan_repository.dart';
import '../data/models/campaign/campaign_status.dart';
import 'anti_ban_service.dart';

/// 🚀 CAMPAIGN EXECUTION SERVICE
/// Sends WhatsApp messages one-by-one with delay, pause/resume,
/// real-time Firestore tracking, security validation,
/// and anti-ban coordination.
class CampaignExecutionService {
  final WhatsappRepository _waRepo;
  final CampaignRepository _campaignRepo;
  final AntiBanService _antiBan;
  final PlanRepository _planRepo;
  final String _userId;

  // Execution state
  bool _isPaused = false;
  bool _isCancelled = false;
  String? _activeCampaignId;

  // Campaign sending speed
  static const int _delayMs = 500;          // 500ms between messages (2 msgs/sec)
  static const int _batchSize = 80;         // Pause after batch
  static const int _batchCooldownMs = 3000; // 3s cooldown between batches
  static const int _maxRetriesPerMessage = 2;

  CampaignExecutionService({
    required WhatsappRepository waRepo,
    required CampaignRepository campaignRepo,
    required AntiBanService antiBan,
    required PlanRepository planRepo,
    required String userId,
  })  : _waRepo = waRepo,
        _campaignRepo = campaignRepo,
        _antiBan = antiBan,
        _planRepo = planRepo,
        _userId = userId;

  /// Is a campaign currently executing?
  bool get isExecuting => _activeCampaignId != null;
  String? get activeCampaignId => _activeCampaignId;

  /// Execute a campaign — sends messages to all recipients
  Future<void> execute(String campaignId) async {
    if (_activeCampaignId != null) {
      throw Exception('Another campaign is already running');
    }

    _activeCampaignId = campaignId;
    _isPaused = false;
    _isCancelled = false;

    try {
      // 1. Load campaign
      final campaign = await _campaignRepo.getCampaign(_userId, campaignId);
      if (campaign == null) throw Exception('Campaign not found');

      // 2. Resolve full recipient list + normalize ALL phones upfront
      final rawPhones = List<String>.from(campaign.audiencePhones);

      // Resolve group contacts
      if (campaign.audienceGroups.isNotEmpty) {
        final groupPhones = await _resolveGroupPhones(campaign.audienceGroups);
        rawPhones.addAll(groupPhones);
      }

      // Resolve tag-based contacts
      if (campaign.audienceTags.isNotEmpty) {
        final tagPhones = await _resolveTagPhones(campaign.audienceTags);
        rawPhones.addAll(tagPhones);
      }

      // Normalize ALL phones and deduplicate
      final normalizedSet = <String>{};
      final recipients = <String>[];
      for (final raw in rawPhones) {
        final norm = _normalizePhone(raw);
        if (norm.isNotEmpty && _isValidPhone(norm) && normalizedSet.add(norm)) {
          recipients.add(norm);
        }
      }

      if (recipients.isEmpty) {
        await _campaignRepo.updateStatus(
          _userId, campaignId, CampaignStatus.failed,
        );
        await _campaignRepo.addLog(_userId, campaignId, phone: '', status: 'failed', reason: 'No recipients found');
        return;
      }

      // 3. Validate campaign (skip message validation for templates)
      _validateCampaign(recipients, campaign.messageBody, isTemplate: campaign.isTemplate);

      // 4. Update total recipients (actual deduped count) + set running
      await _campaignRepo.startCampaign(_userId, campaignId);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('campaigns')
          .doc(campaignId)
          .update({'totalRecipients': recipients.length});

      // 5. Send start notification
      await _addNotification(
        'Campaign Started! 🚀',
        '${campaign.name} is sending to ${recipients.length} recipients.',
        'campaign_started',
        campaignId,
      );

      // 6. Skip already-processed messages (sent + failed — for resume)
      final allProcessedPhones = await _campaignRepo.getAllProcessedPhones(_userId, campaignId);
      final pending = recipients
          .where((phone) => !allProcessedPhones.contains(phone))
          .toList();

      // 7. Send messages with delay
      int batchCount = 0;
      int sentSoFar = allProcessedPhones.length;
      final total = recipients.length;
      int lastMilestone = 0;

      for (int i = 0; i < pending.length; i++) {
        // Check pause/cancel
        if (_isCancelled) break;

        while (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (_isCancelled) break;

          // Check Firestore status (in case paused from another device)
          final current = await _campaignRepo.getCampaign(_userId, campaignId);
          if (current?.status == CampaignStatus.paused) {
            continue;
          } else if (current?.status == CampaignStatus.running) {
            _isPaused = false;
          } else {
            _isCancelled = true;
            break;
          }
        }
        if (_isCancelled) break;

        // Phones are already normalized and validated in step 2
        final normalizedPhone = pending[i];

        // Sanitize message (prevent injection)
        final sanitizedMessage = _sanitizeMessage(campaign.messageBody);

        // Send message
        bool success = false;
        String? errorReason;
        String? wamid;

        for (int retry = 0; retry <= _maxRetriesPerMessage; retry++) {
          try {
            bool resultSuccess;
            String? resultMessage;
            String? resultWamid;

            if (campaign.isTemplate) {
              // Build template components with variables
              List<Map<String, dynamic>>? components;
              if (campaign.templateVariables.isNotEmpty) {
                final varValues = <String>[];
                if (campaign.variableSource == 'csv') {
                  // Find this recipient's data in recipientData
                  final recipientMap = campaign.recipientData.firstWhere(
                    (r) => _normalizePhone(r['phone'] ?? '') == normalizedPhone,
                    orElse: () => {},
                  );
                  for (final varName in campaign.templateVariables) {
                    varValues.add(recipientMap[varName] ?? '');
                  }
                } else {
                  // Static: same values for all
                  for (final varName in campaign.templateVariables) {
                    varValues.add(campaign.staticVariableValues[varName] ?? '');
                  }
                }

                // Build Meta API components format
                if (varValues.any((v) => v.isNotEmpty)) {
                  components = [
                    {
                      'type': 'body',
                      'parameters': varValues.map((v) => <String, dynamic>{
                        'type': 'text',
                        'text': v,
                      }).toList(),
                    }
                  ];
                }
              }

              final result = await _waRepo.sendTemplate(
                userId: _userId,
                to: normalizedPhone,
                templateName: campaign.templateName ?? campaign.messageBody,
                languageCode: campaign.templateLanguage ?? 'en',
                components: components,
              );
              resultSuccess = result.success;
              resultMessage = result.message;
              resultWamid = result.messageId;
            } else {
              final result = await _waRepo.sendText(
                userId: _userId,
                to: normalizedPhone,
                message: sanitizedMessage,
              );
              resultSuccess = result.success;
              resultMessage = result.message;
              resultWamid = result.messageId;
            }

            if (resultSuccess) {
              success = true;
              wamid = resultWamid;
              break;
            } else {
              errorReason = resultMessage ?? 'API error';
              if (retry < _maxRetriesPerMessage) {
                await Future.delayed(const Duration(seconds: 3));
              }
            }
          } catch (e) {
            errorReason = e.toString();
            if (retry < _maxRetriesPerMessage) {
              await Future.delayed(const Duration(seconds: 3));
            }
          }
        }

        // Update analytics
        if (success) {
          await _campaignRepo.incrementSent(_userId, campaignId);
          // Count toward plan message usage
          try { await _planRepo.incrementMessages(_userId); } catch (_) {}
          try {
            await _campaignRepo.addLog(
              _userId, campaignId,
              phone: normalizedPhone,
              status: 'sent',
              wamid: wamid,
            );
          } catch (_) {}

          // Store wamid → campaignId mapping for delivered/read tracking
          if (wamid != null && wamid.isNotEmpty) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_userId)
                  .collection('campaign_messages')
                  .doc(wamid)
                  .set({
                'campaignId': campaignId,
                'phone': normalizedPhone,
                'sentAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }
        } else {
          await _campaignRepo.incrementFailed(_userId, campaignId);
          try { await _campaignRepo.addLog(_userId, campaignId, phone: normalizedPhone, status: 'failed', reason: errorReason); } catch (_) {}
        }

        sentSoFar++;

        // Milestone notifications (25%, 50%, 75%)
        if (total > 0) {
          final pct = (sentSoFar / total * 100).floor();
          for (final milestone in [25, 50, 75]) {
            if (pct >= milestone && lastMilestone < milestone) {
              lastMilestone = milestone;
              await _addNotification(
                'Campaign Progress: $milestone% 📊',
                '${campaign.name}: $sentSoFar / $total messages processed.',
                'campaign_progress',
                campaignId,
              );
            }
          }
        }

        // Campaign speed delay (500ms = 2 msgs/sec)
        batchCount++;
        // Apply anti-ban delay if service flags a slowdown
        final canSend = _antiBan.canSend(contactPhone: normalizedPhone, messageText: campaign.messageBody);
        final extraDelay = canSend != null ? 2000 : 0;
        if (batchCount >= _batchSize && i < pending.length - 1) {
          // Batch cooldown
          batchCount = 0;
          await Future.delayed(Duration(milliseconds: _batchCooldownMs + extraDelay));
        } else if (i < pending.length - 1) {
          // Normal delay
          await Future.delayed(Duration(milliseconds: _delayMs + extraDelay));
        }
      }

      // 8. AUTO-RETRY: Retry all failed messages once
      if (!_isCancelled) {
        final failedPhones = await _campaignRepo.getFailedPhones(_userId, campaignId);
        if (failedPhones.isNotEmpty) {
          await _addNotification(
            'Retrying Failed Messages 🔄',
            '${campaign.name}: Retrying ${failedPhones.length} failed messages...',
            'campaign_retry',
            campaignId,
          );

          for (final retryPhone in failedPhones) {
            if (_isCancelled) break;

            bool retrySuccess = false;
            try {
              if (campaign.isTemplate) {
                final result = await _waRepo.sendTemplate(
                  userId: _userId,
                  to: retryPhone,
                  templateName: campaign.templateName ?? campaign.messageBody,
                  languageCode: campaign.templateLanguage ?? 'en',
                );
                retrySuccess = result.success;
              } else {
                final result = await _waRepo.sendText(
                  userId: _userId,
                  to: retryPhone,
                  message: _sanitizeMessage(campaign.messageBody),
                );
                retrySuccess = result.success;
              }
            } catch (_) {}

            if (retrySuccess) {
              // Move from failed to sent
              await _campaignRepo.decrementFailed(_userId, campaignId);
              await _campaignRepo.incrementSent(_userId, campaignId);
              try { await _campaignRepo.addLog(_userId, campaignId, phone: retryPhone, status: 'sent', reason: 'Retry success'); } catch (_) {}
              try { await _planRepo.incrementMessages(_userId); } catch (_) {}
            }

            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      // 9. Complete campaign
      if (!_isCancelled) {
        await _campaignRepo.completeCampaign(_userId, campaignId);
      } else {
        // Notify about pause/cancel
        await _addNotification(
          'Campaign Paused ⏸️',
          '${campaign.name} was paused. You can resume it anytime.',
          'campaign_paused',
          campaignId,
        );
      }
    } catch (e) {
      // Mark as failed if error
      try {
        await _campaignRepo.updateStatus(
          _userId, campaignId, CampaignStatus.failed,
        );
        await _campaignRepo.addLog(_userId, campaignId, phone: '', status: 'error', reason: 'Execution error: $e');
        await _addNotification(
          'Campaign Failed ❌',
          'An error occurred. Check campaign details for more info.',
          'campaign_failed',
          campaignId,
        );
      } catch (_) {}
    } finally {
      _activeCampaignId = null;
    }
  }

  /// Pause current execution
  void pause() {
    _isPaused = true;
  }

  /// Resume paused execution
  void resume() {
    _isPaused = false;
  }

  /// Cancel current execution
  void cancel() {
    _isCancelled = true;
    _isPaused = false;
  }

  // ============ NOTIFICATIONS ============

  Future<void> _addNotification(String title, String body, String type, String campaignId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'data': {'campaignId': campaignId},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ============ SECURITY: Input Validation ============

  void _validateCampaign(List<String> phones, String message, {bool isTemplate = false}) {
    if (phones.isEmpty) {
      throw Exception('Campaign has no recipients');
    }
    // Skip message body validation for templates (messageBody is template body text, not user input)
    if (!isTemplate) {
      if (message.trim().isEmpty) {
        throw Exception('Campaign message is empty');
      }
      if (message.length > 4096) {
        throw Exception('Message exceeds WhatsApp limit (4096 chars)');
      }
      if (_containsSuspiciousContent(message)) {
        throw Exception('Message contains suspicious content');
      }
    }
  }

  /// Normalize phone to E.164 international format (+CountryCodeNumber).
  ///
  /// Handles:
  /// - Excel scientific notation:  9.23E+11 → +923000000000
  /// - Already E.164:              +14155551234 → +14155551234 (unchanged)
  /// - Pakistani local (0-prefix): 03001234567 → +923001234567
  /// - Pakistani local (3-prefix): 3001234567  → +923001234567
  /// - International without +:    923001234567 → +923001234567
  /// - Any other number ≥10 digits: prepends +
  String _normalizePhone(String raw) {
    var phone = raw.trim();

    // Handle Excel scientific notation (e.g. 9.23E+11 → 923000000000)
    if (RegExp(r'^[0-9.]+[eE][+\-]?[0-9]+$').hasMatch(phone)) {
      try {
        final n = double.parse(phone);
        phone = n.toStringAsFixed(0);
      } catch (_) {}
    }

    // Preserve + prefix, then strip all formatting
    final hadPlus = phone.startsWith('+');
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.isEmpty) return '';

    // Already had + → treat as international, return as-is
    if (hadPlus) return '+$phone';

    // Pakistani local format: 03XXXXXXXXX (11 digits, starts with 0)
    if (phone.startsWith('0') && phone.length == 11) {
      return '+92${phone.substring(1)}';
    }

    // Pakistani short format: 3XXXXXXXXX (10 digits, starts with 3)
    if (phone.startsWith('3') && phone.length == 10) {
      return '+92$phone';
    }

    // Already has country code but no + (e.g. 923001234567, 14155551234)
    // If length ≥ 11, assume it already includes country code → just add +
    if (phone.length >= 11) {
      return '+$phone';
    }

    // Short local number without country code (≥7 digits) — add + and return
    // (caller may need to verify this is a valid number for their country)
    if (phone.length >= 7) {
      return '+$phone';
    }

    return phone;
  }

  bool _isValidPhone(String phone) {
    if (!phone.startsWith('+')) return false;
    final digits = phone.substring(1);
    // E.164: 7–15 digits after country code
    if (digits.length < 7 || digits.length > 15) return false;
    return RegExp(r'^\d+$').hasMatch(digits);
  }

  String _sanitizeMessage(String message) {
    // Remove null bytes and control characters (except newlines)
    var sanitized = message.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    // Trim excessive whitespace
    sanitized = sanitized.trim();
    // Limit length
    if (sanitized.length > 4096) {
      sanitized = sanitized.substring(0, 4096);
    }
    return sanitized;
  }

  bool _containsSuspiciousContent(String message) {
    final lower = message.toLowerCase();
    // Detect script injection attempts
    if (RegExp(r'<script|javascript:|data:text/html|on\w+\s*=').hasMatch(lower)) {
      return true;
    }
    // Detect SQL injection patterns
    if (RegExp(r"('\s*(or|and)\s*'|--\s*$|;\s*drop\s|union\s+select)", caseSensitive: false).hasMatch(lower)) {
      return true;
    }
    return false;
  }

  // ============ HELPERS ============

  Future<List<String>> _resolveGroupPhones(List<String> groups) async {
    final phones = <String>[];
    // Firestore whereIn limit is 10, so batch the queries
    for (int i = 0; i < groups.length; i += 10) {
      final batch = groups.skip(i).take(10).toList();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('contacts')
          .where('group', whereIn: batch)
          .get();
      phones.addAll(
        snap.docs
            .map((d) => d.data()['phone'] as String? ?? '')
            .where((p) => p.isNotEmpty),
      );
    }
    return phones;
  }

  /// Resolve contacts that have ANY of the given tags
  Future<List<String>> _resolveTagPhones(List<String> tags) async {
    final phones = <String>[];
    // Firestore arrayContainsAny limit is 10
    for (int i = 0; i < tags.length; i += 10) {
      final batch = tags.skip(i).take(10).toList();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('contacts')
          .where('tags', arrayContainsAny: batch)
          .get();
      phones.addAll(
        snap.docs
            .map((d) => d.data()['phone'] as String? ?? '')
            .where((p) => p.isNotEmpty),
      );
    }
    return phones;
  }
}
