/// Riverpod providers and data models for the Admin Panel.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../features/auth/auth_provider.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class AdminUser {
  AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.managerId,
    this.department = '',
    this.designation = '',
    this.isActive = true,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String? managerId;
  final String department;
  final String designation;
  final bool isActive;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String? ?? '',
        email: j['email'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        role: j['role'] as String? ?? 'employee',
        managerId: j['manager_id'] as String?,
        department: j['department'] as String? ?? '',
        designation: j['designation'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
      );
}

class AuditLogEntry {
  AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.actorId,
    required this.action,
    this.actorRole = '',
    this.employeeId = '',
    this.fieldChanged = '',
    this.oldValue,
    this.newValue,
    this.reason = '',
    this.goalTitle = '',
  });

  final String id;
  final String timestamp;
  final String actorId;
  final String actorRole;
  final String action;
  final String employeeId;
  final String fieldChanged;
  final dynamic oldValue;
  final dynamic newValue;
  final String reason;
  final String goalTitle;

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
        id: j['id'] as String? ?? '',
        timestamp: j['timestamp'] as String? ?? '',
        actorId: j['actorId'] as String? ?? '',
        actorRole: j['actorRole'] as String? ?? '',
        action: j['action'] as String? ?? '',
        employeeId: j['employeeId'] as String? ?? '',
        fieldChanged: j['fieldChanged'] as String? ?? '',
        oldValue: j['oldValue'],
        newValue: j['newValue'],
        reason: j['reason'] as String? ?? '',
        goalTitle: j['goalTitle'] as String? ?? '',
      );
}

class PhaseWindow {
  final String? openDate;
  final String? closeDate;

  PhaseWindow({this.openDate, this.closeDate});

  factory PhaseWindow.fromJson(Map<String, dynamic> j) => PhaseWindow(
        openDate: j['openDate'] as String?,
        closeDate: j['closeDate'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'open_date': openDate, 'close_date': closeDate};
}

class Cycle {
  Cycle({
    required this.id,
    required this.year,
    required this.label,
    required this.isActive,
    required this.goalSetting,
    required this.q1,
    required this.q2,
    required this.q3,
    required this.q4,
    this.createdAt,
    this.activatedAt,
  });

  final String id;
  final int year;
  final String label;
  final bool isActive;
  final PhaseWindow goalSetting;
  final PhaseWindow q1;
  final PhaseWindow q2;
  final PhaseWindow q3;
  final PhaseWindow q4;
  final String? createdAt;
  final String? activatedAt;

  factory Cycle.fromJson(Map<String, dynamic> j) => Cycle(
        id: j['id'] as String? ?? '',
        year: j['year'] as int? ?? 0,
        label: j['label'] as String? ?? '',
        isActive: j['isActive'] as bool? ?? false,
        goalSetting: PhaseWindow.fromJson(
            (j['goalSetting'] as Map<String, dynamic>?) ?? {}),
        q1: PhaseWindow.fromJson((j['q1'] as Map<String, dynamic>?) ?? {}),
        q2: PhaseWindow.fromJson((j['q2'] as Map<String, dynamic>?) ?? {}),
        q3: PhaseWindow.fromJson((j['q3'] as Map<String, dynamic>?) ?? {}),
        q4: PhaseWindow.fromJson((j['q4'] as Map<String, dynamic>?) ?? {}),
        createdAt: j['createdAt'] as String?,
        activatedAt: j['activatedAt'] as String?,
      );
}

class OrgStats {
  final int totalEmployees;
  final int goalsSubmitted;
  final int goalsApproved;
  final int pendingApprovals;
  final int checkinCompletionRate;

  OrgStats({
    this.totalEmployees = 0,
    this.goalsSubmitted = 0,
    this.goalsApproved = 0,
    this.pendingApprovals = 0,
    this.checkinCompletionRate = 0,
  });

