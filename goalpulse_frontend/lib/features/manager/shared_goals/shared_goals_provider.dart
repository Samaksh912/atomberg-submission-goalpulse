/// Riverpod providers for the Shared Goals feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../models/shared_goal_model.dart';

// ── Fetch manager's shared goals ─────────────────────────────────────────

final sharedGoalsProvider =
    FutureProvider<List<SharedGoal>>((ref) async {
  final auth = ref.read(authServiceProvider);
  final token = await auth.getCurrentIdToken();
  if (token == null) return [];

  final api = ref.read(apiClientProvider);
  final res = await api.get(
    '/shared-goals',
    options: ApiClient.bearerOptions(token),
  );
  final list = res.data as List<dynamic>? ?? [];
  return list
      .map((j) => SharedGoal.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ── Push new shared goal ──────────────────────────────────────────────────

class SharedGoalActions {
  SharedGoalActions(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);

  /// Push a shared KPI to the team. Returns null on success, error on failure.
  Future<Map<String, dynamic>?> pushSharedGoal(
      Map<String, dynamic> data) async {
    final token = await _auth.getCurrentIdToken();
    if (token == null) throw Exception('Not authenticated.');

    final res = await _api.post(
      '/shared-goals',
      data: data,
      options: ApiClient.bearerOptions(token),
    );
    _ref.invalidate(sharedGoalsProvider);
    return res.data as Map<String, dynamic>?;
  }

  /// Employee updates their local weightage for a shared goal.
  Future<void> updateWeightage(String sharedGoalId, double weightage) async {
    final token = await _auth.getCurrentIdToken();
    if (token == null) throw Exception('Not authenticated.');

    await _api.put(
      '/shared-goals/$sharedGoalId/weightage',
      data: {'weightage': weightage},
      options: ApiClient.bearerOptions(token),
    );
  }
}

final sharedGoalActionsProvider =
    Provider<SharedGoalActions>((ref) => SharedGoalActions(ref));
