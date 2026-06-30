import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/contact/contact_model.dart';
import 'message_repository.dart';

/// 📇 CONTACT REPOSITORY — Full CRUD + Batch + Groups + Import/Export
class ContactRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  final MessageRepository _messageRepo = MessageRepository();

  CollectionReference<Map<String, dynamic>> _contacts(String userId) =>
      _firestore.user(userId).collection('contacts');

  // ============ REALTIME LIST ============
  Stream<List<ContactModel>> getContacts(String userId) {
    return _contacts(userId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContactModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET SINGLE ============
  Future<ContactModel?> getContact(String userId, String contactId) async {
    final doc = await _contacts(userId).doc(contactId).get();
    if (!doc.exists) return null;
    return ContactModel.fromJson(doc.data()!, doc.id);
  }

  // ============ SEARCH BY PHONE ============
  Future<ContactModel?> findByPhone(String userId, String phone) async {
    final query = await _contacts(userId)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return ContactModel.fromJson(query.docs.first.data(), query.docs.first.id);
  }

  // ============ CREATE ============
  Future<ContactModel> createContact(String userId, ContactModel contact) async {
    // Check duplicate phone
    final existing = await findByPhone(userId, contact.phone);
    if (existing != null) {
      throw Exception('A contact with this phone number already exists');
    }

    final ref = _contacts(userId).doc();
    final newContact = contact.copyWith(id: ref.id, createdAt: DateTime.now());
    await ref.set(newContact.toJson());

    // Increment totalContacts on user doc
    await _firestore.user(userId).update({
      'totalContacts': FieldValue.increment(1),
    });

    return newContact;
  }

  // ============ UPDATE ============
  Future<void> updateContact(String userId, ContactModel contact) async {
    await _contacts(userId).doc(contact.id).update(contact.toJson());
  }

  // ============ DELETE (with cascade) ============
  Future<void> deleteContact(String userId, String contactId) async {
    // Get the contact's phone before deleting
    final contact = await getContact(userId, contactId);
    
    await _contacts(userId).doc(contactId).delete();

    // Decrement totalContacts on user doc
    await _firestore.user(userId).update({
      'totalContacts': FieldValue.increment(-1),
    });

    // Cascade: delete conversation + all messages for this contact
    if (contact != null) {
      await _messageRepo.deleteConversationAndMessages(userId, contact.phone);
    }
  }

  // ============ DELETE MULTIPLE ============
  Future<int> deleteMultiple(String userId, List<String> contactIds) async {
    if (contactIds.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();
    for (final id in contactIds) {
      batch.delete(_contacts(userId).doc(id));
    }
    await batch.commit();

    // Decrement totalContacts
    await _firestore.user(userId).update({
      'totalContacts': FieldValue.increment(-contactIds.length),
    });

    return contactIds.length;
  }

  // ============ TOTAL COUNT ============
  Stream<int> getContactCount(String userId) {
    return _contacts(userId).snapshots().map((snap) => snap.docs.length);
  }

  // ============ GET BY TAG ============
  Stream<List<ContactModel>> getContactsByTag(String userId, String tag) {
    return _contacts(userId)
        .where('tags', arrayContains: tag)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContactModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET BY GROUP ============
  Stream<List<ContactModel>> getContactsByGroup(String userId, String group) {
    return _contacts(userId)
        .where('group', isEqualTo: group)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContactModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET ALL GROUPS ============
  Future<List<String>> getAllGroups(String userId) async {
    final snap = await _contacts(userId).get();
    final groups = <String>{};
    for (final doc in snap.docs) {
      final group = doc.data()['group'] as String?;
      if (group != null && group.isNotEmpty) {
        groups.add(group);
      }
    }
    return groups.toList()..sort();
  }

  // ============ GET ALL GROUPS (REALTIME STREAM) ============
  Stream<List<String>> getGroupsStream(String userId) {
    return _contacts(userId).snapshots().map((snap) {
      final groups = <String>{};
      for (final doc in snap.docs) {
        final group = doc.data()['group'] as String?;
        if (group != null && group.isNotEmpty) {
          groups.add(group);
        }
      }
      return groups.toList()..sort();
    });
  }

  // ============ IMPORT CONTACTS (BATCH) ============
  Future<int> importContacts(String userId, List<ContactModel> contacts) async {
    if (contacts.isEmpty) return 0;

    // Get existing phones to avoid duplicates
    final existingSnap = await _contacts(userId).get();
    final existingPhones = existingSnap.docs
        .map((doc) => (doc.data() as Map<String, dynamic>?)?['phone'] as String?)
        .whereType<String>()
        .toSet();

    final batch = FirebaseFirestore.instance.batch();
    int imported = 0;

    for (final contact in contacts) {
      if (existingPhones.contains(contact.phone)) continue;

      final ref = _contacts(userId).doc();
      final newContact = contact.copyWith(id: ref.id, createdAt: DateTime.now());
      batch.set(ref, newContact.toJson());
      imported++;

      // Firestore batch limit is 500
      if (imported % 400 == 0) {
        await batch.commit();
      }
    }

    if (imported > 0) {
      await batch.commit();
      await _firestore.user(userId).update({
        'totalContacts': FieldValue.increment(imported),
      });
    }

    return imported;
  }

  // ============ EXPORT ALL CONTACTS ============
  Future<List<ContactModel>> exportContacts(String userId) async {
    final snap = await _contacts(userId).orderBy('name').get();
    return snap.docs
        .map((doc) => ContactModel.fromJson(doc.data(), doc.id))
        .toList();
  }
}
