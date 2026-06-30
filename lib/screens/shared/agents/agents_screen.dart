import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../providers/auth/auth_provider.dart';

/// 👥 AGENTS SCREEN — Manage agents sharing this WhatsApp number
/// Owner: see all agents, add by email, transfer ownership, remove agent
/// Agent: see all agents, disconnect self
class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  static const _apiBase = 'https://api.wabees.live/api';
  bool _isTransferring = false;
  bool _isAddingAgent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isOwner = user.dataOwner == null || user.dataOwner!.isEmpty;
    final ownerId = isOwner ? user.id : user.dataOwner!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D2818), const Color(0xFF0A1628)]
                  : [AppColors.primaryDark, AppColors.primary],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              tooltip: 'Add Agent by Email',
              onPressed: () => _showAddAgentDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Owner/Agent info card
          Container(
            margin: const EdgeInsets.all(AppDimens.md),
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(15),
                  AppColors.primary.withAlpha(5),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(color: AppColors.primary.withAlpha(30)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOwner ? Icons.shield_rounded : Icons.person_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwner ? 'You are the Owner' : 'You are an Agent',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'You control all data and agents for this WhatsApp number'
                            : 'You share data with the owner of this WhatsApp number',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Agent self-disconnect button
                if (!isOwner)
                  TextButton.icon(
                    onPressed: () => _confirmSelfDisconnect(context, ownerId),
                    icon: const Icon(Icons.link_off_rounded, size: 18, color: Colors.redAccent),
                    label: const Text('Leave', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      backgroundColor: Colors.redAccent.withAlpha(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Agents list header + add button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Row(
              children: [
                Text(
                  'Connected Agents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (isOwner)
                  TextButton.icon(
                    onPressed: () => _showAddAgentDialog(context),
                    icon: const Icon(Icons.add_circle_rounded, size: 18),
                    label: const Text('Add Agent'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          // Agents list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(ownerId)
                  .collection('agents')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('Agents StreamBuilder error: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withAlpha(120)),
                          const SizedBox(height: AppDimens.md),
                          Text(
                            'Unable to load agents',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.xs),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.redAccent.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final agents = snapshot.data?.docs ?? [];

                if (agents.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off_rounded,
                            size: 64,
                            color: theme.colorScheme.onSurface.withAlpha(30),
                          ),
                          const SizedBox(height: AppDimens.md),
                          Text(
                            'No agents connected',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimens.xs),
                          Text(
                            isOwner 
                              ? 'Tap "Add Agent" to invite users by email, or they can connect using the same WhatsApp credentials.'
                              : 'No other agents are connected to this WhatsApp number.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    final data = agent.data() as Map<String, dynamic>;
                    final email = data['email'] ?? 'Unknown';
                    final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate();
                    final addedBy = data['addedBy'] as String?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppDimens.sm),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        side: BorderSide(
                          color: AppColors.primary.withAlpha(30),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.md,
                          vertical: AppDimens.xs,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6366F1).withAlpha(20),
                          child: Text(
                            (data['name'] as String? ?? email).isNotEmpty
                                ? (data['name'] as String? ?? email)[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          (data['name'] as String?)?.isNotEmpty == true
                              ? data['name'] as String
                              : email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((data['name'] as String?)?.isNotEmpty == true)
                              Text(
                                email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            Row(
                              children: [
                                Text(
                                  joinedAt != null
                                      ? 'Joined ${_formatDate(joinedAt)}'
                                      : 'Agent',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (addedBy == 'owner') ...[ 
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'invited',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: isOwner
                            ? PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onSelected: (value) {
                                  if (value == 'transfer') {
                                    _confirmTransfer(context, agent.id, email);
                                  } else if (value == 'remove') {
                                    _confirmRemove(context, ownerId, agent.id, email);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'transfer',
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF0EA5E9)),
                                        SizedBox(width: 8),
                                        Text('Transfer Ownership'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove_rounded, size: 20, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Remove Agent', style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // FAB for adding agent (owner only)
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAgentDialog(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Agent', style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  // ============ ADD AGENT BY EMAIL — Uses Backend API ============
  void _showAddAgentDialog(BuildContext context) {
    final emailController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Add Agent by Email'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the email of a registered user to add them as an agent. They will share access to your WhatsApp data.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'User Email',
                    hintText: 'agent@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isAddingAgent) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: _isAddingAgent
                    ? null
                    : () => _addAgentByEmail(ctx, emailController.text.trim(), setDialogState),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Agent'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addAgentByEmail(BuildContext dialogCtx, String email, void Function(void Function()) setDialogState) async {
    if (email.isEmpty) {
      _showSnack('Please enter an email address');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setDialogState(() => _isAddingAgent = true);
    setState(() => _isAddingAgent = true);

    try {
      // Call backend API — bypasses Firestore rules
      final response = await http.post(
        Uri.parse('$_apiBase/add-agent.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'owner_id': user.id,
          'agent_email': email.toLowerCase(),
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
        _showSnack('Agent added successfully! ✅ $email can now access shared data.');
      } else {
        final errorMsg = body['error'] ?? 'Unknown error';
        _showSnack(errorMsg);
      }
    } catch (e) {
      _showSnack('Network error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAddingAgent = false);
      }
    }
  }

  // ============ AGENT SELF-DISCONNECT — Uses Backend API ============
  void _confirmSelfDisconnect(BuildContext context, String ownerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave as Agent?'),
        content: const Text(
          'You will lose access to the shared WhatsApp data.\n\n'
          'You can reconnect later by:\n'
          '• Being re-added by the owner\n'
          '• Connecting with the same WhatsApp credentials',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _selfDisconnect(ownerId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _selfDisconnect(String ownerId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/remove-agent.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'owner_id': ownerId,
          'agent_id': user.id,
          'mode': 'self_disconnect',
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack('Disconnected from shared WhatsApp');
        if (mounted) Navigator.of(context).pop();
      } else {
        _showSnack(body['error'] ?? 'Failed to disconnect');
      }
    } catch (e) {
      _showSnack('Network error: $e');
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _confirmTransfer(BuildContext context, String agentId, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Ownership?'),
        content: Text(
          'Are you sure you want to transfer ownership to $email?\n\n'
          '• They will become the new owner\n'
          '• You will become an agent\n'
          '• All data will remain shared',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isTransferring
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _transferOwnership(agentId);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, String ownerId, String agentId, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Agent?'),
        content: Text(
          'Remove $email from your agents?\n\n'
          'They will lose access to shared data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeAgent(ownerId, agentId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _transferOwnership(String newOwnerId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isTransferring = true);

    try {
      final db = FirebaseFirestore.instance;
      final oldOwnerId = user.id;
      final phoneId = user.whatsappPhoneNumberId;

      if (phoneId == null || phoneId.isEmpty) {
        _showSnack('WhatsApp not connected');
        return;
      }

      // 1. Update wa_map to new owner
      await db.collection('wa_map').doc(phoneId).update({
        'ownerId': newOwnerId,
      });

      // 2. Set dataOwner on old owner (now becomes agent)
      await db.collection('users').doc(oldOwnerId).set({
        'dataOwner': newOwnerId,
      }, SetOptions(merge: true));

      // 3. Clear dataOwner on new owner
      await db.collection('users').doc(newOwnerId).update({
        'dataOwner': FieldValue.delete(),
      });

      // 4. Remove new owner from old owner's agents
      await db.collection('users').doc(oldOwnerId)
          .collection('agents').doc(newOwnerId).delete();

      // 5. Move remaining agents to new owner's agents subcollection
      final remainingAgents = await db.collection('users')
          .doc(oldOwnerId).collection('agents').get();

      for (final agentDoc in remainingAgents.docs) {
        await db.collection('users').doc(newOwnerId)
            .collection('agents').doc(agentDoc.id).set(agentDoc.data());
        await db.collection('users').doc(agentDoc.id).update({
          'dataOwner': newOwnerId,
        });
        await agentDoc.reference.delete();
      }

      // 6. Add old owner as agent under new owner
      await db.collection('users').doc(newOwnerId)
          .collection('agents').doc(oldOwnerId).set({
        'email': user.email,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      _showSnack('Ownership transferred successfully! ✅');
    } catch (e) {
      _showSnack('Transfer failed: $e');
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  // ============ REMOVE AGENT — Uses Backend API ============
  Future<void> _removeAgent(String ownerId, String agentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/remove-agent.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'owner_id': ownerId,
          'agent_id': agentId,
          'mode': 'remove',
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack('Agent removed');
      } else {
        _showSnack(body['error'] ?? 'Failed to remove agent');
      }
    } catch (e) {
      _showSnack('Network error: $e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
}
