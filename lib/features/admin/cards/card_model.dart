class CardModel {
  final String uid;
  final String employeeId;
  final bool active;
  final DateTime createdAt;

  CardModel({
    required this.uid,
    required this.employeeId,
    required this.active,
    required this.createdAt,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) => CardModel(
    uid: json['uid'] as String,
    employeeId: json['employee_id'] as String,
    active: json['active'] as bool? ?? true,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String).toLocal()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'uid': uid.toUpperCase(),
    'employee_id': employeeId,
    'active': active,
  };

  CardModel copyWith({
    String? uid,
    String? employeeId,
    bool? active,
    DateTime? createdAt,
  }) {
    return CardModel(
      uid: uid ?? this.uid,
      employeeId: employeeId ?? this.employeeId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
