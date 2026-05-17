/// Data model for shared / cascaded KPI goals.

class SharedGoal {
  SharedGoal({
    required this.id,
    required this.createdBy,
    required this.cycleId,
    required this.thrustArea,
    required this.title,
    this.description = '',
    required this.uomType,
    required this.target,
    this.suggestedWeightage = 20,
    required this.recipientIds,
    required this.ownerEmployeeId,
    required this.linkedGoalItemIds,
    this.createdAt,
  });

  final String id;
  final String createdBy;
  final String cycleId;
  final String thrustArea;
  final String title;
  final String description;
  final String uomType;
  final dynamic target;
  final double suggestedWeightage;
  final List<String> recipientIds;
  final String ownerEmployeeId;
  final Map<String, dynamic> linkedGoalItemIds; // {employeeId: goalItemId}
  final String? createdAt;

  int get recipientCount => recipientIds.length;

  factory SharedGoal.fromJson(Map<String, dynamic> json) => SharedGoal(
        id: json['id'] as String? ?? '',
        createdBy: json['createdBy'] as String? ?? '',
        cycleId: json['cycleId'] as String? ?? '',
        thrustArea: json['thrustArea'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        uomType: json['uomType'] as String? ?? '',
        target: json['target'],
        suggestedWeightage:
            (json['suggestedWeightage'] as num?)?.toDouble() ?? 20,
        recipientIds: (json['recipientIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        ownerEmployeeId: json['ownerEmployeeId'] as String? ?? '',
        linkedGoalItemIds: (json['linkedGoalItemIds'] as Map<String, dynamic>?) ?? {},
        createdAt: json['createdAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdBy': createdBy,
        'cycleId': cycleId,
        'thrustArea': thrustArea,
        'title': title,
        'description': description,
        'uomType': uomType,
        'target': target,
        'suggestedWeightage': suggestedWeightage,
        'recipientIds': recipientIds,
        'ownerEmployeeId': ownerEmployeeId,
        'linkedGoalItemIds': linkedGoalItemIds,
        'createdAt': createdAt,
      };
}
