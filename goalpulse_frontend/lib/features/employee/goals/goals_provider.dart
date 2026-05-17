/// Riverpod providers for Goal Sheet state management.
///
/// [goalSheetProvider] – server-side goal sheet (fetched from API).
/// [localDraftGoalsProvider] – local form state for the goal builder.
/// [weightageValidationProvider] – derived validation state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../models/goal_model.dart';

// ── Draft goal (local form state) ────────────────────────────────────────

/// Mutable draft goal used while editing in the goal builder form.
class GoalItemDraft {
  GoalItemDraft({
    this.thrustArea = '',
    this.title = '',
    this.description = '',
    this.uomType = '',
    this.target,
    this.weightage = 10,
    this.isShared = false,
    this.sharedGoalId,
  });

  String thrustArea;
  String title;
  String description;
  String uomType;
  dynamic target;
  double weightage;
  bool isShared;
  String? sharedGoalId;

  GoalItemDraft copyWith({
    String? thrustArea,
    String? title,
    String? description,
    String? uomType,
    dynamic target,
    double? weightage,
    bool? isShared,
    String? sharedGoalId,
  }) =>
      GoalItemDraft(
        thrustArea: thrustArea ?? this.thrustArea,
        title: title ?? this.title,
        description: description ?? this.description,
        uomType: uomType ?? this.uomType,
        target: target ?? this.target,
        weightage: weightage ?? this.weightage,
        isShared: isShared ?? this.isShared,
        sharedGoalId: sharedGoalId ?? this.sharedGoalId,
      );

  /// Whether required fields are filled.
  bool get isValid =>
      thrustArea.isNotEmpty &&
      title.isNotEmpty &&
      uomType.isNotEmpty &&
      target != null;

  Map<String, dynamic> toApiJson() => {
        'thrust_area': thrustArea,
        'title': title,
        'description': description,
        'uom_type': uomType,
        'target': target,
        'weightage': weightage,
      };
}

// ── Weightage validation ─────────────────────────────────────────────────

class WeightageValidation {
  const WeightageValidation({
    required this.total,
    required this.isValid,
    required this.hasUnderMinimum,
    required this.goalCount,
    required this.isOverLimit,
  });

  final double total;
  final bool isValid;
  final bool hasUnderMinimum;
  final int goalCount;
  final bool isOverLimit;
}

final weightageValidationProvider =
    Provider<WeightageValidation>((ref) {
  final goals = ref.watch(localDraftGoalsProvider);
  final total = goals.fold<double>(0, (sum, g) => sum + g.weightage);
  return WeightageValidation(
    total: total,
    isValid: (total - 100.0).abs() < 0.01,
    hasUnderMinimum: goals.any((g) => g.weightage < 10),
    goalCount: goals.length,
    isOverLimit: goals.length > 8,
  );
});

// ── Local draft goals ────────────────────────────────────────────────────

final localDraftGoalsProvider =
    StateProvider<List<GoalItemDraft>>((ref) => []);

// ── Goal sheet from API ──────────────────────────────────────────────────

final goalSheetProvider =
    StateNotifierProvider<GoalSheetNotifier, AsyncValue<GoalSheet?>>(
  (ref) => GoalSheetNotifier(ref),
);

class GoalSheetNotifier extends StateNotifier<AsyncValue<GoalSheet?>> {
  GoalSheetNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);

  Future<String?> _getToken() => _auth.getCurrentIdToken();

  // ── Fetch ──────────────────────────────────────────────────────────────

  Future<void> fetchGoalSheet({String cycleId = 'cycle_2025'}) async {
    state = const AsyncValue.loading();
    try {
      final token = await _getToken();
      if (token == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final res = await _api.get(
        '/goals/my?cycle_id=$cycleId',
        options: ApiClient.bearerOptions(token),
      );
      if (res.data == null || res.data == '') {
        state = const AsyncValue.data(null);
      } else {
        final sheet = GoalSheet.fromJson(res.data as Map<String, dynamic>);
        state = AsyncValue.data(sheet);
        // Sync to local draft.
        _syncDraftFromSheet(sheet);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _syncDraftFromSheet(GoalSheet sheet) {
    final drafts = sheet.goals
        .map((g) => GoalItemDraft(
              thrustArea: g.thrustArea,
              title: g.title,
              description: g.description,
              uomType: g.uomType,
              target: g.target,
              weightage: g.weightage,
              isShared: g.isShared,
              sharedGoalId: g.sharedGoalId,
            ))
        .toList();
    _ref.read(localDraftGoalsProvider.notifier).state = drafts;
  }

  // ── Create / Update ────────────────────────────────────────────────────

  Future<String?> createOrUpdateGoals({
    String cycleId = 'cycle_2025',
  }) async {
    final token = await _getToken();
    if (token == null) return 'Not authenticated.';

    final drafts = _ref.read(localDraftGoalsProvider);
    final goalsJson = drafts.map((d) => d.toApiJson()).toList();
    final body = {'cycle_id': cycleId, 'goals': goalsJson};
    final opts = ApiClient.bearerOptions(token);

    try {
      final existing = state.valueOrNull;
      if (existing != null && existing.id.isNotEmpty) {
        // Update.
        await _api.put('/goals/${existing.id}', data: body, options: opts);
      } else {
        // Create.
        await _api.post('/goals', data: body, options: opts);
      }
      await fetchGoalSheet(cycleId: cycleId);
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<String?> submitForApproval() async {
    final token = await _getToken();
    if (token == null) return 'Not authenticated.';
    final existing = state.valueOrNull;
    if (existing == null || existing.id.isEmpty) return 'No goal sheet found.';

    try {
      await _api.post(
        '/goals/${existing.id}/submit',
        options: ApiClient.bearerOptions(token),
      );
      await fetchGoalSheet(cycleId: existing.cycleId);
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }
}
