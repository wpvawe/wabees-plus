import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';
import '../../../data/datasources/api/whatsapp_api_ds.dart';

/// 🔧 DIAGNOSTIC SCREEN — Shows WhatsApp config, Firestore, and send test
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  final List<String> _logs = [];
  bool _running = false;

  void _log(String msg) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _logs.clear();
      _running = true;
    });

    try {
      // 1. Check Auth
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _log('❌ AUTH: Not logged in');
        setState(() => _running = false);
        return;
      }
      _log('✅ AUTH: uid=${user.id}');
      _log('   email=${user.email}');

      // 2. Check Firestore Connection
      _log('🔄 FIRESTORE: Testing connection...');
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();
        if (userDoc.exists) {
          _log('✅ FIRESTORE: User doc exists');
          final data = userDoc.data() ?? {};
          _log('   whatsappConnected=${data['whatsappConnected']}');
          _log('   whatsappPhoneNumberId=${data['whatsappPhoneNumberId']}');
          final fcm = data['fcmToken'] as String?;
          _log('   fcmToken=${fcm != null ? 'SET (${fcm.length > 20 ? fcm.substring(0, 20) : fcm}...)' : 'NULL'}');
        } else {
          _log('❌ FIRESTORE: User doc NOT FOUND');
        }
      } catch (e) {
        _log('❌ FIRESTORE: Error reading user doc: $e');
      }

      // 3. Check WhatsApp Config
      _log('🔄 WA_CONFIG: Reading whatsapp_config/config...');
      try {
        final configDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('whatsapp_config')
            .doc('config')
            .get();
        if (configDoc.exists) {
          final data = configDoc.data() ?? {};
          final phoneNumberId = data['phoneNumberId'] ?? '';
          final accessToken = data['accessToken'] ?? '';
          final isConnected = data['isConnected'] ?? false;
          _log('✅ WA_CONFIG: Doc exists');
          _log('   phoneNumberId=${phoneNumberId.isNotEmpty ? phoneNumberId : "EMPTY!"}');
          _log('   accessToken=${accessToken.isNotEmpty ? "${accessToken.length > 20 ? accessToken.substring(0, 20) : accessToken}..." : "EMPTY!"}');
          _log('   isConnected=$isConnected');
          _log('   displayPhoneNumber=${data['displayPhoneNumber'] ?? 'null'}');

          if (phoneNumberId.isEmpty || accessToken.isEmpty) {
            _log('❌ WA_CONFIG: MISSING CREDENTIALS — This is why messages fail!');
          }
        } else {
          _log('❌ WA_CONFIG: Doc NOT FOUND — WhatsApp not set up!');
        }
      } catch (e) {
        _log('❌ WA_CONFIG: Error reading config: $e');
      }

      // 4. Check WhatsApp Config via Repository (cached)
      _log('🔄 WA_REPO: Checking cached config from WhatsappRepository...');
      try {
        final config = await ref.read(whatsappRepositoryProvider).getConfig(user.id);
        _log('   hasCredentials=${config.hasCredentials}');
        _log('   phoneNumberId=${config.phoneNumberId.isNotEmpty ? config.phoneNumberId : "EMPTY"}');
        _log('   accessToken=${config.accessToken.isNotEmpty ? "${config.accessToken.length > 20 ? config.accessToken.substring(0, 20) : config.accessToken}..." : "EMPTY"}');
        _log('   isConnected=${config.isConnected}');
      } catch (e) {
        _log('❌ WA_REPO: Error: $e');
      }

      // 5. Check Conversations Count
      _log('🔄 CONVERSATIONS: Counting...');
      try {
        final convSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('conversations')
            .get();
        _log('✅ CONVERSATIONS: ${convSnap.docs.length} found');
        for (final doc in convSnap.docs.take(3)) {
          final data = doc.data();
          _log('   ${doc.id}: ${data['contactName'] ?? 'Unknown'} — ${data['lastMessage'] ?? ''}');
        }
      } catch (e) {
        _log('❌ CONVERSATIONS: Error: $e');
      }

      // 6. Check Messages Count
      _log('🔄 MESSAGES: Counting...');
      try {
        final msgSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('messages')
            .limit(10)
            .get();
        _log('✅ MESSAGES: ${msgSnap.docs.length} recent messages');
        for (final doc in msgSnap.docs.take(3)) {
          final data = doc.data();
          final body = data['body']?.toString() ?? '';
          final preview = body.length > 30 ? '${body.substring(0, 30)}...' : body;
          _log('   ${data['direction']}: ${data['contactPhone']} — $preview');
        }
      } catch (e) {
        _log('❌ MESSAGES: Error: $e');
      }

      // 7. Test API connectivity
      _log('🔄 API: Testing connectivity to api.wabees.live...');
      try {
        final api = WhatsappApiDs();
        final config = await ref.read(whatsappRepositoryProvider).getConfig(user.id);
        if (config.hasCredentials) {
          final result = await api.verifyConnection(
            phoneNumberId: config.phoneNumberId,
            accessToken: config.accessToken,
          );
          _log('${result.success ? "✅" : "❌"} API: verify=${result.success}');
          if (!result.success) {
            _log('   Error: ${result.message}');
          }
        } else {
          _log('⚠️ API: Skipped — no credentials');
        }
      } catch (e) {
        _log('❌ API: Error: $e');
      }

      // 8. Check Firestore real-time listener
      _log('🔄 REALTIME: Testing snapshot listener...');
      try {
        bool received = false;
        final sub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('conversations')
            .orderBy('lastMessageAt', descending: true)
            .limit(1)
            .snapshots()
            .listen((snap) {
          if (!received) {
            received = true;
            _log('✅ REALTIME: Snapshot received (${snap.docs.length} docs)');
          }
        }, onError: (e) {
          _log('❌ REALTIME: Listener error: $e');
        });

        // Wait 5 seconds for snapshot
        await Future.delayed(const Duration(seconds: 5));
        sub.cancel();
        if (!received) {
          _log('❌ REALTIME: No snapshot after 5s — Firestore listener NOT working!');
        }
      } catch (e) {
        _log('❌ REALTIME: Error: $e');
      }

    } catch (e) {
      _log('❌ UNKNOWN ERROR: $e');
    }

    setState(() => _running = false);
    _log('--- Diagnostics Complete ---');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Diagnostics'),
        actions: [
          IconButton(
            onPressed: _running ? null : _runDiagnostics,
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Run Diagnostics',
          ),
          if (_logs.isNotEmpty)
            IconButton(
              onPressed: () {
                final allLogs = _logs.join('\n');
                Clipboard.setData(ClipboardData(text: allLogs));
                // Use snackbar to show copied
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_logs.length} log lines copied')),
                );
              },
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Logs',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_logs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Press ▶ to run diagnostics',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This checks WhatsApp config,\nFirestore connection, and API access',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (ctx, i) {
                  final log = _logs[i];
                  Color color;
                  if (log.contains('✅')) {
                    color = Colors.green;
                  } else if (log.contains('❌')) {
                    color = Colors.red;
                  } else if (log.contains('⚠️')) {
                    color = Colors.orange;
                  } else if (log.contains('🔄')) {
                    color = Colors.blue;
                  } else {
                    color = Colors.grey.shade700;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_running)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _running ? null : _runDiagnostics,
        child: _running
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.play_arrow),
      ),
    );
  }
}
