import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/template/template_model.dart';
import '../../data/repositories/template_repository.dart';
import '../../data/repositories/whatsapp_repository.dart';
import '../auth/auth_provider.dart';

// ============ REPOSITORY ============
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository();
});

final whatsappRepoProvider = Provider<WhatsappRepository>((ref) {
  return WhatsappRepository();
});

// ============ TEMPLATES LIST (REALTIME) ============
final templatesProvider = StreamProvider<List<TemplateModel>>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value([]);

  final repo = ref.watch(templateRepositoryProvider);
  return repo.getTemplates(userId);
});

// ============ APPROVED TEMPLATES (for campaign picker) ============
final approvedTemplatesProvider = Provider<AsyncValue<List<TemplateModel>>>((ref) {
  final templatesAsync = ref.watch(templatesProvider);
  return templatesAsync.whenData((templates) {
    return templates.where((t) => t.status.toUpperCase() == 'APPROVED').toList();
  });
});

// ============ FILTERS ============
final templateCategoryFilterProvider = StateProvider<String>((ref) => 'ALL');
final templateStatusFilterProvider = StateProvider<String>((ref) => 'ALL');
final templateSearchQueryProvider = StateProvider<String>((ref) => '');

// ============ FILTERED TEMPLATES (CATEGORY + STATUS + SEARCH) ============
final filteredTemplatesProvider = Provider<AsyncValue<List<TemplateModel>>>((ref) {
  final templatesAsync = ref.watch(templatesProvider);
  final category = ref.watch(templateCategoryFilterProvider);
  final status = ref.watch(templateStatusFilterProvider);
  final search = ref.watch(templateSearchQueryProvider).toLowerCase();

  return templatesAsync.whenData((templates) {
    var filtered = templates.toList();

    // Category filter
    if (category != 'ALL') {
      filtered = filtered
          .where((t) => t.category.toUpperCase() == category.toUpperCase())
          .toList();
    }

    // Status filter
    if (status != 'ALL') {
      filtered = filtered
          .where((t) => t.status.toUpperCase() == status.toUpperCase())
          .toList();
    }

    // Search filter (by name or body)
    if (search.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.name.toLowerCase().contains(search) ||
            t.body.toLowerCase().contains(search);
      }).toList();
    }

    return filtered;
  });
});

// ============ TEMPLATE STATS ============
final templateStatsProvider = Provider<Map<String, int>>((ref) {
  final templatesAsync = ref.watch(templatesProvider);
  return templatesAsync.when(
    data: (templates) {
      final stats = <String, int>{
        'total': templates.length,
        'approved': templates.where((t) => t.isApproved).length,
        'pending': templates.where((t) => t.isPending).length,
        'rejected': templates.where((t) => t.isRejected).length,
        'paused': templates.where((t) => t.isPaused).length,
        'marketing': templates.where((t) => t.category == 'MARKETING').length,
        'utility': templates.where((t) => t.category == 'UTILITY').length,
        'authentication': templates.where((t) => t.category == 'AUTHENTICATION').length,
      };
      return stats;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

// ============ TEMPLATE MANAGEMENT NOTIFIER ============
class TemplateNotifier extends StateNotifier<TemplateActionState> {
  final TemplateRepository _repo;
  final WhatsappRepository _whatsappRepo;
  final String _userId;

  TemplateNotifier(this._repo, this._whatsappRepo, this._userId)
      : super(const TemplateActionState());

  /// Create template on Meta API + save to Firestore
  Future<bool> create(TemplateModel template) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.createOnMeta(_userId, template);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanError(e));
      return false;
    }
  }

  /// Edit template on Meta API + update Firestore
  Future<bool> update(TemplateModel template) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (template.canEdit) {
        await _repo.editOnMeta(_userId, template);
      } else {
        // Fallback to local-only update if no Meta ID
        await _repo.updateTemplate(_userId, template);
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanError(e));
      return false;
    }
  }

  /// Delete template from Meta API + Firestore
  Future<bool> delete(TemplateModel template) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteOnMeta(_userId, template);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanError(e));
      return false;
    }
  }

  /// Sync all templates from Meta API → Firestore
  Future<int> syncFromMeta() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final count = await _repo.syncFromMeta(_userId);
      state = state.copyWith(isLoading: false);
      return count;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanError(e));
      return 0;
    }
  }

  /// Send a template message via WhatsApp API
  Future<bool> sendTemplate({
    required String to,
    required String templateName,
    required String languageCode,
    List<Map<String, dynamic>>? components,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _whatsappRepo.sendTemplate(
        userId: _userId,
        to: to,
        templateName: templateName,
        languageCode: languageCode,
        components: components,
      );
      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.message ?? 'Failed to send template',
        );
        return false;
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanError(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  /// Clean error message — remove 'Exception:' prefix
  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    return msg;
  }
}

class TemplateActionState {
  final bool isLoading;
  final String? error;

  const TemplateActionState({this.isLoading = false, this.error});

  TemplateActionState copyWith({bool? isLoading, String? error}) {
    return TemplateActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final templateNotifierProvider =
    StateNotifierProvider<TemplateNotifier, TemplateActionState>((ref) {
  final repo = ref.watch(templateRepositoryProvider);
  final whatsappRepo = ref.watch(whatsappRepoProvider);
  final user = ref.watch(currentUserProvider);
  return TemplateNotifier(repo, whatsappRepo, user?.id ?? '');
});
