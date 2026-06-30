import 'package:flutter_test/flutter_test.dart';
import 'package:wabees/data/models/plan/plan_model.dart';
import 'package:wabees/data/models/plan/subscription_model.dart';

void main() {
  group('PlanModel', () {
    final testPlan = PlanModel(
      id: 'plan1',
      name: 'Business Pro',
      description: 'Best for growing businesses',
      priceMonthly: 49.0,
      priceYearly: 499.0,
      currency: 'USD',
      maxMessages: 10000,
      maxContacts: 500,
      maxCampaigns: 20,
      maxBots: 5,
      maxTemplates: 50,
      hasAnalytics: true,
      hasPrioritySupport: true,
      hasApiAccess: false,
      features: ['Bulk messaging', 'Analytics dashboard'],
      isActive: true,
      sortOrder: 2,
      isPopular: true,
      createdAt: DateTime(2026, 1, 1),
    );

    test('creates with correct properties', () {
      expect(testPlan.id, 'plan1');
      expect(testPlan.name, 'Business Pro');
      expect(testPlan.priceMonthly, 49.0);
      expect(testPlan.priceYearly, 499.0);
      expect(testPlan.maxMessages, 10000);
      expect(testPlan.maxContacts, 500);
      expect(testPlan.isActive, true);
      expect(testPlan.isPopular, true);
    });

    test('formattedPrice returns correct string', () {
      expect(testPlan.formattedPrice, 'USD 49/mo');
    });

    test('isUnlimitedMessages false for limited plan', () {
      expect(testPlan.isUnlimitedMessages, false);
    });

    test('isUnlimitedMessages true for unlimited plan', () {
      final unlimited = testPlan.copyWith(maxMessages: -1);
      expect(unlimited.isUnlimitedMessages, true);
    });

    test('limitLabel returns Unlimited for -1', () {
      expect(testPlan.limitLabel(-1), 'Unlimited');
    });

    test('limitLabel returns number string for positive values', () {
      expect(testPlan.limitLabel(500), '500');
    });

    test('toJson returns correct map', () {
      final json = testPlan.toJson();
      expect(json['name'], 'Business Pro');
      expect(json['priceMonthly'], 49.0);
      expect(json['maxMessages'], 10000);
      expect(json['isActive'], true);
      expect(json['isPopular'], true);
      expect(json['features'], ['Bulk messaging', 'Analytics dashboard']);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = testPlan.copyWith(name: 'Enterprise');
      expect(updated.name, 'Enterprise');
      expect(updated.priceMonthly, 49.0);
      expect(updated.maxMessages, 10000);
    });
  });

  group('SubscriptionModel', () {
    final now = DateTime.now();
    final activeSub = SubscriptionModel(
      id: 'sub1',
      planId: 'plan1',
      planName: 'Business Pro',
      status: 'active',
      messagesUsed: 500,
      contactsUsed: 100,
      campaignsUsed: 5,
      botsUsed: 2,
      maxMessages: 10000,
      maxContacts: 500,
      maxCampaigns: 20,
      maxBots: 5,
      startDate: now.subtract(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 20)),
      createdAt: now.subtract(const Duration(days: 10)),
    );

    test('isActive returns true for active subscription', () {
      expect(activeSub.isActive, true);
    });

    test('isExpired returns false for future endDate', () {
      expect(activeSub.isExpired, false);
    });

    test('daysRemaining returns correct value', () {
      expect(activeSub.daysRemaining, greaterThanOrEqualTo(19));
      expect(activeSub.daysRemaining, lessThanOrEqualTo(21));
    });

    test('canSendMessage true when under limit', () {
      expect(activeSub.canSendMessage, true);
    });

    test('canSendMessage false when at limit', () {
      final atLimit = SubscriptionModel(
        id: 'sub2',
        planId: 'plan1',
        planName: 'Basic',
        status: 'active',
        messagesUsed: 10000,
        contactsUsed: 0,
        campaignsUsed: 0,
        botsUsed: 0,
        maxMessages: 10000,
        maxContacts: 100,
        maxCampaigns: 5,
        maxBots: 1,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now,
      );
      expect(atLimit.canSendMessage, false);
    });

    test('canSendMessage true when unlimited (-1)', () {
      final unlimited = SubscriptionModel(
        id: 'sub3',
        planId: 'plan1',
        planName: 'Enterprise',
        status: 'active',
        messagesUsed: 999999,
        contactsUsed: 0,
        campaignsUsed: 0,
        botsUsed: 0,
        maxMessages: -1,
        maxContacts: -1,
        maxCampaigns: -1,
        maxBots: -1,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now,
      );
      expect(unlimited.canSendMessage, true);
      expect(unlimited.canAddContact, true);
      expect(unlimited.canCreateCampaign, true);
      expect(unlimited.canCreateBot, true);
    });

    test('canAddContact false when at limit', () {
      final atLimit = SubscriptionModel(
        id: 'sub4',
        planId: 'plan1',
        planName: 'Basic',
        status: 'active',
        messagesUsed: 0,
        contactsUsed: 500,
        campaignsUsed: 0,
        botsUsed: 0,
        maxMessages: 10000,
        maxContacts: 500,
        maxCampaigns: 5,
        maxBots: 1,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now,
      );
      expect(atLimit.canAddContact, false);
    });

    test('expired subscription is not active', () {
      final expired = SubscriptionModel(
        id: 'sub5',
        planId: 'plan1',
        planName: 'Basic',
        status: 'active',
        messagesUsed: 0,
        contactsUsed: 0,
        campaignsUsed: 0,
        botsUsed: 0,
        maxMessages: 10000,
        maxContacts: 100,
        maxCampaigns: 5,
        maxBots: 1,
        startDate: now.subtract(const Duration(days: 60)),
        endDate: now.subtract(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 60)),
      );
      expect(expired.isActive, false);
      expect(expired.isExpired, true);
      expect(expired.daysRemaining, 0);
    });

    test('toJson returns correct map', () {
      final json = activeSub.toJson();
      expect(json['planId'], 'plan1');
      expect(json['planName'], 'Business Pro');
      expect(json['status'], 'active');
      expect(json['messagesUsed'], 500);
      expect(json['maxMessages'], 10000);
    });
  });
}
