import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repositories/campaign_repository.dart';
import '../data/models/campaign/campaign_status.dart';
import 'campaign_execution_service.dart';

/// ⏰ CAMPAIGN SCHEDULER SERVICE
/// Monitors scheduled campaigns and auto-starts them when their
/// scheduledAt time arrives. Runs a periodic check every 30 seconds.
class CampaignSchedulerService {
  final CampaignRepository _campaignRepo;
  final CampaignExecutionService _executionService;
  final String _userId;

  Timer? _timer;
  StreamSubscription? _subscription;
  bool _isChecking = false;

  CampaignSchedulerService({
    required CampaignRepository campaignRepo,
    required CampaignExecutionService executionService,
    required String userId,
  })  : _campaignRepo = campaignRepo,
        _executionService = executionService,
        _userId = userId;

  /// Start monitoring scheduled campaigns
  void start() {
    // Listen to scheduled campaigns in realtime
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('campaigns')
        .where('status', isEqualTo: 'scheduled')
        .snapshots()
        .listen((_) {
      // Whenever scheduled campaigns change, check if any are due
      _checkScheduledCampaigns();
    });

    // Also check periodically (every 30s) in case realtime misses edge cases
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkScheduledCampaigns();
    });
  }

  /// Stop monitoring
  void stop() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Check all scheduled campaigns and start any that are due
  Future<void> _checkScheduledCampaigns() async {
    if (_isChecking) return; // Prevent concurrent checks
    if (_executionService.isExecuting) return; // Only 1 campaign at a time
    _isChecking = true;

    try {
      // Query scheduled campaigns
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('campaigns')
          .where('status', isEqualTo: 'scheduled')
          .get();

      final now = DateTime.now();

      for (final doc in snap.docs) {
        final data = doc.data();
        final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();

        if (scheduledAt != null && scheduledAt.isBefore(now)) {
          // This campaign is due — start it!
          if (!_executionService.isExecuting) {
            try {
              await _executionService.execute(doc.id);
            } catch (e) {
              // If execution fails, mark as failed
              try {
                await _campaignRepo.updateStatus(
                  _userId, doc.id, CampaignStatus.failed,
                );
              } catch (_) {}
            }
            // Only start one campaign per check cycle
            break;
          }
        }
      }
    } catch (_) {
      // Silently handle errors — will retry on next cycle
    } finally {
      _isChecking = false;
    }
  }

  /// Schedule a campaign for a specific time
  Future<void> scheduleCampaign(String campaignId, DateTime scheduledAt) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('campaigns')
        .doc(campaignId)
        .update({
      'status': CampaignStatus.scheduled.name,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
    });
  }
}
