enum UserRole {
  employee,
  hr,
  legal;

  String get displayName {
    switch (this) {
      case UserRole.employee:
        return 'Employee';
      case UserRole.hr:
        return 'HR';
      case UserRole.legal:
        return 'Legal';
    }
  }

  String get value {
    return name;
  }

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.name == role.toLowerCase(),
      orElse: () => UserRole.employee,
    );
  }
}