  factory OrgStats.fromJson(Map<String, dynamic> j) => OrgStats(
        totalEmployees: j['total_employees'] as int? ?? 0,
        goalsSubmitted: j['goals_submitted'] as int? ?? 0,
        goalsApproved: j['goals_approved'] as int? ?? 0,
        pendingApprovals: j['pending_approvals'] as int? ?? 0,
        checkinCompletionRate: j['checkin_completion_rate'] as int? ?? 0,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class AdminApiService {
  AdminApiService(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);

  Future<String?> _token() => _auth.getCurrentIdToken();

  Future<Map<String, dynamic>> getUsers({
    String search = '',
    String role = '',
    int page = 1,
  }) async {
    final token = await _token();
    final res = await _api.get(
      '/admin/users?search=$search&role=$role&page=$page&page_size=20',
      options: ApiClient.bearerOptions(token!),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    final token = await _token();
    await _api.post('/admin/users',
        data: data, options: ApiClient.bearerOptions(token!));
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    final token = await _token();
    await _api.put('/admin/users/$userId',
        data: data, options: ApiClient.bearerOptions(token!));
  }

  Future<Map<String, dynamic>> getAuditLogs({
    String? startDate,
    String? endDate,
    String? actorId,
    String? action,
    int page = 1,
  }) async {
    final token = await _token();
    final params = <String, String>{
      'page': '$page',
      'page_size': '50',
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (actorId != null && actorId.isNotEmpty) 'actor_id': actorId,
      if (action != null && action.isNotEmpty) 'action': action,
    };
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _api.get('/admin/audit-logs?$query',
        options: ApiClient.bearerOptions(token!));
    return res.data as Map<String, dynamic>;
  }

  Future<List<Cycle>> getCycles() async {
    final token = await _token();
    final res = await _api.get('/admin/cycles',
        options: ApiClient.bearerOptions(token!));
    return (res.data as List<dynamic>)
        .map((j) => Cycle.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Cycle?> getActiveCycle() async {
    final token = await _token();
    final res = await _api.get('/admin/cycles/active',
        options: ApiClient.bearerOptions(token!));
    if (res.data == null) return null;
    return Cycle.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Cycle> createCycle(Map<String, dynamic> data) async {
    final token = await _token();
    final res = await _api.post('/admin/cycles',
        data: data, options: ApiClient.bearerOptions(token!));
    return Cycle.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Cycle> updateCycle(String cycleId, Map<String, dynamic> data) async {
    final token = await _token();
    final res = await _api.put('/admin/cycles/$cycleId',
        data: data, options: ApiClient.bearerOptions(token!));
    return Cycle.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> activateCycle(String cycleId) async {
    final token = await _token();
    await _api.post('/admin/cycles/$cycleId/activate',
        options: ApiClient.bearerOptions(token!));
  }

  Future<OrgStats> getOrgStats() async {
    final token = await _token();
    final res = await _api.get('/admin/stats',
        options: ApiClient.bearerOptions(token!));
    return OrgStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getApprovedGoals(
      {String search = ''}) async {
    final token = await _token();
    final res = await _api.get(
      '/goals?search=$search&status=approved',
      options: ApiClient.bearerOptions(token!),
    );
    final list = res.data as List<dynamic>? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  }

  Future<void> unlockGoalItem(
      String goalId, String goalItemId, String reason) async {
    final token = await _token();
    await _api.post(
      '/goals/$goalId/unlock-item',
      data: {'goal_item_id': goalItemId, 'reason': reason},
      options: ApiClient.bearerOptions(token!),
    );
  }

  Future<List<Map<String, dynamic>>> getAllGoals() async {
    final token = await _token();
    final res = await _api.get('/goals',
        options: ApiClient.bearerOptions(token!));
    final list = res.data as List<dynamic>? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final adminApiProvider =
    Provider<AdminApiService>((ref) => AdminApiService(ref));

final orgStatsProvider = FutureProvider<OrgStats>((ref) async {
  return ref.read(adminApiProvider).getOrgStats();
});

final cyclesProvider = FutureProvider<List<Cycle>>((ref) async {
  return ref.read(adminApiProvider).getCycles();
});

final activeCycleProvider = FutureProvider<Cycle?>((ref) async {
  return ref.read(adminApiProvider).getActiveCycle();
});
