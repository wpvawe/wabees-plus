import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/campaign/campaign_model.dart';
import '../../data/models/campaign/campaign_status.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../data/repositories/whatsapp_repository.dart';
import '../../services/campaign_execution_service.dart';
import '../../services/campaign_scheduler_service.dart';
import '../../services/anti_ban_service.dart';
import '../auth/auth_provider.dart';
import '../plans/plan_provider.dart';

// ============ REPOSITORY ============
final campaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return CampaignRepository();
});

// ============ CAMPAIGNS LIST (REALTIME) ============
final campaignsProvider = StreamProvider<List<CampaignModel>>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value([]);

  final repo = ref.watch(campaignRepositoryProvider);
  return repo.getCampaigns(userId);
});

// ============ ACTIVE CAMPAIGNS (RUNNING — REALTIME) ============
final activeCampaignsProvider = StreamProvider<List<CampaignModel>>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value([]);

  final repo = ref.watch(campaignRepositoryProvider);
  return repo.getActiveCampaigns(userId);
});

// ============ SINGLE CAMPAIGN (REALTIME TRACKING) ============
final campaignDetailProvider =
    StreamProvider.family<CampaignModel?, String>((ref, campaignId) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value(null);

  final repo = ref.watch(campaignRepositoryProvider);
  return repo.watchCampaign(userId, campaignId);
});

// ============ CAMPAIGN LOGS (REALTIME) ============
final campaignLogsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, campaignId) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value([]);

  final repo = ref.watch(campaignRepositoryProvider);
  return repo.getLogs(userId, campaignId);
});

// ============ ANTI-BAN SERVICE ============
final _campaignAntiBanProvider = Provider<AntiBanService>((ref) {
  return AntiBanService();
});

// ============ CAMPAIGN EXECUTION SERVICE ============
final campaignExecutionServiceProvider = Provider<CampaignExecutionService?>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return null;

  final waRepo = ref.watch(whatsappRepositoryProvider);
  final campaignRepo = ref.watch(campaignRepositoryProvider);
  final antiBan = ref.watch(_campaignAntiBanProvider);
  final planRepo = ref.watch(planRepositoryProvider);

  return CampaignExecutionService(
    waRepo: waRepo,
    campaignRepo: campaignRepo,
    antiBan: antiBan,
    planRepo: planRepo,
    userId: userId,
  );
});

final whatsappRepositoryProvider = Provider<WhatsappRepository>((ref) {
  return WhatsappRepository();
});

// ============ CAMPAIGN SCHEDULER (AUTO-START SCHEDULED CAMPAIGNS) ============
final campaignSchedulerProvider = Provider<CampaignSchedulerService?>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  final executionService = ref.watch(campaignExecutionServiceProvider);
  if (userId == null || executionService == null) return null;

  final campaignRepo = ref.watch(campaignRepositoryProvider);
  final scheduler = CampaignSchedulerService(
    campaignRepo: campaignRepo,
    executionService: executionService,
    userId: userId,
  );
  scheduler.start();
  ref.onDispose(() => scheduler.stop());
  return scheduler;
});

// ============ CAMPAIGN MANAGEMENT NOTIFIER ============
class CampaignNotifier extends StateNotifier<CampaignActionState> {
  final CampaignRepository _repo;
  final String _userId;
  final CampaignExecutionService? _executionService;

  CampaignNotifier(this._repo, this._userId, this._executionService)
      : super(const CampaignActionState());

  Future<bool> create(CampaignModel campaign) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.createCampaign(_userId, campaign);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> update(CampaignModel campaign) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateCampaign(_userId, campaign);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String campaignId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteCampaign(_userId, campaignId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Start campaign — set running status
  Future<bool> start(String campaignId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.startCampaign(_userId, campaignId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Execute campaign — actually send messages
  Future<void> executeCampaign(String campaignId) async {
    if (_executionService == null) {
      state = state.copyWith(error: 'Execution service not available');
      return;
    }

    if (_executionService!.isExecuting) {
      state = state.copyWith(error: 'Another campaign is already running');
      return;
    }

    // Run in background (don't await — it's a long-running process)
    _executionService!.execute(campaignId).catchError((e) {
      state = state.copyWith(error: 'Campaign failed: $e');
    });
  }

  /// Pause a running campaign
  Future<bool> pause(String campaignId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.pauseCampaign(_userId, campaignId);
      _executionService?.pause();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Resume paused campaign
  Future<bool> resume(String campaignId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Update Firestore status to running
      await _repo.resumeCampaign(_userId, campaignId);

      // If execution service still has this campaign's loop alive, just unpause
      if (_executionService != null && _executionService!.activeCampaignId == campaignId) {
        _executionService!.resume();
      } else if (_executionService != null) {
        // Loop was lost (provider rebuilt, app navigated away, etc.)
        // Re-execute — execute() automatically skips already-sent messages
        _executionService!.execute(campaignId).catchError((e) {
          state = state.copyWith(error: 'Campaign resume failed: $e');
        });
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Schedule campaign for later execution
  Future<bool> schedule(String campaignId, DateTime scheduledAt) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('campaigns')
          .doc(campaignId)
          .update({
        'status': CampaignStatus.scheduled.name,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
      });
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Restart a completed campaign — reset stats and re-execute
  Future<void> restart(String campaignId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.restartCampaign(_userId, campaignId);
      state = state.copyWith(isLoading: false);
      // Now execute the campaign
      executeCampaign(campaignId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

class CampaignActionState {
  final bool isLoading;
  final String? error;

  const CampaignActionState({this.isLoading = false, this.error});

  CampaignActionState copyWith({bool? isLoading, String? error}) {
    return CampaignActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final campaignNotifierProvider =
    StateNotifierProvider<CampaignNotifier, CampaignActionState>((ref) {
  final repo = ref.watch(campaignRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final ownerId = user?.dataOwner ?? user?.id ?? '';
  final executionService = ref.watch(campaignExecutionServiceProvider);
  return CampaignNotifier(repo, ownerId, executionService);
});
