/// 📊 CAMPAIGN STATUS
enum CampaignStatus {
  draft,       // Not yet scheduled
  scheduled,   // Scheduled for future
  running,     // Currently sending
  paused,      // Paused mid-send
  completed,   // All messages sent
  failed;      // Failed to execute

  String get label {
    switch (this) {
      case CampaignStatus.draft:
        return 'Draft';
      case CampaignStatus.scheduled:
        return 'Scheduled';
      case CampaignStatus.running:
        return 'Running';
      case CampaignStatus.paused:
        return 'Paused';
      case CampaignStatus.completed:
        return 'Completed';
      case CampaignStatus.failed:
        return 'Failed';
    }
  }

  bool get isEditable => this == CampaignStatus.draft;
  bool get isActive => this == CampaignStatus.running || this == CampaignStatus.scheduled;

  static CampaignStatus fromString(String value) {
    return CampaignStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CampaignStatus.draft,
    );
  }
}
