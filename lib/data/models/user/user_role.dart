/// 🎯 USER ROLE ENUM
enum UserRole {
  user,
  admin;

  bool get isAdmin => this == UserRole.admin;
  bool get isUser => this == UserRole.user;

  String get label {
    switch (this) {
      case UserRole.user:
        return 'User';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
