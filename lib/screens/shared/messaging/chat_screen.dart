import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:wabees/core/services/notification_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../data/models/message/message_model.dart';
import '../../../data/models/message/message_status.dart';

import '../../../data/models/message/message_type.dart';
import '../../../providers/messaging/messaging_provider.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';
import '../../../data/models/whatsapp/whatsapp_api_response.dart';
import '../../../providers/plans/plan_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../providers/calling/webrtc_provider.dart';

/// 💬 CHAT SCREEN — Individual Conversation (Enhanced)
class ChatScreen extends ConsumerStatefulWidget {
  final String contactPhone;
  final String contactName;

  const ChatScreen({
    super.key,
    required this.contactPhone,
    required this.contactName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSendingVoice = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _recordPath;
  bool _hasText = false;
  int _messageLimit = 20;
  bool _isLoadingMore = false;
  bool _ringReady = false; // Prevents ring during initial load
  bool _initialScrollDone = false; // Scroll to bottom on first load
  bool _showScrollToBottom = false; // Show floating scroll-to-bottom button
  MessageModel? _replyingTo; // Message currently being replied to
  String? _lastInboundWamid; // wamid of latest incoming msg (for typing indicator)
  Timer? _typingTimer;
  String? _typingLastWamid;
  DateTime? _typingLastAt;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
      _scheduleTypingIndicator();
    });
    // Scroll listener for loading more messages on scroll up + scroll-to-bottom FAB
    _scrollController.addListener(() {
      // Load more on scroll to top
      if (!_isLoadingMore &&
          _scrollController.hasClients &&
          _scrollController.position.pixels <= _scrollController.position.minScrollExtent + 50) {
        _isLoadingMore = true;
        setState(() => _messageLimit += 20);
        Future.delayed(const Duration(milliseconds: 500), () {
          _isLoadingMore = false;
        });
      }
      // Show/hide scroll-to-bottom FAB
      if (_scrollController.hasClients) {
        final distFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
        final shouldShow = distFromBottom > 200;
        if (shouldShow != _showScrollToBottom) {
          setState(() => _showScrollToBottom = shouldShow);
        }
      }
    });
    // Delay ring activation by 2s — prevents ringing on chat open/reload
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _ringReady = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final normalized = PhoneUtils.normalize(widget.contactPhone);
      ref.read(activeChatPhoneProvider.notifier).state = normalized;

      NotificationService.instance.cancel(normalized.hashCode, tag: normalized);

