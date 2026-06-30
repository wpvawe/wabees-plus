import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/whatsapp_repository.dart';
import '../whatsapp/whatsapp_provider.dart';

// ============ SETUP STATE ============

/// State machine: token → connecting → done
enum SetupStep { token, connecting, done, error }

class SetupState {
  final SetupStep step;
  final bool isLoading;
  final String? statusMessage;
  final String? error;

  // Token input
  final String? accessToken;
  final String? phoneNumberId;

  // Discovered data
  final String? wabaId;
  final String? businessId;
  final String? businessName;
  final String? verifiedName;
  final String? displayPhoneNumber;
  final String? qualityRating;

  const SetupState({
    this.step = SetupStep.token,
    this.isLoading = false,
    this.statusMessage,
    this.error,
    this.accessToken,
    this.phoneNumberId,
    this.wabaId,
    this.businessId,
    this.businessName,
    this.verifiedName,
    this.displayPhoneNumber,
    this.qualityRating,
  });

  SetupState copyWith({
    SetupStep? step,
    bool? isLoading,
    String? statusMessage,
    String? error,
    String? accessToken,
    String? phoneNumberId,
    String? wabaId,
    String? businessId,
    String? businessName,
    String? verifiedName,
    String? displayPhoneNumber,
    String? qualityRating,
  }) {
    return SetupState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error ?? this.error,
      accessToken: accessToken ?? this.accessToken,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      wabaId: wabaId ?? this.wabaId,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      verifiedName: verifiedName ?? this.verifiedName,
      displayPhoneNumber: displayPhoneNumber ?? this.displayPhoneNumber,
      qualityRating: qualityRating ?? this.qualityRating,
    );
  }
}

// ============ PROVIDER ============

final whatsappSetupProvider =
    StateNotifierProvider.autoDispose<WhatsappSetupNotifier, SetupState>(
  (ref) => WhatsappSetupNotifier(ref.watch(whatsappRepositoryProvider)),
);

class WhatsappSetupNotifier extends StateNotifier<SetupState> {
  final WhatsappRepository _repo;
  String _userId = '';

  WhatsappSetupNotifier(this._repo) : super(const SetupState());

  // ── Step 1: Start smart connect ──
  Future<void> startSmartConnect({
    required String token,
    required String phoneId,
    required String userId,
  }) async {
    _userId = userId;
    state = state.copyWith(
      step: SetupStep.connecting,
      isLoading: true,
      accessToken: token.trim(),
      phoneNumberId: phoneId.trim(),
      statusMessage: 'Verifying credentials & detecting account...',
      error: null,
    );

    try {
      final result = await _repo.smartConnect(
        accessToken: token.trim(),
        phoneNumberId: phoneId.trim(),
      );

      if (result == null) {
        state = state.copyWith(
          step: SetupStep.error,
          isLoading: false,
          error: 'Failed to connect. Check your Access Token and Phone Number ID.',
        );
        return;
      }

      final phoneData = result['phone'] as Map<String, dynamic>? ?? {};
      final wabaId = (result['waba_id'] ?? '').toString();
      final businessId = (result['business_id'] ?? '').toString();
      final businessName = (result['business_name'] ?? '').toString();

      state = state.copyWith(
        phoneNumberId: phoneId.trim(),
        wabaId: wabaId,
        businessId: businessId,
        businessName: businessName,
        verifiedName: (phoneData['verified_name'] ?? '').toString(),
        displayPhoneNumber: (phoneData['display_phone_number'] ?? '').toString(),
        qualityRating: (phoneData['quality_rating'] ?? '').toString(),
        statusMessage: 'Verified! ${phoneData['verified_name'] ?? 'Phone connected'}',
      );

      // Save config and finish
      await _saveAndFinish();
    } catch (e) {
      state = state.copyWith(
        step: SetupStep.error,
        isLoading: false,
        error: 'Connection error: $e',
      );
    }
  }

  // ── Save config and finish ──
  Future<void> _saveAndFinish() async {
    try {
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Saving configuration...',
      );

      await _repo.saveSetupConfig(
        userId: _userId,
        accessToken: state.accessToken!,
        phoneNumberId: state.phoneNumberId!,
        wabaId: state.wabaId ?? '',
      );

      state = state.copyWith(
        step: SetupStep.done,
        isLoading: false,
        statusMessage: 'Connected successfully! 🎉',
      );
    } catch (e) {
      state = state.copyWith(
        step: SetupStep.error,
        isLoading: false,
        error: 'Failed to save: $e',
      );
    }
  }

  // ── Go back ──
  void goBack() {
    switch (state.step) {
      case SetupStep.error:
      case SetupStep.connecting:
        state = const SetupState();
        break;
      default:
        break;
    }
  }

  // ── Reset ──
  void reset() => state = const SetupState();
}
