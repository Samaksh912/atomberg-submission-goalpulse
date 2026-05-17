/// Data models for quarterly check-in records.

class CheckinActual {
  CheckinActual({
    required this.goalItemId,
    required this.goalTitle,
    required this.uomType,
    this.target,
    required this.actualAchievement,
    required this.status,
    this.progressScore = 0,
    this.weightage = 0,
  });

  final String goalItemId;
  final String goalTitle;
  final String uomType;
  final dynamic target;
  final dynamic actualAchievement;
  final String status;
  final double progressScore;
  final double weightage;

  factory CheckinActual.fromJson(Map<String, dynamic> json) => CheckinActual(
        goalItemId: json['goalItemId'] as String? ?? '',
        goalTitle: json['goalTitle'] as String? ?? '',
        uomType: json['uomType'] as String? ?? '',
        target: json['target'],
        actualAchievement: json['actualAchievement'],
        status: json['status'] as String? ?? 'not_started',
        progressScore: (json['progressScore'] as num?)?.toDouble() ?? 0,
        weightage: (json['weightage'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'goalItemId': goalItemId,
        'goalTitle': goalTitle,
        'uomType': uomType,
        'target': target,
        'actualAchievement': actualAchievement,
        'status': status,
        'progressScore': progressScore,
        'weightage': weightage,
      };
}

class CheckinRecord {
  CheckinRecord({
    required this.id,
    required this.goalId,
    required this.employeeId,
    required this.quarter,
    required this.status,
    this.managerComment,
    this.aiSummary,
    required this.actuals,
    this.overallScore = 0,
    this.employeeSubmittedAt,
    this.managerReviewedAt,
  });

  final String id;
  final String goalId;
  final String employeeId;
  final String quarter;
  final String status;
  final String? managerComment;
  final String? aiSummary;
  final List<CheckinActual> actuals;
  final double overallScore;
  final String? employeeSubmittedAt;
  final String? managerReviewedAt;

  factory CheckinRecord.fromJson(Map<String, dynamic> json) => CheckinRecord(
        id: json['id'] as String? ?? '',
        goalId: json['goalId'] as String? ?? '',
        employeeId: json['employeeId'] as String? ?? '',
        quarter: json['quarter'] as String? ?? '',
        status: json['status'] as String? ?? '',
        managerComment: json['managerComment'] as String?,
        aiSummary: json['aiSummary'] as String?,
        actuals: (json['actuals'] as List<dynamic>?)
                ?.map((a) =>
                    CheckinActual.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
        employeeSubmittedAt: json['employeeSubmittedAt'] as String?,
        managerReviewedAt: json['managerReviewedAt'] as String?,
      );
}
