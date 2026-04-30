import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveType {
  casual,
  medical,
  annual;

  String get displayName {
    switch (this) {
      case LeaveType.casual:
        return 'Casual Leave';
      case LeaveType.medical:
        return 'Medical Leave';
      case LeaveType.annual:
        return 'Annual Leave';
    }
  }

  String get value {
    return name;
  }

  static LeaveType fromString(String type) {
    return LeaveType.values.firstWhere(
      (e) => e.name == type.toLowerCase(),
      orElse: () => LeaveType.casual,
    );
  }
}

enum LeaveStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }

  String get value {
    return name;
  }

  static LeaveStatus fromString(String status) {
    return LeaveStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => LeaveStatus.pending,
    );
  }
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewComment;
  final bool isOverridden;
  final String? overrideReason;
  final String? overriddenBy;
  final DateTime? overriddenAt;
  final String? previousStatus;
  final String? attachmentUrl;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComment,
    this.isOverridden = false,
    this.overrideReason,
    this.overriddenBy,
    this.overriddenAt,
    this.previousStatus,
    this.attachmentUrl,
  });

  int get totalDays {
    return endDate.difference(startDate).inDays + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeEmail': employeeEmail,
      'leaveType': leaveType.value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewComment': reviewComment,
      'isOverridden': isOverridden,
      'overrideReason': overrideReason,
      'overriddenBy': overriddenBy,
      'overriddenAt': overriddenAt != null ? Timestamp.fromDate(overriddenAt!) : null,
      'previousStatus': previousStatus,
      'attachmentUrl': attachmentUrl,
    };
  }

  factory LeaveRequest.fromMap(String id, Map<String, dynamic> map) {
    return LeaveRequest(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      employeeEmail: map['employeeEmail'] ?? '',
      leaveType: LeaveType.fromString(map['leaveType'] ?? 'casual'),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
      status: LeaveStatus.fromString(map['status'] ?? 'pending'),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      reviewedBy: map['reviewedBy'],
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewComment: map['reviewComment'],
      isOverridden: map['isOverridden'] ?? false,
      overrideReason: map['overrideReason'],
      overriddenBy: map['overriddenBy'],
      overriddenAt: map['overriddenAt'] != null
          ? (map['overriddenAt'] as Timestamp).toDate()
          : null,
      previousStatus: map['previousStatus'],
      attachmentUrl: map['attachmentUrl'],
    );
  }

  LeaveRequest copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeeEmail,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    LeaveStatus? status,
    DateTime? createdAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewComment,
    bool? isOverridden,
    String? overrideReason,
    String? overriddenBy,
    DateTime? overriddenAt,
    String? previousStatus,
    String? attachmentUrl,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewComment: reviewComment ?? this.reviewComment,
      isOverridden: isOverridden ?? this.isOverridden,
      overrideReason: overrideReason ?? this.overrideReason,
      overriddenBy: overriddenBy ?? this.overriddenBy,
      overriddenAt: overriddenAt ?? this.overriddenAt,
      previousStatus: previousStatus ?? this.previousStatus,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }
}

class LeaveBalance {
  final String employeeId;
  final int casualLeaves;
  final int medicalLeaves;
  final int annualLeaves;
  final int casualUsed;
  final int medicalUsed;
  final int annualUsed;

  LeaveBalance({
    required this.employeeId,
    required this.casualLeaves,
    required this.medicalLeaves,
    required this.annualLeaves,
    this.casualUsed = 0,
    this.medicalUsed = 0,
    this.annualUsed = 0,
  });

  int get casualRemaining => casualLeaves - casualUsed;
  int get medicalRemaining => medicalLeaves - medicalUsed;
  int get annualRemaining => annualLeaves - annualUsed;

  int get totalLeaves => casualLeaves + medicalLeaves + annualLeaves;
  int get totalUsed => casualUsed + medicalUsed + annualUsed;
  int get totalRemaining => totalLeaves - totalUsed;

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'casualLeaves': casualLeaves,
      'medicalLeaves': medicalLeaves,
      'annualLeaves': annualLeaves,
      'casualUsed': casualUsed,
      'medicalUsed': medicalUsed,
      'annualUsed': annualUsed,
    };
  }

  factory LeaveBalance.fromMap(Map<String, dynamic> map) {
    return LeaveBalance(
      employeeId: map['employeeId'] ?? '',
      casualLeaves: map['casualLeaves'] ?? 10,
      medicalLeaves: map['medicalLeaves'] ?? 10,
      annualLeaves: map['annualLeaves'] ?? 10,
      casualUsed: map['casualUsed'] ?? 0,
      medicalUsed: map['medicalUsed'] ?? 0,
      annualUsed: map['annualUsed'] ?? 0,
    );
  }

  LeaveBalance copyWith({
    String? employeeId,
    int? casualLeaves,
    int? medicalLeaves,
    int? annualLeaves,
    int? casualUsed,
    int? medicalUsed,
    int? annualUsed,
  }) {
    return LeaveBalance(
      employeeId: employeeId ?? this.employeeId,
      casualLeaves: casualLeaves ?? this.casualLeaves,
      medicalLeaves: medicalLeaves ?? this.medicalLeaves,
      annualLeaves: annualLeaves ?? this.annualLeaves,
      casualUsed: casualUsed ?? this.casualUsed,
      medicalUsed: medicalUsed ?? this.medicalUsed,
      annualUsed: annualUsed ?? this.annualUsed,
    );
  }
}
