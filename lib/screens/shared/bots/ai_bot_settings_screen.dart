import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/bots/ai_bot_provider.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/plans/plan_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/route_names.dart';

class AiBotSettingsScreen extends ConsumerStatefulWidget {
  const AiBotSettingsScreen({super.key});

  @override
  ConsumerState<AiBotSettingsScreen> createState() =>
      _AiBotSettingsScreenState();
}

class _AiBotSettingsScreenState extends ConsumerState<AiBotSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Controllers
  final _businessNameCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _timingsCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _contactsCtrl = TextEditingController();
  final _customInfoCtrl = TextEditingController();
  final _customInstructionsCtrl = TextEditingController();
  final _greetingCtrl = TextEditingController();
  final _handoffKeywordsCtrl = TextEditingController();
  final _leadFieldsCtrl = TextEditingController();
  final _afterHoursMessageCtrl = TextEditingController();
  String _tone = 'professional and friendly';
  bool _initialized = false;

  // FAQ
  List<Map<String, String>> _faqs = [];

  // Test Bot tab state
  final _testInputCtrl = TextEditingController();
  final List<_TestMessage> _testMessages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _servicesCtrl.dispose();
    _timingsCtrl.dispose();
    _locationCtrl.dispose();
    _contactsCtrl.dispose();
    _customInfoCtrl.dispose();
    _customInstructionsCtrl.dispose();
    _greetingCtrl.dispose();
    _handoffKeywordsCtrl.dispose();
    _leadFieldsCtrl.dispose();
    _afterHoursMessageCtrl.dispose();
    _testInputCtrl.dispose();
    super.dispose();
  }

  void _initFromConfig(AiBotConfig config) {
    if (_initialized) return;
    _initialized = true;
    _businessNameCtrl.text = config.businessName;
    _businessTypeCtrl.text = config.businessType;
    _servicesCtrl.text = config.services;
    _timingsCtrl.text = config.timings;
    _locationCtrl.text = config.location;
    _contactsCtrl.text = config.contacts;
    _customInfoCtrl.text = config.customInfo;
    _customInstructionsCtrl.text = config.customInstructions;
    _greetingCtrl.text = config.greeting;
    _handoffKeywordsCtrl.text = config.handoffKeywords;
    _leadFieldsCtrl.text = config.leadFields;
    _afterHoursMessageCtrl.text = config.afterHoursMessage;
    _tone = config.tone;
    try {
      final parsed = json.decode(config.faq);
      if (parsed is List) {
        _faqs = parsed
            .map<Map<String, String>>((e) => {
                  'q': (e['q'] ?? '').toString(),
                  'a': (e['a'] ?? '').toString(),
                })
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider);
    final uid = user?.dataOwner ?? user?.id ?? '';
    if (uid.isEmpty) {
      setState(() => _saving = false);
      return;
    }

    final config = AiBotConfig(
      enabled: ref.read(aiBotConfigProvider).value?.enabled ?? false,
      businessName: _businessNameCtrl.text.trim(),
      businessType: _businessTypeCtrl.text.trim(),
      services: _servicesCtrl.text.trim(),
      timings: _timingsCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      contacts: _contactsCtrl.text.trim(),
      customInfo: _customInfoCtrl.text.trim(),
      faq: json.encode(_faqs),
      customInstructions: _customInstructionsCtrl.text.trim(),
      tone: _tone,
      greeting: _greetingCtrl.text.trim(),
      handoffKeywords: _handoffKeywordsCtrl.text.trim(),
      leadFields: _leadFieldsCtrl.text.trim(),
      afterHoursMessage: _afterHoursMessageCtrl.text.trim(),
    );

    await saveAiBotConfig(uid, config);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ AI Bot settings saved!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Feature gate: admin must enable AI bot AND user must be owner (not agent)
    final bool isAgent = user?.dataOwner != null;
    if (user == null || !user.aiBotEnabled || isAgent) {
      return Scaffold(
        appBar: AppBar(title: const Text('🤖 AI Auto Bot')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                const Text(
                  'AI Bot Feature Not Available',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This feature is not enabled for your account.\nPlease contact admin to activate AI Bot.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final configAsync = ref.watch(aiBotConfigProvider);
    final usageAsync = ref.watch(aiBotUsageProvider);
    final leadsAsync = ref.watch(aiBotLeadsProvider);

    return configAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (config) {
        _initFromConfig(config);
        return Scaffold(
          appBar: AppBar(
            title: const Text('🤖 AI Auto Bot'),
            actions: [
              // Enable/Disable toggle
              Switch(
                value: config.enabled,
                activeThumbColor: AppColors.primary,
                onChanged: (val) async {
                  final user = ref.read(currentUserProvider);
                  final uid = user?.dataOwner ?? user?.id ?? '';
                  if (uid.isNotEmpty) await toggleAiBot(uid, val);
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.settings), text: 'Setup'),
                Tab(icon: Icon(Icons.analytics), text: 'Usage'),
                Tab(icon: Icon(Icons.people), text: 'Leads'),
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Test Bot'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildCreditBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSetupTab(config),
                    _buildUsageTab(usageAsync),
                    _buildLeadsTab(leadsAsync),
                    _buildTestTab(config),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreditBanner() {
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    if (sub == null) return const SizedBox.shrink();

    if (!sub.isActive) {
      return _AiBotBanner(
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
        message: 'Your subscription has expired. AI Bot is disabled.',
        actionLabel: 'Renew Plan',
        onAction: () => context.pushNamed(RouteNames.plans),
      );
    }

    if (!sub.canUseAiBot) {
      return _AiBotBanner(
        icon: Icons.battery_alert_rounded,
        color: Colors.orange,
        message:
            'AI message credits exhausted (${sub.aiMessagesUsed}/${sub.maxAiMessages} used). '
            'Upgrade your plan to get more AI credits.',
        actionLabel: 'Upgrade Plan',
        onAction: () => context.pushNamed(RouteNames.plans),
      );
    }

    if (sub.maxAiMessages > 0) {
      final remaining = sub.aiMessagesRemaining;
      final percent = sub.aiMessagesUsed / sub.maxAiMessages;
      if (percent >= 0.85) {
        return _AiBotBanner(
          icon: Icons.warning_amber_rounded,
          color: Colors.amber.shade700,
          message:
              'AI credits running low — $remaining of ${sub.maxAiMessages} remaining.',
          actionLabel: 'Upgrade',
          onAction: () => context.pushNamed(RouteNames.plans),
        );
      }
    }

    return const SizedBox.shrink();
  }

  // ============ SETUP TAB ============
  Widget _buildSetupTab(AiBotConfig config) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: config.enabled
                    ? [Colors.green.shade700, Colors.green.shade500]
                    : [Colors.grey.shade700, Colors.grey.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  config.enabled ? Icons.smart_toy : Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.enabled ? 'Bot is ACTIVE' : 'Bot is OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        config.enabled
                            ? 'Replying to clients automatically'
                            : 'Enable from top-right toggle',
                        style: TextStyle(
                          color: Colors.white.withAlpha(204),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Business Info Section
          _sectionHeader('📋 Business Information'),
          const SizedBox(height: 8),
          _buildField(_businessNameCtrl, 'Business Name', 'e.g. ABC Loans',
              required: true),
          _buildField(_businessTypeCtrl, 'Business Type',
              'e.g. Financial Services, Restaurant'),
          _buildField(_servicesCtrl, 'Services / Products',
              'List your services with details & prices',
              maxLines: 4),
          _buildField(_timingsCtrl, 'Working Hours', 'e.g. Mon-Sat 9am-6pm'),
          _buildField(
              _locationCtrl, 'Location', 'e.g. Islamabad, Blue Area'),
          _buildField(_contactsCtrl, 'Contact Info',
              'Phone, email, website etc.'),
          _buildField(_customInfoCtrl, 'Additional Info',
              'Any other important details for the bot',
              maxLines: 3),

          const SizedBox(height: 24),

          // FAQ Section
          _sectionHeader('❓ FAQs (${_faqs.length})'),
          const SizedBox(height: 8),
          ..._faqs.asMap().entries.map((entry) {
            final i = entry.key;
            final faq = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Q${i + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () =>
                              setState(() => _faqs.removeAt(i)),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    Text('Q: ${faq['q']}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('A: ${faq['a']}',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addFaq,
            icon: const Icon(Icons.add),
            label: const Text('Add FAQ'),
          ),

          const SizedBox(height: 24),

          // Bot Behavior Section
          _sectionHeader('🧠 Bot Behavior'),
          const SizedBox(height: 8),
          _buildField(_greetingCtrl, 'Greeting Message',
              'First message when new client contacts',
              maxLines: 2),
          _buildField(_customInstructionsCtrl, 'Custom Instructions',
              'Special rules for the bot (e.g. Always ask for CNIC)',
              maxLines: 3),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _tone,
            decoration: const InputDecoration(
              labelText: 'Bot Tone',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'professional and friendly',
                  child: Text('Professional & Friendly')),
              DropdownMenuItem(
                  value: 'casual', child: Text('Casual')),
              DropdownMenuItem(
                  value: 'formal', child: Text('Formal')),
              DropdownMenuItem(
                  value: 'enthusiastic', child: Text('Enthusiastic')),
            ],
            onChanged: (v) => setState(() => _tone = v ?? _tone),
          ),
          const SizedBox(height: 12),
          _buildField(_handoffKeywordsCtrl, 'Handoff Keywords',
              'Comma separated: complaint, manager, angry',
              helperText:
                  'When client uses these words, bot will stop and let you handle'),
          _buildField(_leadFieldsCtrl, 'Lead Fields to Collect',
              'Comma separated: name, phone, cnic, email',
              helperText: 'Bot will naturally try to collect this info'),

          const SizedBox(height: 24),

          // After Hours Section
          _sectionHeader('🕐 After Hours'),
          const SizedBox(height: 8),
          _buildField(_afterHoursMessageCtrl, 'After-Hours Message',
              'e.g. Hamari timings Mon-Sat 9am-6pm hain. Hum aap se jald rabta karein ge!',
              maxLines: 3,
              helperText:
                  'Sent when customer messages outside business hours (uses Working Hours above)'),

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ============ USAGE TAB ============
  Widget _buildUsageTab(AsyncValue<AiBotUsage> usageAsync) {
    return usageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (usage) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Usage card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.purple.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Messages This Month',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${usage.usedThisMonth} / ${usage.monthlyLimit}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: usage.usagePercent,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(
                      usage.usagePercent > 0.8 ? Colors.red : Colors.greenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${usage.remaining} messages remaining',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Plan info
          Card(
            child: ListTile(
              leading: Icon(
                Icons.workspace_premium,
                color: usage.monthlyLimit > 1000
                    ? Colors.amber
                    : Colors.grey,
                size: 32,
              ),
              title: Text(
                '${usage.monthlyLimit == 999999 ? "Unlimited" : "${usage.monthlyLimit}"} AI Messages',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                usage.monthlyLimit == 999999
                    ? 'Unlimited messages included in your plan'
                    : '${usage.remaining} remaining • Upgrade plan for more',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ LEADS TAB ============
  Widget _buildLeadsTab(AsyncValue<List<AiBotLead>> leadsAsync) {
    return leadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (leads) {
        if (leads.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No leads captured yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Leads will appear as bot chats with clients',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: leads.length,
          itemBuilder: (context, i) {
            final lead = leads[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: lead.score == 'hot'
                      ? Colors.red
                      : lead.score == 'warm'
                          ? Colors.orange
                          : Colors.grey,
                  child: Text(
                    lead.score == 'hot'
                        ? '🔥'
                        : lead.score == 'warm'
                            ? '🟡'
                            : '⚪',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                title: Text(lead.name.isNotEmpty ? lead.name : lead.phone,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${lead.score.toUpperCase()} • ${lead.messageCount} msgs',
                  style: TextStyle(
                    color: lead.score == 'hot' ? Colors.red : Colors.grey,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lead.phone.isNotEmpty) _leadRow('📱 Phone', lead.phone),
                        if (lead.email.isNotEmpty) _leadRow('📧 Email', lead.email),
                        if (lead.cnic.isNotEmpty) _leadRow('🪪 CNIC', lead.cnic),
                        if (lead.details.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Chat Notes:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(lead.details,
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============ TEST BOT TAB ============
  /// Local simulator — shows how the bot would behave using current saved config.
  /// Does NOT call any API or use AI credits. Pure offline simulation.
  Widget _buildTestTab(AiBotConfig config) {
    final scrollCtrl = ScrollController();

    return Column(
      children: [
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simulator uses your saved config (FAQs, greeting, handoff keywords). '
                  'No AI credits used.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _testMessages.clear()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Chat messages
        Expanded(
          child: _testMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Type a message below to test the bot',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bot will simulate responses based on your\nFAQs, greeting, and handoff keywords.',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _testMessages.length,
                  itemBuilder: (context, i) {
                    final msg = _testMessages[i];
                    return _buildTestBubble(msg);
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testInputCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type a test message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendTestMessage(config, scrollCtrl),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () => _sendTestMessage(config, scrollCtrl),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestBubble(_TestMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Text('🤖', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (msg.matchedFaq != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '✅ Matched FAQ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (msg.isHandoff) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '⚠️ Handoff triggered — bot would stop',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _sendTestMessage(AiBotConfig config, ScrollController scrollCtrl) {
    final text = _testInputCtrl.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _testMessages.add(_TestMessage(text: text, isUser: true));
    });
    _testInputCtrl.clear();

    // Simulate bot response (offline, no API)
    final response = _simulateBotResponse(text, config);

    // Small delay to feel natural
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _testMessages.add(response);
        });
        // Auto-scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (scrollCtrl.hasClients) {
            scrollCtrl.animateTo(
              scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  /// Simulate bot logic locally using saved config.
  /// Priority order:
  ///   1. Handoff keyword detected → bot stops
  ///   2. FAQ keyword match → return FAQ answer
  ///   3. Greeting (first message) → show greeting
  ///   4. Service/business info keywords → return relevant info
  ///   5. Generic fallback
  _TestMessage _simulateBotResponse(String userText, AiBotConfig config) {
    final lower = userText.toLowerCase();

    // 1. Check handoff keywords (highest priority)
    if (config.handoffKeywords.isNotEmpty) {
      final handoffWords = config.handoffKeywords
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty);
      for (final kw in handoffWords) {
        if (lower.contains(kw)) {
          return _TestMessage(
            text: 'I\'ll connect you with a human agent right away. '
                'Please wait a moment. 🙏',
            isUser: false,
            isHandoff: true,
          );
        }
      }
    }

    // 2. Check FAQs — find best keyword match
    String? faqAnswer;
    String? matchedFaq;
    for (final faq in _faqs) {
      final question = (faq['q'] ?? '').toLowerCase();
      // Split question into words and check if any significant word matches
      final words = question
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .toList();
      final matchScore = words.where((w) => lower.contains(w)).length;
      if (matchScore > 0 && faqAnswer == null) {
        faqAnswer = faq['a'] ?? '';
        matchedFaq = faq['q'];
      }
    }
    if (faqAnswer != null && faqAnswer.isNotEmpty) {
      return _TestMessage(
        text: faqAnswer,
        isUser: false,
        matchedFaq: matchedFaq,
      );
    }

    // 3. Greeting for hi/hello/salam/assalam
    final greetWords = ['hi', 'hello', 'salam', 'assalam', 'hey', 'hola', 'good morning', 'good evening'];
    if (greetWords.any((g) => lower.contains(g))) {
      final greeting = config.greeting.isNotEmpty
          ? config.greeting
          : 'Hello! Welcome to ${config.businessName.isNotEmpty ? config.businessName : "our business"}. How can I help you today? 😊';
      return _TestMessage(text: greeting, isUser: false);
    }

    // 4. Service/pricing/timing/location queries
    if (lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('rate') ||
        lower.contains('charges') ||
        lower.contains('kitna') ||
        lower.contains('fee')) {
      final services = config.services.isNotEmpty
          ? config.services
          : 'Please contact us for pricing details.';
      return _TestMessage(
        text: 'Our services & pricing:\n\n$services',
        isUser: false,
      );
    }

    if (lower.contains('time') ||
        lower.contains('timing') ||
        lower.contains('open') ||
        lower.contains('hours') ||
        lower.contains('waqt')) {
      final timings = config.timings.isNotEmpty
          ? config.timings
          : 'Please check our website for working hours.';
      return _TestMessage(
        text: 'Our working hours:\n$timings',
        isUser: false,
      );
    }

    if (lower.contains('location') ||
        lower.contains('address') ||
        lower.contains('where') ||
        lower.contains('kahan') ||
        lower.contains('map')) {
      final location = config.location.isNotEmpty
          ? config.location
          : 'Please contact us for our location.';
      return _TestMessage(
        text: 'We are located at:\n$location\n\n${config.contacts.isNotEmpty ? "Contact: ${config.contacts}" : ""}',
        isUser: false,
      );
    }

    if (lower.contains('contact') ||
        lower.contains('call') ||
        lower.contains('phone') ||
        lower.contains('email')) {
      final contacts = config.contacts.isNotEmpty
          ? config.contacts
          : 'Please reach out through WhatsApp.';
      return _TestMessage(
        text: 'You can reach us at:\n$contacts',
        isUser: false,
      );
    }

    // 5. Generic fallback
    final biz = config.businessName.isNotEmpty ? config.businessName : 'our business';
    return _TestMessage(
      text: 'Thank you for contacting $biz! 😊\n\n'
          'I\'m here to help. You can ask me about:\n'
          '• Our services & pricing\n'
          '• Working hours\n'
          '• Location & contact\n'
          '• Any specific questions\n\n'
          '${config.customInfo.isNotEmpty ? config.customInfo : ""}',
      isUser: false,
    );
  }

  // ============ HELPERS ============
  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    bool required = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _leadRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _addFaq() {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add FAQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qCtrl,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Answer',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (qCtrl.text.trim().isNotEmpty &&
                  aCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _faqs.add({
                    'q': qCtrl.text.trim(),
                    'a': aCtrl.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ============ TEST MESSAGE MODEL ============
class _TestMessage {
  final String text;
  final bool isUser;
  final String? matchedFaq;
  final bool isHandoff;

  const _TestMessage({
    required this.text,
    required this.isUser,
    this.matchedFaq,
    this.isHandoff = false,
  });
}

// ============ CREDIT/EXPIRY BANNER WIDGET ============
class _AiBotBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _AiBotBanner({
    required this.icon,
    required this.color,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withAlpha(25),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