      final user = ref.read(currentUserProvider);
      if (user != null) {
        final ownerId = user.dataOwner ?? user.id;
        // Lock conversation for this user
        ref.read(messageRepositoryProvider).lockConversation(
          ownerId, widget.contactPhone, user.id, user.email,
        );

        // Mark as read (use ownerId — conversations live under the owner, not the agent)
        ref.read(messageRepositoryProvider).markConversationRead(
          ownerId,
          widget.contactPhone,
        ).then((_) {
          if (mounted) ref.invalidate(conversationsProvider);
        });

        _sendReadReceipt(ownerId);
        
    // FIX: Force re-calculate lastIncomingMessageAt on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user != null) {
         ref.invalidate(chatMessagesProvider(widget.contactPhone));
      }
    });
      }
    });
  }

  /// Send read receipt to WhatsApp for the latest incoming message
  Future<void> _sendReadReceipt(String userId) async {
    try {
      final phone = PhoneUtils.normalize(widget.contactPhone);
      // Get latest messages for this conversation
      final messagesSnapshot = await ref.read(messageRepositoryProvider)
          .getLatestIncomingMessageId(userId, phone);
      if (messagesSnapshot != null && messagesSnapshot.isNotEmpty) {
        // Fire-and-forget read receipt
        ref.read(whatsappRepositoryProvider).markMessageRead(
          userId: userId,
          messageId: messagesSnapshot,
        );
      }
    } catch (_) {
      // Silent — read receipts are non-critical
    }
  }



  // ============ VOICE RECORDING ============
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = (await getTemporaryDirectory()).path;
        // MUST use .ogg + Opus — WhatsApp only renders voice notes (waveform)
        // with ogg/opus format. AAC/m4a shows as plain [audio] attachment.
        final path = '$dir/voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 64000,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordPath = path;
          _recordDuration = Duration.zero;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
        });
      } else {
        if (mounted) WbSnackbar.showError(context, 'Microphone permission denied');
      }
    } catch (e) {
      if (mounted) WbSnackbar.showError(context, 'Failed to start recording');
    }
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (!ref.read(canSendMessageProvider)) {
      setState(() { _isRecording = false; _isSendingVoice = false; });
      _showSubscriptionExpiredDialog();
      return;
    }

    setState(() => _isSendingVoice = true);

    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);

      if (path == null || path.isEmpty) {
        WbSnackbar.showError(context, 'Recording failed');
        setState(() => _isSendingVoice = false);
        return;
      }

      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) WbSnackbar.showError(context, 'User not logged in');
        setState(() => _isSendingVoice = false);
        return;
      }

      // Upload via existing media flow
      final uploadResult = await ref.read(whatsappRepositoryProvider).uploadMedia(
        userId: user.id,
        filePath: path,
        mediaType: 'audio',
      );

      if (!mounted) return;
      if (!uploadResult.success || uploadResult.data?['url'] == null) {
        setState(() => _isSendingVoice = false);
        return;
      }

      final url = uploadResult.data!['url'] as String;
      final mediaId = uploadResult.data!['media_id'] as String?;

      final reply = _replyingTo;
      if (reply != null && mounted) setState(() => _replyingTo = null);
      ref.read(sendMessageProvider.notifier).sendMedia(
        contactPhone: widget.contactPhone,
        contactName: widget.contactName,
        mediaType: 'audio',
        mediaUrl: url,
        mediaId: mediaId,
        fileName: 'Voice message',
        isVoice: true, // ← Real WhatsApp voice note (waveform mic icon)
        replyToId: reply?.id,
        replyToBody: reply != null ? _replyPreview(reply) : null,
        replyToWamid: reply?.whatsappMessageId,
        replyToType: reply?.type.name,
      );
    } catch (e) {
      debugPrint('Voice send error: $e');
    } finally {
      if (mounted) setState(() => _isSendingVoice = false);
    }
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    if (_recordPath != null) {
      try { File(_recordPath!).deleteSync(); } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _recordPath = null;
      _recordDuration = Duration.zero;
    });
  }

  String _fmtRecordTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _audioRecorder.dispose();
    // Unlock conversation
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final ownerId = user.dataOwner ?? user.id;
      ref.read(messageRepositoryProvider).unlockConversation(
        ownerId, widget.contactPhone, user.id,
      );
    }
    // Clear active chat
    ref.read(activeChatPhoneProvider.notifier).state = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Debounce (350ms) + throttle (20s per wamid) outbound typing indicator.
  /// Meta scopes typing to a read receipt so we need a known inbound wamid.
  void _scheduleTypingIndicator() {
    final wamid = _lastInboundWamid;
    if (wamid == null || wamid.isEmpty) return;
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 350), () {
      final now = DateTime.now();
      if (_typingLastWamid == wamid &&
          _typingLastAt != null &&
          now.difference(_typingLastAt!).inSeconds < 20) {
        return;
      }
      _typingLastWamid = wamid;
      _typingLastAt = now;
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      ref.read(whatsappRepositoryProvider)
          .sendTypingIndicator(userId: user.id, messageId: wamid)
          .catchError((_) => WhatsappApiResponse.error('ignored'));
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (!ref.read(canSendMessageProvider)) {
      _showSubscriptionExpiredDialog();
      return;
    }

    _messageController.clear();
    final reply = _replyingTo;
    if (reply != null) setState(() => _replyingTo = null);
    ref.read(sendMessageProvider.notifier).sendText(
      contactPhone: widget.contactPhone,
      contactName: widget.contactName,
      text: text,
      replyToId: reply?.id,
      replyToBody: reply != null ? _replyPreview(reply) : null,
      replyToWamid: reply?.whatsappMessageId,
      replyToType: reply?.type.name,
    );
  }

  /// WhatsApp-style non-empty preview for the quoted message
  String _replyPreview(MessageModel m) {
    final text = m.body.trim().isNotEmpty ? m.body.trim() : (m.caption?.trim() ?? '');
    if (text.isNotEmpty) return text.length > 200 ? text.substring(0, 200) : text;
    switch (m.type) {
      case MessageType.image:    return '📷 Photo';
      case MessageType.sticker:  return '💟 Sticker';
      case MessageType.video:    return '🎥 Video';
      case MessageType.audio:    return '🎤 Voice message';
      case MessageType.document: return '📄 ${m.fileName ?? 'Document'}';
      case MessageType.location: return '📍 Location';
      case MessageType.contact:  return '👤 Contact';
      case MessageType.template: return '📋 Template';
      case MessageType.interactive: return '🔘 Interactive';
      case MessageType.button:   return '🔘 Button';
      case MessageType.order:    return '🛒 Order';
      default: return '[${m.type.name}]';
    }
  }

  void _showSubscriptionExpiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_outlined, color: AppColors.error, size: 44),
        title: const Text('Subscription Expired'),
        content: const Text(
          'Your subscription has expired or your monthly message limit has been reached.\n\n'
          'Please renew your plan to continue sending messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushNamed(RouteNames.plans);
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  void _resendMessage(String messageId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await ref.read(messageRepositoryProvider).resendMessage(
      userId: user.id,
      messageId: messageId,
    );
  }

  void _showErrorInfo(MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text('Message Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.errorReason ?? 'Unknown error — WhatsApp API returned an error.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              'Sent at: ${_formatDateTime(message.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _resendMessage(message.id);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Resend'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach File',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.image,
                    label: 'Image',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage();
                    },
                  ),
                  _AttachOption(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendFile('video');
                    },
                  ),
                  _AttachOption(
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendFile('document');
                    },
                  ),
                  _AttachOption(
                    icon: Icons.audiotrack,
                    label: 'Audio',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendFile('audio');
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.md),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick image from gallery and send
  Future<void> _pickAndSendImage() async {
    if (!ref.read(canSendMessageProvider)) {
      _showSubscriptionExpiredDialog();
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked == null) return;

      // Ask for optional caption
      final caption = await _askCaption();

      if (!mounted) return;
      WbSnackbar.showInfo(context, 'Uploading image...');

      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) WbSnackbar.showError(context, 'User not logged in');
        return;
      }

      // Upload to server + WhatsApp Cloud
      final uploadResult = await ref.read(whatsappRepositoryProvider).uploadMedia(
        userId: user.id,
        filePath: picked.path,
        mediaType: 'image',
      );

      if (!mounted) return;
      if (!uploadResult.success || uploadResult.data?['url'] == null) {
        WbSnackbar.showError(context, uploadResult.message ?? 'Upload failed');
        return;
      }

      final url = uploadResult.data!['url'] as String;
      final mediaId = uploadResult.data!['media_id'] as String?;

      // Send via messaging provider
      final reply = _replyingTo;
      if (reply != null && mounted) setState(() => _replyingTo = null);
      ref.read(sendMessageProvider.notifier).sendMedia(
        contactPhone: widget.contactPhone,
        contactName: widget.contactName,
        mediaType: 'image',
        mediaUrl: url,
        mediaId: mediaId,
        caption: caption,
        fileName: picked.name,
        replyToId: reply?.id,
        replyToBody: reply != null ? _replyPreview(reply) : null,
        replyToWamid: reply?.whatsappMessageId,
        replyToType: reply?.type.name,
      );
    } catch (e) {
      if (mounted) WbSnackbar.showError(context, 'Failed to pick image');
    }
  }

  /// Pick file (video/document/audio) and send
  Future<void> _pickAndSendFile(String mediaType) async {
    if (!ref.read(canSendMessageProvider)) {
      _showSubscriptionExpiredDialog();
      return;
    }
    try {
      FileType fileType;
      List<String>? allowedExtensions;
      switch (mediaType) {
        case 'video':
          fileType = FileType.video;
          break;
        case 'audio':
          fileType = FileType.audio;
          break;
        case 'document':
          fileType = FileType.custom;
          allowedExtensions = [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'txt',
          ];
          break;
        default:
          fileType = FileType.any;
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      // Ask for optional caption (not for audio)
      String? caption;
      if (mediaType != 'audio') {
        caption = await _askCaption();
      }

      if (!mounted) return;

      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) WbSnackbar.showError(context, 'User not logged in');
        return;
      }

      // Upload to server + WhatsApp Cloud
      final uploadResult = await ref.read(whatsappRepositoryProvider).uploadMedia(
        userId: user.id,
        filePath: file.path!,
        mediaType: mediaType,
      );

      if (!mounted) return;
      if (!uploadResult.success || uploadResult.data?['url'] == null) {
        return;
      }

      final url = uploadResult.data!['url'] as String;
      final mediaId = uploadResult.data!['media_id'] as String?;

      // Send via messaging provider
      final reply = _replyingTo;
      if (reply != null && mounted) setState(() => _replyingTo = null);
      ref.read(sendMessageProvider.notifier).sendMedia(
        contactPhone: widget.contactPhone,
        contactName: widget.contactName,
        mediaType: mediaType,
        mediaUrl: url,
        mediaId: mediaId,
        caption: caption,
        fileName: file.name,
        fileSize: file.size,
        replyToId: reply?.id,
        replyToBody: reply != null ? _replyPreview(reply) : null,
        replyToWamid: reply?.whatsappMessageId,
        replyToType: reply?.type.name,
      );
    } catch (e) {
      debugPrint('Media pick/send error: $e');
    }
  }

  /// Show dialog to optionally enter a caption
  Future<String?> _askCaption() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Caption'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Optional caption...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isEmpty) return null;
    return result;
  }

  void _showMessageActions(MessageModel message) {
    final user = ref.read(currentUserProvider);
    final userId = user?.id ?? '';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reaction emoji picker row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendReaction(message, emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.teal),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = message);
              },
            ),
            if (message.status == MessageStatus.failed) ...[
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: const Text('Resend'),
                onTap: () {
                  Navigator.pop(ctx);
                  _resendMessage(message.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.red),
                title: const Text('View Error'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showErrorInfo(message);
                },
              ),
            ],
            // Download option for media messages
            if (message.type.isMedia && (message.mediaUrl != null || message.mediaId != null))
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: const Text('Download'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadMedia(message, userId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.body));
                WbSnackbar.showSuccess(context, 'Copied!');
              },
            ),
            // NOTE: WhatsApp Business Cloud API does NOT support message unsend/delete.
            // API only accepts status: "read", not "deleted".
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(ctx);
                if (user != null) {
                  ref.read(messageRepositoryProvider).deleteMessage(user.id, message.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Unsend (delete for everyone) via WhatsApp API
  // ignore: unused_element
  Future<void> _unsendMessage(MessageModel message) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final wamid = message.whatsappMessageId;
    // Validate: real WhatsApp message IDs always start with "wamid."
    if (wamid == null || wamid.isEmpty || !wamid.startsWith('wamid.')) {
      WbSnackbar.showError(context, 'Cannot unsend: message ID not available');
      return;
    }

    WbSnackbar.showInfo(context, 'Unsending...');
    try {
      final result = await ref.read(whatsappRepositoryProvider).deleteMessage(
        userId: user.id,
        whatsappMessageId: wamid,
      );
      if (!mounted) return;
      if (result.success) {
        // Also delete locally (for me)
        await ref.read(messageRepositoryProvider).deleteMessage(user.id, message.id);
        if (mounted) WbSnackbar.showSuccess(context, 'Message unsent ✓');
      } else {
        if (mounted) WbSnackbar.showError(context, result.message ?? 'Could not unsend message');
      }
    } catch (e) {
      if (mounted) WbSnackbar.showError(context, 'Error: $e');
    }
  }

  /// Toggle a reaction (WhatsApp-style): tapping the same emoji removes it.
  /// Uses the PHP proxy (whatsappRepository.sendReaction) so we don't hit Meta directly.
  void _sendReaction(MessageModel message, String emoji) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ownerId = user.dataOwner ?? user.id;
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();

    // Find any existing outgoing reaction from this user on this message
    QuerySnapshot<Map<String, dynamic>>? existing;
    try {
      existing = await fs
          .collection('users').doc(ownerId)
          .collection('messages')
          .where('type', isEqualTo: 'reaction')
          .where('reactionMsgId', isEqualTo: message.id)
          .where('direction', isEqualTo: 'outgoing')
          .limit(5)
          .get();
    } catch (_) {}

    final sameEmojiExists = existing?.docs.any((d) => (d.data()['reactionEmoji'] ?? '') == emoji) ?? false;
    final outboundEmoji = sameEmojiExists ? '' : emoji; // '' removes on WhatsApp side

    // Update Firestore first (optimistic, mirrors what webhook would echo back)
    if (existing != null) {
      for (final d in existing.docs) {
        try { await d.reference.delete(); } catch (_) {}
      }
    }
    if (!sameEmojiExists) {
      final msgId = 'msg_${now.millisecondsSinceEpoch}';
      await fs
          .collection('users').doc(ownerId)
          .collection('messages').doc(msgId)
          .set({
        'contactPhone': message.contactPhone,
        'contactName': message.contactName,
        'type': 'reaction',
        'direction': 'outgoing',
        'status': 'sent',
        'body': emoji,
        'reactionEmoji': emoji,
        'reactionMsgId': message.id,
        'reactionAt': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Send to WhatsApp via PHP proxy (only if we have the wamid)
    final wamid = message.whatsappMessageId;
    if (wamid == null || wamid.isEmpty) return;
    try {
      await ref.read(whatsappRepositoryProvider).sendReaction(
        userId: ownerId,
        to: message.contactPhone.replaceAll('+', ''),
        messageId: wamid,
        emoji: outboundEmoji,
      );
    } catch (e) {
      debugPrint('Reaction error: $e');
    }
  }

  void _downloadMedia(MessageModel message, String userId) async {
    String? url;
    if (message.mediaId != null && message.mediaId!.isNotEmpty && userId.isNotEmpty) {
      url = 'https://api.wabees.live/media-proxy.php?id=${Uri.encodeComponent(message.mediaId!)}&uid=${Uri.encodeComponent(userId)}';
    } else if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      url = message.mediaUrl;
    }

    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Media not available'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Build filename
    final ext = message.fileName?.contains('.') == true
        ? '.${message.fileName!.split('.').last}'
        : _extensionForType(message.type.name);
    final safeFileName = message.fileName ?? 'media_${DateTime.now().millisecondsSinceEpoch}$ext';

    // Show downloading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 12),
              Text('Downloading $safeFileName...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );
    }

    try {
      // Download to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$safeFileName';

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ));

      await dio.download(url, tempPath);

      // Verify file was downloaded
      final file = File(tempPath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Download failed - empty file');
      }

      // Clear downloading snackbar
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Auto-open the downloaded file
      final result = await OpenFilex.open(tempPath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Downloaded: $safeFileName'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Download failed: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _extensionForType(String type) {
    switch (type) {
      case 'image': return '.jpg';
      case 'video': return '.mp4';
      case 'audio': return '.m4a';
      case 'document': return '.pdf';
      default: return '';
    }
  }

  // ============ CALL INITIATION ============
  void _initiateCall(String contactName, String contactPhone, {String callType = 'voice'}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final callRepo = CallRepository();
    final userId = user.id; // _resolveConfig handles dataOwner internally

    // Check call permission first
    final permResult = await callRepo.checkCallPermission(
      userId: userId,
      contactPhone: contactPhone,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (permResult['canCall'] == true) {
      // Has permission — init WebRTC, generate SDP offer, then call API
      WebRTCService? webrtc;
      String? sdpOffer;
      try {
        webrtc = WebRTCService();
        await webrtc.initialize();
        sdpOffer = await webrtc.createOffer();
        ref.read(activeWebRTCProvider.notifier).state = webrtc;
      } catch (e) {
        debugPrint('[CHAT] WebRTC init failed: $e');
        webrtc?.dispose();
        webrtc = null;
        if (mounted) {
          final errMsg = e.toString().toLowerCase();
          final msg = errMsg.contains('permission') || errMsg.contains('denied') || errMsg.contains('notallowed')
              ? 'Microphone access denied. Please grant microphone permission in device Settings and try again.'
              : 'Could not access microphone. Make sure no other app is using it and try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
          );
        }
        return;
      }

      final result = await callRepo.initiateCall(
        userId: userId,
        contactPhone: contactPhone,
        contactName: contactName,
        callType: callType,
        sdpOffer: sdpOffer,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        if (!mounted) return;
        // Extract SDP answer from Meta response (may be in data.session.sdp)
        final sdpAnswer = (result['data'] as Map<String, dynamic>?)
            ?['session']?['sdp'] as String?;
        context.pushNamed('in-call', extra: {
          'callId': result['callId'] ?? '',
          'contactName': contactName,
          'contactPhone': contactPhone,
          'isIncoming': false,
          'callType': callType,
          'ownerId': result['ownerId'] ?? '',
          'sdpAnswer': sdpAnswer,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // No permission — offer to send request
      final _ = permResult['reason'] ?? 'Permission required';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Call Permission Required'),
          content: Text(
            'You need permission to call $contactName.\n\n'
            'Would you like to send a call permission request?\n\n'
            'Once they accept, you can call them for 7 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final success = await callRepo.requestCallPermission(
                  userId: userId,
                  contactPhone: contactPhone,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '✅ Call permission request sent'
                        : '❌ Failed to send permission request. Make sure calling is enabled in WhatsApp Manager.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      if (_showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedPhoneForProviders = PhoneUtils.normalize(widget.contactPhone);
    final messagesAsync = ref.watch(chatMessagesProvider(normalizedPhoneForProviders));
    final sendState = ref.watch(sendMessageProvider);
    final convDetailAsync = ref.watch(conversationDetailProvider(normalizedPhoneForProviders));
    final theme = Theme.of(context);
    // CRITICAL: watch so userId reacts to auth state — never empty after login
    final userId = ref.watch(currentUserProvider)?.id ?? '';

    // FIX: Check for lastIncomingMessageAt consistency and repair if needed
    ref.listen(chatMessagesProvider(normalizedPhoneForProviders), (prev, next) {
      // Play notification beep ONLY for genuinely new real-time messages
      // _ringReady is false for 2s after chat opens to prevent ring on initial load
      if (_ringReady && prev?.hasValue == true && next.hasValue) {
        final oldLen = prev!.value!.length;
        final newLen = next.value!.length;
        if (newLen > oldLen) {
          final latestMsg = next.value!.last;
          if (latestMsg.direction.isIncoming) {
            // Play ring.mp3 notification sound (fire-and-forget)
            try {
              final notifPlayer = AudioPlayer();
              notifPlayer.setAsset('assets/sounds/ring.mp3').then((_) {
                notifPlayer.play();
                notifPlayer.playerStateStream.listen((state) {
                  if (state.processingState == ProcessingState.completed) {
                    notifPlayer.dispose();
                  }
                });
              });
            } catch (_) {}
            HapticFeedback.mediumImpact();
          }
        }
      }
      if (next.hasValue && next.value!.isNotEmpty) {
        final messages = next.value!;
        DateTime? lastIncoming;

        // Find the latest incoming message that actually opens Meta's 24h window.
        // Reactions, system events, templates, unsupported and stickers do NOT
        // open a customer service window — using them would show a "window open"
        // banner while Meta still rejects free-form sends with error 131047.
        const windowOpeningTypes = <MessageType>{
          MessageType.text,
          MessageType.image,
          MessageType.video,
          MessageType.audio,
          MessageType.document,
          MessageType.location,
          MessageType.contact,
          MessageType.interactive,
          MessageType.button,
          MessageType.order,
        };
        for (final m in messages.reversed) {
          if (m.direction.isIncoming && windowOpeningTypes.contains(m.type)) {
            lastIncoming = m.createdAt;
            break;
          }
        }

        if (lastIncoming != null) {
          final conv = ref.read(conversationDetailProvider(normalizedPhoneForProviders)).valueOrNull;
          final now = DateTime.now();
          final isRecent = now.difference(lastIncoming).inHours < 24;

          if (conv == null ||
              conv.lastIncomingMessageAt == null ||
              (isRecent && conv.lastIncomingMessageAt!.isBefore(lastIncoming.subtract(const Duration(seconds: 1))))) {
            final user = ref.read(currentUserProvider);
            if (user != null) {
              // Always write on the OWNER's conversation doc so agents & owner stay in sync.
              final ownerId = user.dataOwner ?? user.id;
              ref.read(messageRepositoryProvider).updateLastIncomingMessageTime(
                ownerId,
                normalizedPhoneForProviders,
                lastIncoming,
              );
              ref.invalidate(conversationDetailProvider(normalizedPhoneForProviders));
            }
          }
        }
      }
      
      // Also mark as read (use ownerId for agents)
      final user = ref.read(currentUserProvider);
      if (user != null && next.hasValue && next.value!.isNotEmpty) {
        final ownerId = user.dataOwner ?? user.id;
        ref.read(messageRepositoryProvider).markConversationRead(
          ownerId,
          widget.contactPhone,
        );
        _sendReadReceipt(ownerId);
      }
    });

    ref.listen(sendMessageProvider, (prev, next) {
      if (next.error != null) {
        WbSnackbar.showError(context, next.error!);
        ref.read(sendMessageProvider.notifier).clearError();
      }
    });

    // Listen removed here as we combined it above
    
    final conv = convDetailAsync.valueOrNull;
    final isBlocked = conv?.isBlocked ?? false;
    final headerName = conv?.contactName ?? widget.contactName;
    final headerPhone = PhoneUtils.normalize(conv?.contactPhone ?? widget.contactPhone);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headerName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              headerPhone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Show tags for this conversation
            if (convDetailAsync.valueOrNull?.tags.isNotEmpty == true)
              Builder(builder: (_) {
                final tags = convDetailAsync.valueOrNull!.tags;
                final tagsAsync = ref.watch(userTagsProvider);
                final tagColorMap = <String, Color>{};
                tagsAsync.whenData((tList) {
                  for (final t in tList) {
                    final name = t['name'] ?? '';
                    final c = t['color'];
                    if (c is String && c.startsWith('#') && c.length >= 7) {
                      try { tagColorMap[name] = Color(int.parse('FF${c.substring(1)}', radix: 16)); } catch (_) {}
                    }
                  }
                });
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 4,
                    children: tags.map((t) {
                      final color = tagColorMap[t] ?? AppColors.primary;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withAlpha(80), width: 0.5),
                        ),
                        child: Text(t, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                );
              }),
          ],
        ),
        actions: [
          // Voice call button
          if (!isBlocked)
            IconButton(
              icon: const Icon(Icons.phone_rounded),
              tooltip: 'Voice Call',
              onPressed: () => _initiateCall(headerName, headerPhone),
            ),
          // More options menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'block' || value == 'unblock') {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final ownerId = user.dataOwner ?? user.id;
                final newVal = value == 'block';
                final messenger = ScaffoldMessenger.of(context);
                await FirebaseFirestore.instance
                    .collection('users').doc(ownerId)
                    .collection('conversations').doc(widget.contactPhone)
                    .update({'isBlocked': newVal});
                if (mounted) {
                  WbSnackbar.showSuccessWithState(messenger, newVal ? 'Contact blocked' : 'Contact unblocked');
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: isBlocked ? 'unblock' : 'block',
                child: Row(
                  children: [
                    Icon(
                      isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: isBlocked ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(isBlocked ? 'Unblock Contact' : 'Block Contact'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List + Scroll-to-bottom FAB
          Expanded(
            child: Stack(
              children: [
                messagesAsync.when(
              loading: () => const WbLoading(message: 'Loading messages...'),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allMessages) {
                // Client-side pagination: show only last N messages
                final messages = allMessages.length > _messageLimit
                    ? allMessages.sublist(allMessages.length - _messageLimit)
                    : allMessages;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: theme.colorScheme.onSurface.withAlpha(60),
                        ),
                        const SizedBox(height: AppDimens.sm),
                        Text(
                          'No messages yet\nSend a message to start the conversation',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll: on first load jump to bottom, then only if near bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    if (!_initialScrollDone) {
                      _initialScrollDone = true;
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      // Extra delayed scroll to catch async content (images, audio)
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                        }
                      });
                      Future.delayed(const Duration(milliseconds: 800), () {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                        }
                      });
                    } else {
                      final pos = _scrollController.position;
                      final isNearBottom = pos.maxScrollExtent - pos.pixels < 150;
                      if (isNearBottom) _scrollToBottom();
                    }
                  }
                });

                // Build reaction map (reactionMsgId → emoji) and filter reactions out
                final reactionMap = <String, String>{};
                final displayMessages = <MessageModel>[];
                String? latestInboundWamid;
                for (final m in messages) {
                  if (m.type == MessageType.reaction && m.reactionMsgId != null) {
                    reactionMap[m.reactionMsgId!] = m.reactionEmoji ?? '❤️';
                  } else {
                    displayMessages.add(m);
                  }
                  if (m.direction.isIncoming &&
                      m.whatsappMessageId != null &&
                      m.whatsappMessageId!.isNotEmpty) {
                    latestInboundWamid = m.whatsappMessageId;
                  }
                }
                if (latestInboundWamid != _lastInboundWamid) {
                  // Update outside of build to avoid nested setState during build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _lastInboundWamid = latestInboundWamid;
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppDimens.md),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final msg = displayMessages[index];
                    final isMe = msg.direction.isOutgoing;
                    final msgReaction = reactionMap[msg.id];

                    Widget? dateSeparator;
                    if (index == 0 ||
                        !_isSameDay(
                          displayMessages[index - 1].createdAt,
                          msg.createdAt,
                        )) {
                      dateSeparator = _DateSeparator(date: msg.createdAt);
                    }

                    return Column(
                      children: [
                        if (dateSeparator != null) dateSeparator,
                        GestureDetector(
                          onLongPress: () => _showMessageActions(msg),
                          child: _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            userId: userId,
                            onResend: () => _resendMessage(msg.id),
                            onErrorInfo: () => _showErrorInfo(msg),
                            reactionEmoji: msgReaction,
                          ),
                        ),
                      ],
                    );
                    },
                  );
                },
              ),
                // ── Scroll-to-bottom FAB (WhatsApp style) ──
                if (_showScrollToBottom)
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: AnimatedOpacity(
                      opacity: _showScrollToBottom ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Material(
                        elevation: 4,
                        shape: const CircleBorder(),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _scrollToBottom,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ============ 24H REPLY WINDOW BANNER ============
          convDetailAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (conv) {
              DateTime? lastIncoming = conv?.lastIncomingMessageAt;
              final msgs = messagesAsync.valueOrNull;
              if (lastIncoming == null && msgs != null && msgs.isNotEmpty) {
                for (final m in msgs.reversed) {
                  if (m.direction.isIncoming) {
                    lastIncoming = m.createdAt;
                    break;
                  }
                }
              }

              final now = DateTime.now();
              final diff = lastIncoming != null ? now.difference(lastIncoming) : const Duration(days: 999);
              final isOpen = diff.inHours < 24;

              if (!isOpen) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.sm,
                  ),
                  color: AppColors.error.withAlpha(20),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off, size: 16, color: AppColors.error),
                      const SizedBox(width: AppDimens.xs),
                      Expanded(
                        child: Text(
                          'Reply window expired — Use templates only',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final deadline = (lastIncoming ?? now).add(const Duration(hours: 24));
              final remaining = deadline.difference(now);
              final totalMinutes = remaining.inMinutes.clamp(0, 24 * 60);
              final hours = totalMinutes ~/ 60;
              final minutes = totalMinutes % 60;
              final remainingText = hours > 0
                  ? '${hours}h ${minutes}m'
                  : '${minutes}m';
              final isUrgent = hours < 4;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md,
                  vertical: AppDimens.xs,
                ),
                color:
                    isUrgent ? AppColors.warning.withAlpha(20) : AppColors.info.withAlpha(15),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isUrgent ? AppColors.warning : AppColors.info,
                    ),
                    const SizedBox(width: AppDimens.xxs),
                    Text(
                      'Free reply window: $remainingText remaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isUrgent ? AppColors.warning : AppColors.info,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ============ CONVERSATION LOCK BANNER ============
          Builder(builder: (_) {
            final conv = convDetailAsync.valueOrNull;
            final currentUserId = ref.read(currentUserProvider)?.id ?? '';
            final lockedBy = conv?.activeChatterId;
            final lockedByEmail = conv?.activeChatterEmail;
            final isLockedByOther = lockedBy != null &&
                lockedBy.isNotEmpty &&
                lockedBy != currentUserId;

            if (isLockedByOther) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🔒 ${lockedByEmail ?? 'Another agent'} is chatting with this contact. You cannot send messages now.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Input Bar — with voice recording
          // Only show if not locked by another user
          Builder(builder: (_) {
            final conv = convDetailAsync.valueOrNull;
            final currentUserId = ref.read(currentUserProvider)?.id ?? '';
            final lockedBy = conv?.activeChatterId;
            final isLockedByOther = lockedBy != null &&
                lockedBy.isNotEmpty &&
                lockedBy != currentUserId;

            if (isLockedByOther) return const SizedBox.shrink();

            if (_isRecording) {
              return Container(
                padding: const EdgeInsets.all(AppDimens.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _cancelRecording,
                        icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 28),
                        tooltip: 'Cancel',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(15),
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                            border: Border.all(color: Colors.redAccent.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Recording  ${_fmtRecordTime(_recordDuration)}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Slide to cancel',
                                style: TextStyle(
                                  color: Colors.redAccent.withAlpha(120),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        onPressed: _isSendingVoice ? null : _stopAndSendVoice,
                        backgroundColor: AppColors.primary,
                        child: _isSendingVoice
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show blocked banner instead of input when contact is blocked
            if (isBlocked) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.sm),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(15),
                  border: Border(top: BorderSide(color: Colors.red.withAlpha(40))),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      const Text('Contact Blocked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          final ownerId = user.dataOwner ?? user.id;
                          await FirebaseFirestore.instance
                              .collection('users').doc(ownerId)
                              .collection('conversations').doc(widget.contactPhone)
                              .update({'isBlocked': false});
                          // ignore: use_build_context_synchronously
                          if (mounted) WbSnackbar.showSuccess(context, 'Contact unblocked');
                        },
                        child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(AppDimens.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          border: Border(
                            left: BorderSide(color: AppColors.primary, width: 3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _replyingTo!.direction.isOutgoing ? 'You' : _replyingTo!.contactName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _replyPreview(_replyingTo!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _replyingTo = null),
                              tooltip: 'Cancel reply',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showAttachmentOptions,
                      icon: Icon(
                        Icons.attach_file,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.md,
                            vertical: AppDimens.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.xs),
                    if (_hasText || sendState.isSending)
                      FloatingActionButton.small(
                        onPressed: sendState.isSending ? null : _sendMessage,
                        child: sendState.isSending
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                      )
                    else
                      GestureDetector(
                        onLongPress: _startRecording,
                        child: FloatingActionButton.small(
                          onPressed: _startRecording,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.mic, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }
}

/// Check if body text is just a media type label from webhook
bool _isMediaLabel(String body) {
  final lc = body.trim().toLowerCase();
  return lc == '[image]' || lc == '[video]' || lc == '[audio]' ||
      lc == '[document]' || lc == '[sticker]' || lc == 'image' ||
      lc == 'video' || lc == 'audio' || lc == 'document' || lc == 'sticker' ||
      lc.isEmpty;
}

// ============ ATTACHMENT OPTION ============
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: AppDimens.xxs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ============ MESSAGE BUBBLE ============
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String userId;
  final VoidCallback onResend;
  final VoidCallback onErrorInfo;
  final String? reactionEmoji;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.userId,
    required this.onResend,
    required this.onErrorInfo,
    this.reactionEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = message.status == MessageStatus.failed;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Error/Resend icon (left of bubble for my failed messages)
          if (isMe && isFailed)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: GestureDetector(
                onTap: onErrorInfo,
                child: const Tooltip(
                  message: 'Tap for error details',
                  child: Icon(Icons.info_outline, color: Colors.red, size: 20),
                ),
              ),
            ),
          // Bubble
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: reactionEmoji != null ? 12 : AppDimens.xxs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.sm,
              vertical: AppDimens.xs,
            ),
            decoration: BoxDecoration(
              color: isFailed
                  ? Colors.red.withAlpha(30)
                  : isMe
                      ? AppColors.primary.withAlpha(230)
                      : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppDimens.radiusMd),
                topRight: const Radius.circular(AppDimens.radiusMd),
                bottomLeft: isMe
                    ? const Radius.circular(AppDimens.radiusMd)
                    : const Radius.circular(AppDimens.radiusXs),
                bottomRight: isMe
                    ? const Radius.circular(AppDimens.radiusXs)
                    : const Radius.circular(AppDimens.radiusMd),
              ),
              border: isFailed
                  ? Border.all(color: Colors.red.withAlpha(80))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.type.isMedia ||
                    message.type == MessageType.sticker ||
                    message.type == MessageType.location ||
                    message.type == MessageType.contact)
                  _MediaIndicator(message: message, isMe: isMe, userId: userId),

                // Message Body (+ optional header/footer for interactive)
                if (message.type == MessageType.interactive &&
                    (message.headerText != null && message.headerText!.isNotEmpty)) ...[
                  Text(
                    message.headerText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isFailed
                          ? Colors.red.shade700
                          : isMe
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Reaction: filtered out from list, shown as overlay
                if (_isMediaLabel(message.body) && message.type.isMedia) ...[
                  // Hide ugly [image], [video], [audio] etc. labels for media messages
                ] else ...[
                  Linkify(
                    text: message.body,
                    onOpen: (link) => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isFailed
                          ? Colors.red.shade700
                          : isMe
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                    ),
                    linkStyle: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                if (message.type == MessageType.interactive &&
                    (message.footerText != null && message.footerText!.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.footerText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],

                const SizedBox(height: 2),

                // Quick reply buttons/CTA preview (non-interactive tap in app)
                if (message.type == MessageType.interactive &&
                    ((message.quickReplies != null && message.quickReplies!.isNotEmpty) ||
                     (message.ctaButton != null && message.ctaButton!.isNotEmpty))) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (message.quickReplies != null)
                        ...message.quickReplies!.map((qr) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: isMe ? Colors.white70 : AppColors.primary),
                                borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                              ),
                              child: Text(
                                (qr['title'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isMe ? Colors.white : AppColors.primary,
                                ),
                              ),
                            )),
                      if (message.ctaButton != null && message.ctaButton!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isMe ? Colors.white : AppColors.info).withAlpha(20),
                            border: Border.all(color: isMe ? Colors.white70 : AppColors.info),
                            borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new, size: 14, color: isMe ? Colors.white70 : AppColors.info),
                              const SizedBox(width: 4),
                              Text(
                                (message.ctaButton!['title'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isMe ? Colors.white : AppColors.info,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],

                // Time + Status + Resend
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isFailed
                            ? Colors.red.shade400
                            : isMe
                                ? Colors.white.withAlpha(180)
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      if (isFailed)
                        GestureDetector(
                          onTap: onResend,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 14, color: Colors.red.shade600),
                              const SizedBox(width: 2),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _StatusIcon(status: message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
                // Reaction emoji overlay badge
                if (reactionEmoji != null)
                  Positioned(
                    bottom: 0,
                    right: isMe ? 8 : null,
                    left: isMe ? null : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(80),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        reactionEmoji!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

// ============ MEDIA INDICATOR ============
class _MediaIndicator extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String userId;

  const _MediaIndicator({required this.message, required this.isMe, required this.userId});

  /// Build a usable URL — ALWAYS prefer proxy from mediaId (persistent)
  /// Stored mediaUrl may be a broken local file URL from Cloud Run
  String? get _resolvedUrl {
    // If we have mediaId, ALWAYS use proxy URL (guaranteed to work)
    if (message.mediaId != null && message.mediaId!.isNotEmpty && userId.isNotEmpty) {
      return 'https://api.wabees.live/media-proxy.php?id=${Uri.encodeComponent(message.mediaId!)}&uid=${Uri.encodeComponent(userId)}';
    }
    // Fallback: use stored mediaUrl (for sent messages that have URL but no mediaId)
    if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) return message.mediaUrl;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    // Show actual media preview if URL is available (direct or proxy)
    if (url != null && url.isNotEmpty) {
      switch (message.type) {
        case MessageType.image:
          return _buildImagePreview(context, url);
        case MessageType.video:
          return _buildVideoPreview(context, url);
        case MessageType.document:
          return _buildDocumentCard(context, url);
        case MessageType.audio:
          return _buildAudioCard(context, url);
        case MessageType.sticker:
          return _buildStickerPreview(context, url);
        default:
          break;
      }
    }

    // Fallback: icon + label for media without URL
    IconData icon;
    String label;

    switch (message.type) {
      case MessageType.image:
        icon = Icons.image;
        label = 'Photo';
      case MessageType.video:
        icon = Icons.videocam;
        label = 'Video';
      case MessageType.audio:
        icon = Icons.audiotrack;
        label = 'Audio';
      case MessageType.document:
        icon = Icons.insert_drive_file;
        label = message.fileName ?? 'Document';
      case MessageType.location:
        icon = Icons.location_on;
        label = 'Location';
      case MessageType.contact:
        icon = Icons.person;
        label = 'Contact';
      case MessageType.sticker:
        icon = Icons.emoji_emotions;
        label = 'Sticker';
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.xs,
        vertical: AppDimens.xxs,
      ),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white : AppColors.primary).withAlpha(20),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isMe ? Colors.white70 : AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _showFullImage(context, url),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.xs),
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(
              color: (isMe ? Colors.white : AppColors.primary).withAlpha(15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: const Center(
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 200,
            height: 80,
            decoration: BoxDecoration(
              color: (isMe ? Colors.white : AppColors.primary).withAlpha(15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 18, color: isMe ? Colors.white60 : AppColors.primary),
                const SizedBox(width: 4),
                Text('Image', style: TextStyle(fontSize: 12, color: isMe ? Colors.white60 : AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerPreview(BuildContext context, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.xs),
      constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(
          width: 80,
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.emoji_emotions,
          size: 40,
          color: isMe ? Colors.white60 : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildVideoPreview(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.xs),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isMe ? Colors.white : AppColors.primary).withAlpha(20),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, size: 18, color: isMe ? Colors.white : Colors.red),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : null,
                  ),
                ),
                if (message.fileName != null)
                  Text(
                    message.fileName!,
                    style: TextStyle(fontSize: 11, color: isMe ? Colors.white60 : Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _downloadFile(context, url, message.fileName ?? 'Document'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.xs),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (isMe ? Colors.white : AppColors.primary).withAlpha(20),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, size: 22, color: isMe ? Colors.white70 : Colors.blue),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'Document',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.fileSize != null)
                    Text(
                      _formatFileSize(message.fileSize!),
                      style: TextStyle(fontSize: 11, color: isMe ? Colors.white60 : Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Download file to device then open it
  Future<void> _downloadFile(BuildContext ctx, String url, String fileName) async {
    try {
      // Use app temp directory (no permissions needed)
      final tempDir = await getTemporaryDirectory();
      
      // Extract extension from URL
      final uri = Uri.parse(url);
      final urlFileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : fileName;
      final ext = urlFileName.contains('.') ? '.${urlFileName.split('.').last}' : '';
      final safeFileName = fileName.contains('.') ? fileName : '$fileName$ext';
      final filePath = '${tempDir.path}/$safeFileName';

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Downloading $safeFileName...'), duration: const Duration(seconds: 2)),
      );

      final dio = Dio();
      await dio.download(url, filePath);

      // Open file using open_filex (handles Android FileProvider properly)
      await OpenFilex.open(filePath);
    } catch (e) {
      // Fallback: open URL in browser
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildAudioCard(BuildContext context, String url) {
    return _AudioPlayerWidget(
      url: url,
      isMe: isMe,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ STATUS ICON ============
class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time, size: 14, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: Colors.blue.shade200);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
    }
  }
}

// ============ DATE SEPARATOR ============
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ============ INLINE AUDIO PLAYER ============
class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final bool isMe;

  const _AudioPlayerWidget({required this.url, required this.isMe});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isLoading = false;
  bool _hasError = false;
  bool _initialized = false;
  // ignore: prefer_final_fields — mutable for seek gesture control
  bool _isSeeking = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  late List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Generate pseudo-random waveform from URL hash
    final seed = widget.url.hashCode;
    _waveformHeights = List.generate(28, (i) {
      return 0.3 + ((seed * (i + 1) * 7) % 100) / 140.0;
    });
    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });
    _player.positionStream.listen((p) {
      if (mounted && !_isSeeking) setState(() => _position = p);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        // Auto-reset to start when playback completes
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
          setState(() => _position = Duration.zero);
        } else {
          setState(() {});
        }
      }
    });
    // Pre-load audio URL so playback is instant
    _preloadAudio();
  }

  Future<void> _preloadAudio() async {
    try {
      await _player.setUrl(widget.url);
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('Audio preload failed: $e — retrying...');
      try {
        await _player.setUrl(widget.url);
        if (mounted) setState(() { _initialized = true; _hasError = false; });
      } catch (e2) {
        debugPrint('Audio preload retry failed: $e2');
        if (mounted) setState(() => _hasError = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _initialized = false;
      _hasError = false;
      _preloadAudio();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_hasError) {
      setState(() { _hasError = false; _initialized = false; });
      await _preloadAudio();
      if (_hasError) return;
    }
    if (!_initialized) {
      setState(() => _isLoading = true);
      await _preloadAudio();
      if (mounted) setState(() => _isLoading = false);
      if (_hasError || !_initialized) return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    _player.setSpeed(_speed);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _player.playing;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final accentColor = widget.isMe ? Colors.white : const Color(0xFF25D366);
    final dimColor = widget.isMe ? Colors.white54 : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.xs),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: (widget.isMe ? Colors.white : AppColors.primary).withAlpha(15),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _isLoading ? null : _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(widget.isMe ? 40 : 255),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMe ? accentColor : Colors.white,
                      ),
                    )
                  : _hasError
                      ? Icon(Icons.refresh, size: 22, color: Colors.red.shade300)
                      : Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 24,
                          color: widget.isMe ? accentColor : Colors.white,
                        ),
            ),
          ),
          const SizedBox(width: 8),
          // Waveform + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform visualization bars
                SizedBox(
                  height: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(_waveformHeights.length, (i) {
                      final barProgress = (i + 1) / _waveformHeights.length;
                      final isActive = barProgress <= progress;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          height: 28 * _waveformHeights[i],
                          decoration: BoxDecoration(
                            color: isActive ? accentColor : dimColor.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                // Time + Speed toggle
                Row(
                  children: [
                    Text(
                      _duration.inMilliseconds > 0
                          ? '${_fmt(_position)} / ${_fmt(_duration)}'
                          : 'Audio',
                      style: TextStyle(
                        fontSize: 10,
                        color: dimColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(widget.isMe ? 30 : 20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_speed}x',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
