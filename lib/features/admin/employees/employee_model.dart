class Employee {
  final String id;
  final String code;
  final String fullName;
  final bool active;
  final DateTime createdAt;

  Employee({
    required this.id,
    required this.code,
    required this.fullName,
    required this.active,
    required this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as String,
    code: json['code'] as String,
    fullName: json['full_name'] as String,
    active: json['active'] as bool? ?? true,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String).toLocal()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'code': code.trim(),
    'full_name': fullName.trim(),
    'active': active,
  };

  Employee copyWith({
    String? id,
    String? code,
    String? fullName,
    bool? active,
    DateTime? createdAt,
  }) {
    return Employee(
      id: id ?? this.id,
      code: code ?? this.code,
      fullName: fullName ?? this.fullName,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
