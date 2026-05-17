/// Analytics data providers for manager and admin analytics pages.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../features/auth/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class EmployeeCompletion {
  final String userId;
  final String name;
  final String department;
  final bool goalSubmitted;
  final bool goalApproved;
  final Map<String, bool> checkinsCompleted;

  EmployeeCompletion({
    required this.userId,
    required this.name,
    required this.department,
    required this.goalSubmitted,
    required this.goalApproved,
    required this.checkinsCompleted,
  });

  factory EmployeeCompletion.fromJson(Map<String, dynamic> j) =>
      EmployeeCompletion(
        userId: j['userId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        department: j['department'] as String? ?? '',
        goalSubmitted: j['goalSubmitted'] as bool? ?? false,
        goalApproved: j['goalApproved'] as bool? ?? false,
        checkinsCompleted: Map<String, bool>.from(
            (j['checkinsCompleted'] as Map? ?? {})
                .map((k, v) => MapEntry(k.toString(), v == true))),
      );
}

class CompletionDashboard {
  final double completionRate;
  final List<EmployeeCompletion> employees;

  CompletionDashboard({required this.completionRate, required this.employees});

  factory CompletionDashboard.fromJson(Map<String, dynamic> j) =>
      CompletionDashboard(
        completionRate: (j['completionRate'] as num?)?.toDouble() ?? 0.0,
        employees: ((j['employees'] as List?) ?? [])
            .map((e) =>
                EmployeeCompletion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class QoQTrends {
  final List<String> quarters;
  final List<double> avgScores;
  final List<double> goalCompletionRates;

  QoQTrends({
    required this.quarters,
    required this.avgScores,
    required this.goalCompletionRates,
  });

  factory QoQTrends.fromJson(Map<String, dynamic> j) => QoQTrends(
        quarters:
            ((j['quarters'] as List?) ?? []).map((q) => q.toString()).toList(),
        avgScores: ((j['avgScores'] as List?) ?? [])
            .map((v) => (v as num).toDouble())
            .toList(),
        goalCompletionRates: ((j['goalCompletionRates'] as List?) ?? [])
            .map((v) => (v as num).toDouble())
            .toList(),
      );
}

class ManagerEffectivenessItem {
  final String managerId;
  final String name;
  final double checkinRate;
  final double avgScore;
  final double avgTurnaroundDays;
  final int teamSize;

  ManagerEffectivenessItem({
    required this.managerId,
    required this.name,
    required this.checkinRate,
    required this.avgScore,
    required this.avgTurnaroundDays,
    required this.teamSize,
  });

  factory ManagerEffectivenessItem.fromJson(Map<String, dynamic> j) =>
      ManagerEffectivenessItem(
        managerId: j['managerId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        checkinRate: (j['checkinRate'] as num?)?.toDouble() ?? 0.0,
        avgScore: (j['avgScore'] as num?)?.toDouble() ?? 0.0,
        avgTurnaroundDays: (j['avgTurnaroundDays'] as num?)?.toDouble() ?? 0.0,
        teamSize: j['teamSize'] as int? ?? 0,
      );
}

class GoalDistribution {
  final Map<String, int> byThrustArea;
  final Map<String, int> byUomType;
  final Map<String, int> byStatus;

  GoalDistribution({
    required this.byThrustArea,
    required this.byUomType,
    required this.byStatus,
  });

  factory GoalDistribution.fromJson(Map<String, dynamic> j) =>
      GoalDistribution(
        byThrustArea: Map<String, int>.from(
            (j['byThrustArea'] as Map? ?? {})
                .map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
        byUomType: Map<String, int>.from(
            (j['byUomType'] as Map? ?? {})
                .map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
        byStatus: Map<String, int>.from(
            (j['byStatus'] as Map? ?? {})
                .map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
      );
}

// ── API Service ───────────────────────────────────────────────────────────────

class AnalyticsApiService {
  AnalyticsApiService(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);
  Future<String?> _token() => _auth.getCurrentIdToken();

  Future<CompletionDashboard> getCompletionDashboard(
      String cycleId, String? quarter) async {
    final token = await _token();
    final q = quarter != null ? '&quarter=$quarter' : '';
    final res = await _api.get(
      '/analytics/completion-dashboard?cycle_id=$cycleId$q',
      options: ApiClient.bearerOptions(token!),
    );
    return CompletionDashboard.fromJson(res.data as Map<String, dynamic>);
  }

  Future<QoQTrends> getQoQTrends(String cycleId,
      {String? employeeId, String? department}) async {
    final token = await _token();
    final params = [
      'cycle_id=$cycleId',
      if (employeeId != null) 'employee_id=$employeeId',
      if (department != null) 'department=$department',
    ].join('&');
    final res = await _api.get('/analytics/qoq-trends?$params',
        options: ApiClient.bearerOptions(token!));
    return QoQTrends.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ManagerEffectivenessItem>> getManagerEffectiveness(
      String cycleId) async {
    final token = await _token();
    final res = await _api.get(
      '/analytics/manager-effectiveness?cycle_id=$cycleId',
      options: ApiClient.bearerOptions(token!),
    );
    final data = res.data as Map<String, dynamic>;
    return ((data['managers'] as List?) ?? [])
        .map((j) =>
            ManagerEffectivenessItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<GoalDistribution> getGoalDistribution(String cycleId) async {
    final token = await _token();
    final res = await _api.get(
      '/analytics/goal-distribution?cycle_id=$cycleId',
      options: ApiClient.bearerOptions(token!),
    );
    return GoalDistribution.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getAchievementReport(
      String cycleId, String? quarter) async {
    final token = await _token();
    final q = quarter != null ? '&quarter=$quarter' : '';
    final res = await _api.get(
      '/analytics/reports/achievement?cycle_id=$cycleId&format=json$q',
      options: ApiClient.bearerOptions(token!),
    );
    return (res.data as List<dynamic>? ?? [])
        .map((j) => j as Map<String, dynamic>)
        .toList();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final analyticsApiProvider =
    Provider<AnalyticsApiService>((ref) => AnalyticsApiService(ref));

final completionDashboardProvider = FutureProvider.family<
    CompletionDashboard, (String, String?)>((ref, args) async {
  return ref
      .read(analyticsApiProvider)
      .getCompletionDashboard(args.$1, args.$2);
});

final qoqTrendsProvider =
    FutureProvider.family<QoQTrends, String>((ref, cycleId) async {
  return ref.read(analyticsApiProvider).getQoQTrends(cycleId);
});

final managerEffectivenessProvider =
    FutureProvider.family<List<ManagerEffectivenessItem>, String>(
        (ref, cycleId) async {
  return ref.read(analyticsApiProvider).getManagerEffectiveness(cycleId);
});

final goalDistributionProvider =
    FutureProvider.family<GoalDistribution, String>((ref, cycleId) async {
  return ref.read(analyticsApiProvider).getGoalDistribution(cycleId);
});
