/// AI features provider — Gemini-backed suggestions, summaries, and risk alerts.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../features/auth/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class GoalSuggestion {
  final String title;
  final String description;
  final String uomType;
  final String recommendedTarget;
  final String rationale;

  GoalSuggestion({
    required this.title,
    required this.description,
    required this.uomType,
    required this.recommendedTarget,
    required this.rationale,
  });

  factory GoalSuggestion.fromJson(Map<String, dynamic> j) => GoalSuggestion(
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        uomType: j['uom_type'] as String? ?? 'numeric_max',
        recommendedTarget: j['recommended_target']?.toString() ?? '',
        rationale: j['rationale'] as String? ?? '',
      );
}

class KpiRecommendation {
  final String uomType;
  final String targetSuggestion;
  final String rationale;

  KpiRecommendation({
    required this.uomType,
    required this.targetSuggestion,
    required this.rationale,
  });

  factory KpiRecommendation.fromJson(Map<String, dynamic> j) =>
      KpiRecommendation(
        uomType: j['uom_type'] as String? ?? 'numeric_max',
        targetSuggestion: j['target_suggestion']?.toString() ?? '',
        rationale: j['rationale'] as String? ?? '',
      );
}

class GoalRiskItem {
  final String goalItemId;
  final String goalTitle;
  final String riskLevel; // 'high' | 'medium' | 'low'
  final String? recommendation;

  GoalRiskItem({
    required this.goalItemId,
    required this.goalTitle,
    required this.riskLevel,
    this.recommendation,
  });

  factory GoalRiskItem.fromJson(Map<String, dynamic> j) => GoalRiskItem(
        goalItemId: j['goal_item_id'] as String? ?? '',
        goalTitle: j['goal_title'] as String? ?? '',
        riskLevel: j['risk_level'] as String? ?? 'low',
        recommendation: j['recommendation'] as String?,
      );
}

// ── API Service ───────────────────────────────────────────────────────────────

class AiApiService {
  AiApiService(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  AuthService get _auth => _ref.read(authServiceProvider);
  Future<String?> _token() => _auth.getCurrentIdToken();

  Future<List<GoalSuggestion>> suggestGoals({
    required String role,
    required String department,
    required String thrustArea,
    required List<String> existingTitles,
  }) async {
    final token = await _token();
    final res = await _api.post(
      '/ai/suggest-goals',
      data: {
        'role': role,
        'department': department,
        'thrust_area': thrustArea,
        'existing_goal_titles': existingTitles,
      },
      options: ApiClient.bearerOptions(token!),
    );
    final data = res.data as Map<String, dynamic>;
    return ((data['suggestions'] as List?) ?? [])
        .map((j) => GoalSuggestion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<KpiRecommendation?> recommendKpi({
    required String thrustArea,
    required String goalTitle,
    required String role,
  }) async {
    try {
      final token = await _token();
      final res = await _api.post(
        '/ai/kpi-recommendations',
        data: {
          'thrust_area': thrustArea,
          'goal_title': goalTitle,
          'role': role,
        },
        options: ApiClient.bearerOptions(token!),
      );
      return KpiRecommendation.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<GoalRiskItem>> getRiskPrediction({
    required String goalId,
    required String quarter,
  }) async {
    final token = await _token();
    final res = await _api.post(
      '/ai/risk-prediction',
      data: {'goal_id': goalId, 'quarter': quarter},
      options: ApiClient.bearerOptions(token!),
    );
    final data = res.data as Map<String, dynamic>;
    return ((data['risks'] as List?) ?? [])
        .map((j) => GoalRiskItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<String> generateAiSummary(String checkinId) async {
    final token = await _token();
    final res = await _api.post(
      '/ai/checkins/$checkinId/ai-summary',
      data: {},
      options: ApiClient.bearerOptions(token!),
    );
    final data = res.data as Map<String, dynamic>;
    return data['summary'] as String? ?? '';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final aiApiProvider =
    Provider<AiApiService>((ref) => AiApiService(ref));
