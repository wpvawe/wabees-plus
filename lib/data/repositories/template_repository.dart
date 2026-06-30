import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/template/template_model.dart';
import 'whatsapp_repository.dart';

/// 📋 TEMPLATE REPOSITORY
/// Manages template CRUD in Firestore + Meta API sync
class TemplateRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  final WhatsappRepository _whatsappRepo = WhatsappRepository();

  CollectionReference<Map<String, dynamic>> _templates(String userId) =>
      _firestore.user(userId).collection('templates');

  // ============ REALTIME LIST ============
  Stream<List<TemplateModel>> getTemplates(String userId) {
    return _templates(userId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TemplateModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET SINGLE ============
  Future<TemplateModel?> getTemplate(String userId, String templateId) async {
    final doc = await _templates(userId).doc(templateId).get();
    if (!doc.exists) return null;
    return TemplateModel.fromJson(doc.data()!, doc.id);
  }

  // ============ FIND BY NAME ============
  Future<TemplateModel?> findByName(String userId, String name) async {
    final snap = await _templates(userId)
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TemplateModel.fromJson(snap.docs.first.data(), snap.docs.first.id);
  }

  // ============ CREATE (LOCAL ONLY) ============
  Future<TemplateModel> createTemplate(String userId, TemplateModel template) async {
    final ref = _templates(userId).doc();
    final newTemplate = template.copyWith(
      id: ref.id,
      createdAt: DateTime.now(),
      isSynced: false,
    );
    await ref.set(newTemplate.toJson());
    return newTemplate;
  }

  // ============ CREATE ON META + LOCAL ============
  Future<TemplateModel> createOnMeta(String userId, TemplateModel template) async {
    // 1. Create on Meta API
    final result = await _whatsappRepo.createTemplateOnMeta(
      userId: userId,
      name: template.name,
      category: template.category,
      language: template.languageCode,
      body: template.body,
      header: template.header,
      footer: template.footer,
      variableSamples: template.variableSamples.isEmpty ? null : template.variableSamples,
      variableTypes: template.variableTypes.isEmpty ? null : template.variableTypes,
      buttons: template.buttons.isEmpty ? null : template.buttons,
    );

    if (!result.success) {
      throw Exception(result.message ?? 'Failed to create template on WhatsApp');
    }

    // 2. Extract Meta template ID from response
    final metaId = result.data?['id']?.toString();
    final status = result.data?['status']?.toString() ?? 'PENDING';

    // 3. Save to local Firestore
    final ref = _templates(userId).doc();
    final newTemplate = template.copyWith(
      id: ref.id,
      metaTemplateId: metaId,
      status: status,
      isSynced: true,
      createdAt: DateTime.now(),
    );
    await ref.set(newTemplate.toJson());
    return newTemplate;
  }

  // ============ EDIT ON META + LOCAL ============
  Future<void> editOnMeta(String userId, TemplateModel template) async {
    if (template.metaTemplateId == null || template.metaTemplateId!.isEmpty) {
      throw Exception('Cannot edit: template has no Meta ID. Try syncing first.');
    }

    // 1. Edit on Meta API
    final result = await _whatsappRepo.editTemplateOnMeta(
      userId: userId,
      templateId: template.metaTemplateId!,
      body: template.body,
      header: template.header,
      footer: template.footer,
    );

    if (!result.success) {
      throw Exception(result.message ?? 'Failed to edit template on WhatsApp');
    }

    // 2. Update Firestore — status goes back to PENDING after edit
    await _templates(userId).doc(template.id).update({
      'body': template.body,
      'header': template.header,
      'footer': template.footer,
      'variables': template.variables,
      'status': 'PENDING',
      'isSynced': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ DELETE ON META + LOCAL ============
  Future<void> deleteOnMeta(String userId, TemplateModel template) async {
    // 1. Delete on Meta if it has a Meta ID
    if (template.isSynced && template.metaTemplateId != null) {
      final result = await _whatsappRepo.deleteTemplateOnMeta(
        userId: userId,
        templateName: template.name,
      );
      if (!result.success) {
        final msg = (result.message ?? '').toLowerCase();
        // Only ignore "not found" / "does not exist" — means already deleted on Meta
        if (msg.contains('not found') || msg.contains('does not exist')) {
          // Safe to continue with local delete
        } else if (msg.contains('sample template') || msg.contains("can't be edited")) {
          // Meta sample templates cannot be deleted — give a friendly error
          throw Exception(
            'This is a Meta sample template and cannot be deleted from WhatsApp.',
          );
        } else {
          // ALL other errors should BLOCK local delete
          throw Exception(
            'Failed to delete "${template.name}" from WhatsApp: ${result.message ?? 'Unknown error'}',
          );
        }
      }
    }

    // 2. Delete from local Firestore (only reached if Meta delete succeeded or template not synced)
    await _templates(userId).doc(template.id).delete();
  }

  // ============ UPDATE LOCAL ONLY ============
  Future<void> updateTemplate(String userId, TemplateModel template) async {
    await _templates(userId).doc(template.id).update({
      ...template.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ DELETE LOCAL ONLY ============
  Future<void> deleteTemplate(String userId, String templateId) async {
    await _templates(userId).doc(templateId).delete();
  }

  // ============ SYNC FROM META ============
  Future<int> syncFromMeta(String userId) async {
    final result = await _whatsappRepo.getTemplates(userId);
    if (!result.success) return 0;

    final data = result.data?['data'] as List? ?? [];
    int synced = 0;

    for (final tpl in data) {
      final template = TemplateModel.fromMetaApi(tpl as Map<String, dynamic>);

      // Check if already exists by name
      final existing = await _templates(userId)
          .where('name', isEqualTo: template.name)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing — preserve local doc ID, update content + status
        await existing.docs.first.reference.update({
          'metaTemplateId': template.metaTemplateId,
          'body': template.body,
          'header': template.header,
          'footer': template.footer,
          'buttons': template.buttons,
          'category': template.category,
          'status': template.status,
          'variables': template.variables,
          'qualityScore': template.qualityScore,
          'isSynced': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new
        final ref = _templates(userId).doc();
        await ref.set(template.copyWith(id: ref.id).toJson());
      }
      synced++;
    }

    return synced;
  }
}
