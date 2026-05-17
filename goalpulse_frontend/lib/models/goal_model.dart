/// Data models for Goal Items and Goal Sheets.
///
/// These mirror the API response schema and provide [fromJson] / [toJson]
/// helpers for serialisation.

class GoalItem {
  GoalItem({
    required this.goalItemId,
    required this.thrustArea,
    required this.title,
    this.description = '',
    required this.uomType,
    required this.target,
    required this.weightage,
    this.isShared = false,
    this.sharedGoalId,
    this.isLocked = false,
    this.quarterlyData = const {'Q1': null, 'Q2': null, 'Q3': null, 'Q4': null},
    this.aiSuggested = false,
  });

  final String goalItemId;
  final String thrustArea;
  final String title;
  final String description;
  final String uomType;
  final dynamic target; // double for numeric/%, String for timeline
  final double weightage;
  final bool isShared;
  final String? sharedGoalId;
  final bool isLocked;
  final Map<String, dynamic> quarterlyData;
  final bool aiSuggested;

  factory GoalItem.fromJson(Map<String, dynamic> json) => GoalItem(
        goalItemId: json['goalItemId'] as String? ?? '',
        thrustArea: json['thrustArea'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        uomType: json['uomType'] as String? ?? '',
        target: json['target'],
        weightage: (json['weightage'] as num?)?.toDouble() ?? 0,
        isShared: json['isShared'] as bool? ?? false,
        sharedGoalId: json['sharedGoalId'] as String?,
        isLocked: json['isLocked'] as bool? ?? false,
        quarterlyData: (json['quarterlyData'] as Map<String, dynamic>?) ??
            const {'Q1': null, 'Q2': null, 'Q3': null, 'Q4': null},
        aiSuggested: json['aiSuggested'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'goalItemId': goalItemId,
        'thrustArea': thrustArea,
        'title': title,
        'description': description,
        'uomType': uomType,
        'target': target,
        'weightage': weightage,
        'isShared': isShared,
        'sharedGoalId': sharedGoalId,
        'isLocked': isLocked,
        'quarterlyData': quarterlyData,
        'aiSuggested': aiSuggested,
      };

  GoalItem copyWith({
    String? goalItemId,
    String? thrustArea,
    String? title,
    String? description,
    String? uomType,
    dynamic target,
    double? weightage,
    bool? isShared,
    String? sharedGoalId,
    bool? isLocked,
    Map<String, dynamic>? quarterlyData,
    bool? aiSuggested,
  }) =>
      GoalItem(
        goalItemId: goalItemId ?? this.goalItemId,
        thrustArea: thrustArea ?? this.thrustArea,
        title: title ?? this.title,
        description: description ?? this.description,
        uomType: uomType ?? this.uomType,
        target: target ?? this.target,
        weightage: weightage ?? this.weightage,
        isShared: isShared ?? this.isShared,
        sharedGoalId: sharedGoalId ?? this.sharedGoalId,
        isLocked: isLocked ?? this.isLocked,
        quarterlyData: quarterlyData ?? this.quarterlyData,
        aiSuggested: aiSuggested ?? this.aiSuggested,
      );
}

class GoalSheet {
  GoalSheet({
    required this.id,
    required this.employeeId,
    this.managerId,
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
  final String? managerId;
  final String cycleId;
  final String sheetStatus;
  final List<GoalItem> goals;
  final double totalWeightage;
  final String? submittedAt;
  final String? approvedAt;
  final String? managerComment;
  final String createdAt;

  factory GoalSheet.fromJson(Map<String, dynamic> json) => GoalSheet(
        id: json['id'] as String? ?? '',
        employeeId: json['employeeId'] as String? ?? '',
        managerId: json['managerId'] as String?,
        cycleId: json['cycleId'] as String? ?? '',
        sheetStatus: json['sheetStatus'] as String? ?? 'draft',
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

  GoalSheet copyWith({
    String? id,
    String? employeeId,
    String? managerId,
    String? cycleId,
    String? sheetStatus,
    List<GoalItem>? goals,
    double? totalWeightage,
    String? submittedAt,
    String? approvedAt,
    String? managerComment,
    String? createdAt,
  }) =>
      GoalSheet(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        managerId: managerId ?? this.managerId,
        cycleId: cycleId ?? this.cycleId,
        sheetStatus: sheetStatus ?? this.sheetStatus,
        goals: goals ?? this.goals,
        totalWeightage: totalWeightage ?? this.totalWeightage,
        submittedAt: submittedAt ?? this.submittedAt,
        approvedAt: approvedAt ?? this.approvedAt,
        managerComment: managerComment ?? this.managerComment,
        createdAt: createdAt ?? this.createdAt,
      );
}
