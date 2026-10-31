class Employee {
  final String id;
  final String code;
  final String fullName;
  final bool active;
  final DateTime createdAt;
  final double hourlyRate;
  final String? email;
  final String? department;
  final String? jobTitle;
  final String? phone;
  final DateTime? hireDate;

  Employee({
    required this.id,
    required this.code,
    required this.fullName,
    required this.active,
    required this.createdAt,
    this.hourlyRate = 0,
    this.email,
    this.department,
    this.jobTitle,
    this.phone,
    this.hireDate,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as String,
    code: json['code'] as String,
    fullName: json['full_name'] as String,
    active: json['active'] as bool? ?? true,
    hourlyRate: num.parse('${json['hourly_rate'] ?? 0}').toDouble(),
    email: json['email'] as String?,
    department: json['department'] as String?,
    jobTitle: json['job_title'] as String?,
    phone: json['phone'] as String?,
    hireDate: DateTime.tryParse('${json['hire_date']}'),
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String).toLocal()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'code': code.trim(),
    'full_name': fullName.trim(),
    'active': active,
    'hourly_rate': hourlyRate,
  };

  Employee copyWith({
    String? id,
    String? code,
    String? fullName,
    bool? active,
    DateTime? createdAt,
    double? hourlyRate,
  }) {
    return Employee(
      id: id ?? this.id,
      code: code ?? this.code,
      fullName: fullName ?? this.fullName,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      email: email,
      department: department,
      jobTitle: jobTitle,
      phone: phone,
      hireDate: hireDate,
    );
  }
}
