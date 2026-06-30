import 'package:flutter_test/flutter_test.dart';
import 'package:wabees/data/models/user/user_model.dart';
import 'package:wabees/data/models/user/user_role.dart';
import 'package:wabees/data/models/user/user_status.dart';

void main() {
  group('UserModel', () {
    final testUser = UserModel(
      id: 'user123',
      email: 'test@wabees.com',
      businessName: 'Test Business',
      phoneNumber: '+921234567890',
      role: UserRole.user,
      status: UserStatus.active,
      createdAt: DateTime(2026, 1, 1),
      totalMessages: 150,
      totalContacts: 25,
      totalBots: 3,
      totalCampaigns: 5,
    );

    test('creates with correct properties', () {
      expect(testUser.id, 'user123');
      expect(testUser.email, 'test@wabees.com');
      expect(testUser.businessName, 'Test Business');
      expect(testUser.phoneNumber, '+921234567890');
      expect(testUser.role, UserRole.user);
      expect(testUser.status, UserStatus.active);
      expect(testUser.totalMessages, 150);
      expect(testUser.totalContacts, 25);
      expect(testUser.totalBots, 3);
      expect(testUser.totalCampaigns, 5);
      expect(testUser.whatsappConnected, false);
    });

    test('toJson returns correct map', () {
      final json = testUser.toJson();
      expect(json['email'], 'test@wabees.com');
      expect(json['businessName'], 'Test Business');
      expect(json['role'], 'user');
      expect(json['status'], 'active');
      expect(json['totalMessages'], 150);
      expect(json['whatsappConnected'], false);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = testUser.copyWith(businessName: 'New Business');
      expect(updated.businessName, 'New Business');
      expect(updated.email, 'test@wabees.com');
      expect(updated.id, 'user123');
      expect(updated.role, UserRole.user);
    });

    test('copyWith updates specified fields', () {
      final updated = testUser.copyWith(
        status: UserStatus.suspended,
        role: UserRole.admin,
        totalMessages: 200,
      );
      expect(updated.status, UserStatus.suspended);
      expect(updated.role, UserRole.admin);
      expect(updated.totalMessages, 200);
    });

    test('defaults are correct', () {
      final minimal = UserModel(
        id: 'min1',
        email: 'min@test.com',
        businessName: 'Min',
        phoneNumber: '+0000',
        role: UserRole.user,
        status: UserStatus.pending,
        createdAt: DateTime.now(),
      );
      expect(minimal.totalMessages, 0);
      expect(minimal.totalContacts, 0);
      expect(minimal.totalBots, 0);
      expect(minimal.totalCampaigns, 0);
      expect(minimal.whatsappConnected, false);
      expect(minimal.profileImageUrl, isNull);
      expect(minimal.fcmToken, isNull);
    });
  });

  group('UserRole', () {
    test('isAdmin returns true for admin', () {
      expect(UserRole.admin.isAdmin, true);
      expect(UserRole.user.isAdmin, false);
    });

    test('isUser returns true for user', () {
      expect(UserRole.user.isUser, true);
      expect(UserRole.admin.isUser, false);
    });

    test('label is correct', () {
      expect(UserRole.user.label, 'User');
      expect(UserRole.admin.label, 'Admin');
    });
  });

  group('UserStatus', () {
    test('isActive returns correct value', () {
      expect(UserStatus.active.isActive, true);
      expect(UserStatus.pending.isActive, false);
    });

    test('isPending returns correct value', () {
      expect(UserStatus.pending.isPending, true);
      expect(UserStatus.active.isPending, false);
    });

    test('isSuspended returns correct value', () {
      expect(UserStatus.suspended.isSuspended, true);
      expect(UserStatus.active.isSuspended, false);
    });

    test('labels are correct', () {
      expect(UserStatus.pending.label, 'Pending');
      expect(UserStatus.active.label, 'Active');
      expect(UserStatus.suspended.label, 'Suspended');
      expect(UserStatus.deactivated.label, 'Deactivated');
    });
  });
}
