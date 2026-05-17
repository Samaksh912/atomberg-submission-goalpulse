/// Riverpod providers for the quarterly check-in system.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../models/checkin_model.dart';

// ── Fetch check-ins for a goal ID ────────────────────────────────────────

final checkinsByGoalProvider =
    FutureProvider.family<List<CheckinRecord>, String>((ref, goalId) async {
  final auth = ref.read(authServiceProvider);
  final token = await auth.getCurrentIdToken();
  if (token == null) return [];

  final api = ref.read(apiClientProvider);
  final res = await api.get(
    '/checkins/$goalId',
    options: ApiClient.bearerOptions(token),
  );
  final list = res.data as List<dynamic>? ?? [];
  return list
      .map((j) => CheckinRecord.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ── Check-in actions ─────────────────────────────────────────────────────

class CheckinActions {
  CheckinActions(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);

  /// Submit quarterly actuals. Returns null on success, error string on failure.
  Future<CheckinRecord?> submitCheckin({
    required String goalId,
    required String quarter,
    required List<Map<String, dynamic>> actuals,
  }) async {
    final token = await _auth.getCurrentIdToken();
    if (token == null) throw Exception('Not authenticated.');

    final res = await _api.post(
      '/checkins',
      data: {
        'goal_id': goalId,
        'quarter': quarter,
        'actuals': actuals,
      },
      options: ApiClient.bearerOptions(token),
    );
    return CheckinRecord.fromJson(res.data as Map<String, dynamic>);
  }

  /// Manager reviews a check-in.
  Future<void> managerReview(String checkinId, String comment) async {
    final token = await _auth.getCurrentIdToken();
    if (token == null) throw Exception('Not authenticated.');

    await _api.put(
      '/checkins/$checkinId/manager-review',
      data: {'comment': comment},
      options: ApiClient.bearerOptions(token),
    );
  }
}

final checkinActionsProvider =
    Provider<CheckinActions>((ref) => CheckinActions(ref));
