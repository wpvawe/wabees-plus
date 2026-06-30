import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/utils/validators/phone_validator.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/messaging/messaging_provider.dart';

/// ✉️ NEW MESSAGE SCREEN
class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    // Normalize phone: strip whitespace/dashes, ensure + prefix
    String phone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.isNotEmpty && phone[0] != '+') phone = '+$phone';

    final name = _nameController.text.trim().isEmpty
        ? phone
        : _nameController.text.trim();
    final text = _messageController.text.trim();

    final success = await ref.read(sendMessageProvider.notifier).sendText(
      contactPhone: phone,
      contactName: name,
      text: text,
    );

    if (success && mounted) {
      // Navigate to chat
      context.pushReplacementNamed(
        RouteNames.chat,
        pathParameters: {'phone': phone},
        extra: name,
      );
    } else if (mounted) {
      WbSnackbar.showError(context, 'Failed to send message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(sendMessageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
      ),
      body: SingleChildScrollView(
        padding: AppDimens.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimens.md),

              // Phone Number
              WbTextField(
                label: 'Phone Number',
                hint: '+923001234567',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: PhoneValidator.validate,
                prefixIcon: const Icon(Icons.phone),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              // Contact Name (optional)
              WbTextField(
                label: 'Contact Name',
                hint: 'Optional — will use phone number if empty',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person),
                isRequired: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              // Message
              WbTextField(
                label: 'Message',
                hint: 'Type your message...',
                controller: _messageController,
                maxLines: 5,
                prefixIcon: const Icon(Icons.message),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Message is required';
                  }
                  return null;
                },
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppDimens.xl),

              // Send Button
              WbButton(
                text: 'Send Message',
                onPressed: _send,
                isLoading: sendState.isSending,
                icon: Icons.send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
