/// Riverpod providers for the Manager Approval workflow.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../models/goal_model.dart';

// ── Goal sheet summary (includes employee info from /team endpoint) ──────

class GoalSheetSummary {
  GoalSheetSummary({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    required this.employeeDepartment,
    required this.cycleId,
    required this.sheetStatus,
    required this.goals,
    required this.totalWeightage,
    this.submittedAt,
    this.approvedAt,
    this.managerComment,
    required this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final String employeeDepartment;
  final String cycleId;
  final String sheetStatus;
  final List<GoalItem> goals;
  final double totalWeightage;
  final String? submittedAt;
  final String? approvedAt;
  final String? managerComment;
  final String createdAt;

  int get goalCount => goals.length;

  factory GoalSheetSummary.fromJson(Map<String, dynamic> json) =>
      GoalSheetSummary(
        id: json['id'] as String? ?? '',
        employeeId: json['employeeId'] as String? ?? '',
        employeeName: json['employeeName'] as String? ?? '',
        employeeEmail: json['employeeEmail'] as String? ?? '',
        employeeDepartment: json['employeeDepartment'] as String? ?? '',
        cycleId: json['cycleId'] as String? ?? '',
        sheetStatus: json['sheetStatus'] as String? ?? '',
        goals: (json['goals'] as List<dynamic>?)
                ?.map((g) => GoalItem.fromJson(g as Map<String, dynamic>))
                .toList() ??
            [],
        totalWeightage: (json['totalWeightage'] as num?)?.toDouble() ?? 0,
        submittedAt: json['submittedAt'] as String?,
        approvedAt: json['approvedAt'] as String?,
        managerComment: json['managerComment'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}

// ── Pending approvals (status = submitted) ───────────────────────────────

final pendingApprovalsProvider =
    FutureProvider<List<GoalSheetSummary>>((ref) async {
  final auth = ref.read(authServiceProvider);
  final token = await auth.getCurrentIdToken();
  if (token == null) return [];

  final api = ref.read(apiClientProvider);
  final res = await api.get(
    '/goals/team?status=submitted',
    options: ApiClient.bearerOptions(token),
  );
  final list = res.data as List<dynamic>? ?? [];
  return list
      .map((j) => GoalSheetSummary.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ── All team goals ───────────────────────────────────────────────────────

final teamGoalsProvider =
    FutureProvider<List<GoalSheetSummary>>((ref) async {
  final auth = ref.read(authServiceProvider);
  final token = await auth.getCurrentIdToken();
  if (token == null) return [];

  final api = ref.read(apiClientProvider);
  final res = await api.get(
    '/goals/team',
    options: ApiClient.bearerOptions(token),
  );
  final list = res.data as List<dynamic>? ?? [];
  return list
      .map((j) => GoalSheetSummary.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ── Selected goal for review ─────────────────────────────────────────────

final selectedGoalProvider = StateProvider<GoalSheetSummary?>((ref) => null);

// ── Manager actions ──────────────────────────────────────────────────────

class ManagerGoalActions {
  ManagerGoalActions(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);

  Future<String?> approveGoalSheet(
    String goalId, {
    String? comment,
    List<Map<String, dynamic>>? editedGoals,
  }) async {
    final token = await _auth.getCurrentIdToken();
    if (token == null) return 'Not authenticated.';
    try {
      await _api.put(
        '/goals/$goalId/approve',
        data: {
          'comment': comment,
          'edited_goals': editedGoals,
        },
        options: ApiClient.bearerOptions(token),
      );
      // Refresh providers.
      _ref.invalidate(pendingApprovalsProvider);
      _ref.invalidate(teamGoalsProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> returnGoalSheet(String goalId, String comment) async {
    final token = await _auth.getCurrentIdToken();
    if (token == null) return 'Not authenticated.';
    try {
      await _api.put(
        '/goals/$goalId/return',
        data: {'comment': comment},
        options: ApiClient.bearerOptions(token),
      );
      _ref.invalidate(pendingApprovalsProvider);
      _ref.invalidate(teamGoalsProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final managerGoalActionsProvider =
    Provider<ManagerGoalActions>((ref) => ManagerGoalActions(ref));
