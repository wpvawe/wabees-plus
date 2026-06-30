import 'package:flutter_test/flutter_test.dart';
import 'package:wabees/data/models/bot/bot_model.dart';
import 'package:wabees/data/models/bot/bot_trigger_type.dart';
import 'package:wabees/data/models/campaign/campaign_model.dart';
import 'package:wabees/data/models/campaign/campaign_status.dart';

void main() {
  group('BotModel', () {
    final testBot = BotModel(
      id: 'bot1',
      name: 'Welcome Bot',
      description: 'Greets new customers',
      triggerType: BotTriggerType.keyword,
      triggerKeywords: ['hello', 'hi'],
      responseText: 'Hello! Welcome to our store.',
      isActive: true,
      totalTriggered: 42,
      createdAt: DateTime(2026, 1, 1),
    );

    test('creates with correct properties', () {
      expect(testBot.id, 'bot1');
      expect(testBot.name, 'Welcome Bot');
      expect(testBot.triggerType, BotTriggerType.keyword);
      expect(testBot.triggerKeywords, ['hello', 'hi']);
      expect(testBot.isActive, true);
      expect(testBot.totalTriggered, 42);
    });

    test('toJson returns correct map', () {
      final json = testBot.toJson();
      expect(json['name'], 'Welcome Bot');
      expect(json['triggerType'], 'keyword');
      expect(json['triggerKeywords'], ['hello', 'hi']);
      expect(json['responseText'], 'Hello! Welcome to our store.');
      expect(json['isActive'], true);
      expect(json['totalTriggered'], 42);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = testBot.copyWith(name: 'FAQ Bot');
      expect(updated.name, 'FAQ Bot');
      expect(updated.triggerKeywords, ['hello', 'hi']);
      expect(updated.isActive, true);
    });

    test('copyWith toggles isActive', () {
      final toggled = testBot.copyWith(isActive: false);
      expect(toggled.isActive, false);
      expect(toggled.name, 'Welcome Bot');
    });

    test('statusLabel returns correct value', () {
      expect(testBot.statusLabel, 'Active');
      final inactive = testBot.copyWith(isActive: false);
      expect(inactive.statusLabel, 'Inactive');
    });

    test('shouldTrigger works for keyword type', () {
      expect(testBot.shouldTrigger('hello world'), true);
      expect(testBot.shouldTrigger('say hi there'), true);
      expect(testBot.shouldTrigger('goodbye'), false);
    });

    test('shouldTrigger returns false when inactive', () {
      final inactive = testBot.copyWith(isActive: false);
      expect(inactive.shouldTrigger('hello'), false);
    });

    test('triggerSummary shows keyword count', () {
      expect(testBot.triggerSummary, '2 triggers');
    });

    test('defaults are correct', () {
      final minimal = BotModel(
        id: 'min1',
        name: 'Minimal',
        triggerType: BotTriggerType.allMessages,
        responseText: 'Hi',
        createdAt: DateTime.now(),
      );
      expect(minimal.description, '');
      expect(minimal.isActive, true);
      expect(minimal.delaySeconds, 0);
      expect(minimal.caseSensitive, false);
      expect(minimal.totalTriggered, 0);
      expect(minimal.triggerKeywords, isEmpty);
    });
  });

  group('CampaignModel', () {
    final testCampaign = CampaignModel(
      id: 'camp1',
      name: 'Holiday Sale',
      description: 'Announcing holiday discounts',
      messageType: 'text',
      messageBody: 'Big sale this weekend!',
      audiencePhones: ['+921111111111', '+921222222222'],
      audienceTags: ['customers', 'vip'],
      totalRecipients: 2,
      sentCount: 2,
      deliveredCount: 1,
      readCount: 1,
      failedCount: 0,
      status: CampaignStatus.completed,
      createdAt: DateTime(2026, 1, 1),
    );

    test('creates with correct properties', () {
      expect(testCampaign.id, 'camp1');
      expect(testCampaign.name, 'Holiday Sale');
      expect(testCampaign.messageType, 'text');
      expect(testCampaign.audiencePhones.length, 2);
      expect(testCampaign.status, CampaignStatus.completed);
    });

    test('deliveryRate calculates correctly', () {
      expect(testCampaign.deliveryRate, 50.0);
    });

    test('readRate calculates correctly', () {
      expect(testCampaign.readRate, 100.0); // 1 read / 1 delivered = 100%
    });

    test('progress calculates correctly', () {
      // (sentCount + failedCount) / totalRecipients * 100
      expect(testCampaign.progress, 100.0); // (2+0) / 2 * 100
    });

    test('isTemplate returns correct value', () {
      expect(testCampaign.isTemplate, false);
      final templateCampaign = CampaignModel(
        id: 'camp2',
        name: 'Template Campaign',
        messageType: 'template',
        messageBody: 'template_content',
        status: CampaignStatus.draft,
        createdAt: DateTime.now(),
      );
      expect(templateCampaign.isTemplate, true);
    });

    test('toJson returns correct map', () {
      final json = testCampaign.toJson();
      expect(json['name'], 'Holiday Sale');
      expect(json['messageType'], 'text');
      expect(json['messageBody'], 'Big sale this weekend!');
      expect(json['sentCount'], 2);
      expect(json['status'], 'completed');
    });

    test('zero counts return zero rates', () {
      final empty = CampaignModel(
        id: 'empty',
        name: 'Empty',
        messageBody: '',
        createdAt: DateTime.now(),
      );
      expect(empty.deliveryRate, 0);
      expect(empty.readRate, 0);
      expect(empty.progress, 0);
    });
  });

  group('CampaignStatus', () {
    test('labels are correct', () {
      expect(CampaignStatus.draft.label, 'Draft');
      expect(CampaignStatus.scheduled.label, 'Scheduled');
      expect(CampaignStatus.running.label, 'Running');
      expect(CampaignStatus.paused.label, 'Paused');
      expect(CampaignStatus.completed.label, 'Completed');
      expect(CampaignStatus.failed.label, 'Failed');
    });

    test('isEditable returns correct value', () {
      expect(CampaignStatus.draft.isEditable, true);
      expect(CampaignStatus.scheduled.isEditable, false);
      expect(CampaignStatus.running.isEditable, false);
      expect(CampaignStatus.completed.isEditable, false);
    });

    test('isActive returns correct value', () {
      expect(CampaignStatus.running.isActive, true);
      expect(CampaignStatus.scheduled.isActive, true);
      expect(CampaignStatus.draft.isActive, false);
      expect(CampaignStatus.completed.isActive, false);
    });

    test('fromString parses correctly', () {
      expect(CampaignStatus.fromString('draft'), CampaignStatus.draft);
      expect(CampaignStatus.fromString('running'), CampaignStatus.running);
      expect(CampaignStatus.fromString('invalid'), CampaignStatus.draft);
    });
  });
}
