import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contact/contact_model.dart';
import '../../data/repositories/contact_repository.dart';
import '../auth/auth_provider.dart';

// ============ REPOSITORY ============
final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository();
});

// ============ CONTACTS LIST (REALTIME) ============
final contactsProvider = StreamProvider<List<ContactModel>>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(contactRepositoryProvider);
  return repo.getContacts(ownerId);
});

// ============ PHONE → NAME LOOKUP MAP ============
/// Maps normalized phone numbers to saved contact names for display fallback
final contactNameMapProvider = Provider<Map<String, String>>((ref) {
  final contacts = ref.watch(contactsProvider).valueOrNull ?? [];
  final map = <String, String>{};
  for (final c in contacts) {
    final phone = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isNotEmpty && c.name.isNotEmpty) {
      map[phone] = c.name;
      // Also store with + prefix
      map['+$phone'] = c.name;
    }
  }
  return map;
});

// ============ CONTACT COUNT ============
final contactCountProvider = StreamProvider<int>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value(0);

  final repo = ref.watch(contactRepositoryProvider);
  return repo.getContactCount(ownerId);
});

// ============ CONTACTS BY GROUP ============
final contactsByGroupProvider =
    StreamProvider.family<List<ContactModel>, String>((ref, group) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(contactRepositoryProvider);
  return repo.getContactsByGroup(ownerId, group);
});

// ============ ALL GROUPS LIST (REALTIME) ============
final contactGroupsProvider = StreamProvider<List<String>>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(contactRepositoryProvider);
  return repo.getGroupsStream(ownerId);
});

// ============ CONTACT MANAGEMENT NOTIFIER ============
class ContactNotifier extends StateNotifier<ContactActionState> {
  final ContactRepository _repo;
  final String _userId;

  ContactNotifier(this._repo, this._userId) : super(const ContactActionState());

  Future<bool> create(ContactModel contact) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.createContact(_userId, contact);
      if (mounted) state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> update(ContactModel contact) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateContact(_userId, contact);
      if (mounted) state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String contactId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteContact(_userId, contactId);
      if (mounted) state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Bulk delete multiple contacts
  Future<int> deleteMultiple(List<String> contactIds) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final count = await _repo.deleteMultiple(_userId, contactIds);
      if (mounted) state = state.copyWith(isLoading: false);
      return count;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      return 0;
    }
  }

  /// Import contacts from parsed list
  Future<int> importContacts(List<ContactModel> contacts) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final count = await _repo.importContacts(_userId, contacts);
      if (mounted) state = state.copyWith(isLoading: false);
      return count;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      return 0;
    }
  }

  /// Export all contacts
  Future<List<ContactModel>> exportContacts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final contacts = await _repo.exportContacts(_userId);
      if (mounted) state = state.copyWith(isLoading: false);
      return contacts;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      return [];
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

class ContactActionState {
  final bool isLoading;
  final String? error;

  const ContactActionState({this.isLoading = false, this.error});

  ContactActionState copyWith({bool? isLoading, String? error}) {
    return ContactActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final contactNotifierProvider =
    StateNotifierProvider<ContactNotifier, ContactActionState>((ref) {
  final repo = ref.watch(contactRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final ownerId = user?.dataOwner ?? user?.id ?? '';
  return ContactNotifier(repo, ownerId);
});
