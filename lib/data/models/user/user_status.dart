/// 🎯 USER STATUS ENUM
enum UserStatus {
  pending,
  active,
  suspended,
  deactivated;

  String get label {
    switch (this) {
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.active:
        return 'Active';
      case UserStatus.suspended:
        return 'Suspended';
      case UserStatus.deactivated:
        return 'Deactivated';
    }
  }

  bool get isActive => this == UserStatus.active;
  bool get isPending => this == UserStatus.pending;
  bool get isSuspended => this == UserStatus.suspended;
}
