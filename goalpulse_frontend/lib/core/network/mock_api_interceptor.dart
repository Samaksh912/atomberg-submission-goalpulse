import 'package:dio/dio.dart';
import 'dart:convert';

/// A Dio interceptor that catches all network requests and returns hardcoded mock data
/// so the frontend can function perfectly without the backend running.
class MockApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Add a slight delay to simulate network latency and show loading states
    await Future.delayed(const Duration(milliseconds: 800));

    final path = options.path;
    final method = options.method.toUpperCase();

    try {
      if (method == 'GET') {
        if (path.contains('/goals/my')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockMyGoals(),
          ));
          return;
        } else if (path.contains('/goals/team?status=submitted')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockPendingApprovals(),
          ));
          return;
        } else if (path.contains('/goals/team')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockTeamGoals(),
          ));
          return;
        } else if (path.contains('/analytics/completion-dashboard')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockCompletionDashboard(),
          ));
          return;
        } else if (path.contains('/analytics/qoq-trends')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockQoqTrends(),
          ));
          return;
        } else if (path.contains('/admin/users')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockUsers(),
          ));
          return;
        } else if (path.contains('/admin/audit-logs')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockAuditLogs(),
          ));
          return;
        } else if (path.contains('/checkins/')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockCheckins(),
          ));
          return;
        }
      } else if (method == 'POST') {
        if (path.contains('/ai/suggest-goals')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: _mockAiSuggestions(),
          ));
          return;
        } else if (path.contains('/ai/kpi-recommendations')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {"uomType": "numeric_max", "target": 50, "rationale": "AI recommends keeping this metric low."}
          ));
          return;
        }
      }

      // Default fallback for any unmocked POST/PUT/DELETE to simulate success
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {"message": "Success (Mocked)"},
      ));
    } catch (e) {
      handler.reject(DioException(
        requestOptions: options,
        error: "Mock Error: $e",
      ));
    }
  }

  // ── MOCK DATA ────────────────────────────────────────────────────────────

  Map<String, dynamic> _mockMyGoals() {
    return {
      "id": "mock_goal_sheet_1",
      "employeeId": "emp1",
      "managerId": "manager1",
      "cycleId": "cycle_2025",
      "sheetStatus": "locked",
      "totalWeightage": 100.0,
      "managerComment": "Great goals, approved.",
      "createdAt": DateTime.now().toIso8601String(),
      "goals": [
        {
          "goalItemId": "g1",
          "thrustArea": "Revenue",
          "title": "Increase Q1 Sales",
          "description": "Drive enterprise sales.",
          "uomType": "numeric_min",
          "target": 1000000,
          "weightage": 50.0,
          "isShared": false,
          "isLocked": true,
          "quarterlyData": {"Q1": null, "Q2": null, "Q3": null, "Q4": null}
        },
        {
          "goalItemId": "g2",
          "thrustArea": "Customer Success",
          "title": "Reduce Churn",
          "description": "Keep churn under 2%.",
          "uomType": "percent_max",
          "target": 2,
          "weightage": 50.0,
          "isShared": false,
          "isLocked": true,
          "quarterlyData": {"Q1": null, "Q2": null, "Q3": null, "Q4": null}
        }
      ]
    };
  }

  List<dynamic> _mockPendingApprovals() {
    return [
      {
        "id": "mock_pending_1",
        "employeeId": "emp2",
        "employeeName": "Karthik Nair",
        "employeeEmail": "emp2@demo.com",
        "employeeDepartment": "Sales",
        "cycleId": "cycle_2025",
        "sheetStatus": "submitted",
        "totalWeightage": 100.0,
        "createdAt": DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        "goals": [
          {
            "goalItemId": "g3",
            "thrustArea": "Operations",
            "title": "Optimize Supply Chain",
            "description": "Reduce delivery time.",
            "uomType": "numeric_max",
            "target": 48,
            "weightage": 100.0,
            "isShared": false,
            "isLocked": false,
            "quarterlyData": {"Q1": null, "Q2": null, "Q3": null, "Q4": null}
          }
        ]
      }
    ];
  }

  List<dynamic> _mockTeamGoals() {
    final list = _mockPendingApprovals();
    list.add({
      "id": "mock_goal_sheet_1",
      "employeeId": "emp1",
      "employeeName": "Ananya Iyer",
      "employeeEmail": "emp1@demo.com",
      "employeeDepartment": "Engineering",
      "cycleId": "cycle_2025",
      "sheetStatus": "locked",
      "totalWeightage": 100.0,
      "createdAt": DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      "goals": _mockMyGoals()["goals"],
    });
    return list;
  }

  List<dynamic> _mockCheckins() {
    return [
      {
        "id": "mock_checkin_1",
        "goalId": "mock_goal_sheet_1",
        "employeeId": "emp1",
        "quarter": "Q1",
        "status": "approved",
        "managerComment": "Excellent progress this quarter.",
        "aiSummary": "Ananya achieved strong results across revenue and retention metrics.",
        "employeeSubmittedAt": DateTime.now().toIso8601String(),
        "actuals": [
          {"goalItemId": "g1", "actual": 1200000, "status": "on_track", "progressScore": 100.0},
          {"goalItemId": "g2", "actual": 1.5, "status": "on_track", "progressScore": 100.0}
        ]
      }
    ];
  }

  Map<String, dynamic> _mockCompletionDashboard() {
    return {
      "employees": ["Ananya Iyer", "Karthik Nair", "Deepa Raj"],
      "quarters": ["Q1", "Q2", "Q3", "Q4"],
      "completionRates": [
        [1.0, 0.5, 0.0, 0.0],
        [0.8, 0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0, 0.0]
      ]
    };
  }

  Map<String, dynamic> _mockQoqTrends() {
    return {
      "labels": ["Q1", "Q2", "Q3", "Q4"],
      "datasets": [
        {"label": "Avg Progress Score", "data": [85.0, 92.0, 0.0, 0.0]}
      ]
    };
  }

  List<dynamic> _mockUsers() {
    return [
      {"uid": "admin1", "displayName": "Priya Sharma", "email": "admin@demo.com", "role": "admin", "department": "HR", "designation": "HR Manager", "isActive": true},
      {"uid": "manager1", "displayName": "Rahul Mehta", "email": "manager@demo.com", "role": "manager", "department": "Sales", "designation": "Sales Manager", "isActive": true},
      {"uid": "emp1", "displayName": "Ananya Iyer", "email": "emp1@demo.com", "role": "employee", "department": "Engineering", "designation": "Software Engineer", "isActive": true},
      {"uid": "emp2", "displayName": "Karthik Nair", "email": "emp2@demo.com", "role": "employee", "department": "Sales", "designation": "Sales Executive", "isActive": true},
    ];
  }

  Map<String, dynamic> _mockAuditLogs() {
    return {
      "logs": [
        {
          "id": "log1",
          "actorId": "admin1",
          "actorRole": "admin",
          "targetType": "goal",
          "employeeId": "emp1",
          "action": "unlock",
          "fieldChanged": "isLocked",
          "oldValue": "true",
          "newValue": "false",
          "reason": "Target adjustment request",
          "timestamp": DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()
        }
      ],
      "nextPageToken": null
    };
  }

  Map<String, dynamic> _mockAiSuggestions() {
    return {
      "suggestions": [
        {
          "title": "Boost organic traffic by 20%",
          "description": "Implement advanced SEO strategies across top 50 blog posts.",
          "uomType": "percent_min",
          "target": 20,
          "rationale": "Aligns with marketing growth targets."
        },
        {
          "title": "Reduce page load time",
          "description": "Optimize images and lazy load components to drop load time below 1.5s.",
          "uomType": "numeric_max",
          "target": 1.5,
          "rationale": "Crucial for user retention."
        }
      ]
    };
  }
}
