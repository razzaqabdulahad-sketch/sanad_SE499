import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintStatus {
  submitted,
  underReview,
  inProgress,
  resolved,
  dismissed;

  String get displayName {
    switch (this) {
      case ComplaintStatus.submitted:
        return 'Submitted';
      case ComplaintStatus.underReview:
        return 'Under Review';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.dismissed:
        return 'Dismissed';
    }
  }

  String get value => name;

  static ComplaintStatus fromString(String status) {
    return ComplaintStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ComplaintStatus.submitted,
    );
  }
}

enum ComplaintPriority {
  none,
  p0,
  p1,
  p2;

  String get displayName {
    switch (this) {
      case ComplaintPriority.none:
        return 'Not Set';
      case ComplaintPriority.p0:
        return 'P0 — Low';
      case ComplaintPriority.p1:
        return 'P1 — Medium';
      case ComplaintPriority.p2:
        return 'P2 — Critical';
    }
  }

  String get shortLabel {
    switch (this) {
      case ComplaintPriority.none:
        return '—';
      case ComplaintPriority.p0:
        return 'P0';
      case ComplaintPriority.p1:
        return 'P1';
      case ComplaintPriority.p2:
        return 'P2';
    }
  }

  String get value => name;

  static ComplaintPriority fromString(String priority) {
    return ComplaintPriority.values.firstWhere(
      (e) => e.name == priority,
      orElse: () => ComplaintPriority.none,
    );
  }
}

enum ComplaintDepartment {
  hr,
  legal;

  String get displayName {
    switch (this) {
      case ComplaintDepartment.hr:
        return 'Human Resources';
      case ComplaintDepartment.legal:
        return 'Legal';
    }
  }

  String get value => name;

  static ComplaintDepartment fromString(String dept) {
    return ComplaintDepartment.values.firstWhere(
      (e) => e.name == dept,
      orElse: () => ComplaintDepartment.hr,
    );
  }
}

/// Represents a single status change in the complaint lifecycle.
class StatusUpdate {
  final ComplaintStatus status;
  final String? note;
  final String? updatedBy;
  final DateTime timestamp;

  StatusUpdate({
    required this.status,
    this.note,
    this.updatedBy,
    required this.timestamp,
  });

  factory StatusUpdate.fromMap(Map<String, dynamic> map) {
    return StatusUpdate(
      status: ComplaintStatus.fromString(map['status'] ?? 'submitted'),
      note: map['note'],
      updatedBy: map['updatedBy'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.value,
      'note': note,
      'updatedBy': updatedBy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class Complaint {
  final String id;
  final String userId;
  final String? employeeName;
  final bool isAnonymous;
  final String subject;
  final String description;
  final ComplaintDepartment department;
  final ComplaintStatus status;
  final List<String> attachmentUrls;
  final List<String> attachmentNames;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolvedBy;
  final String? resolutionNote;
  final String? assignedToUserId;
  final String? assignedToName;
  final DateTime? assignedAt;
  final String? caseOutcome;
  final String? caseOutcomeDetails;
  final DateTime? closedAt;
  final List<StatusUpdate> statusHistory;
  final String? aiCategory;
  final String? aiSummary;
  final String? aiRecommendedDepartment;
  final String? aiUrgency;
  final String? aiUrgencyReason;
  final ComplaintPriority priority;
  final String? prioritySetBy;
  final DateTime? prioritySetAt;

  Complaint({
    required this.id,
    required this.userId,
    this.employeeName,
    required this.isAnonymous,
    required this.subject,
    required this.description,
    required this.department,
    required this.status,
    required this.attachmentUrls,
    required this.attachmentNames,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.assignedToUserId,
    this.assignedToName,
    this.assignedAt,
    this.caseOutcome,
    this.caseOutcomeDetails,
    this.closedAt,
    this.statusHistory = const [],
    this.aiCategory,
    this.aiSummary,
    this.aiRecommendedDepartment,
    this.aiUrgency,
    this.aiUrgencyReason,
    this.priority = ComplaintPriority.none,
    this.prioritySetBy,
    this.prioritySetAt,
  });

  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Complaint(
      id: doc.id,
      userId: data['userId'] ?? '',
      employeeName: data['employeeName'],
      isAnonymous: data['isAnonymous'] ?? false,
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      department: ComplaintDepartment.fromString(data['department'] ?? 'hr'),
      status: ComplaintStatus.fromString(data['status'] ?? 'submitted'),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      attachmentNames: List<String>.from(data['attachmentNames'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedBy: data['resolvedBy'],
      resolutionNote: data['resolutionNote'],
      assignedToUserId: data['assignedToUserId'],
      assignedToName: data['assignedToName'],
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      caseOutcome: data['caseOutcome'],
      caseOutcomeDetails: data['caseOutcomeDetails'],
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      statusHistory:
          (data['statusHistory'] as List<dynamic>?)
              ?.map((e) => StatusUpdate.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      aiCategory: data['aiCategory'],
      aiSummary: data['aiSummary'],
      aiRecommendedDepartment: data['aiRecommendedDepartment'],
      aiUrgency: data['aiUrgency'],
      aiUrgencyReason: data['aiUrgencyReason'],
      priority: ComplaintPriority.fromString(data['priority'] ?? 'none'),
      prioritySetBy: data['prioritySetBy'],
      prioritySetAt: (data['prioritySetAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeName': isAnonymous ? null : employeeName,
      'isAnonymous': isAnonymous,
      'subject': subject,
      'description': description,
      'department': department.value,
      'status': status.value,
      'attachmentUrls': attachmentUrls,
      'attachmentNames': attachmentNames,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedBy': resolvedBy,
      'resolutionNote': resolutionNote,
      'assignedToUserId': assignedToUserId,
      'assignedToName': assignedToName,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'caseOutcome': caseOutcome,
      'caseOutcomeDetails': caseOutcomeDetails,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'aiCategory': aiCategory,
      'aiSummary': aiSummary,
      'aiRecommendedDepartment': aiRecommendedDepartment,
      'aiUrgency': aiUrgency,
      'aiUrgencyReason': aiUrgencyReason,
      'priority': priority.value,
      'prioritySetBy': prioritySetBy,
      'prioritySetAt': prioritySetAt != null
          ? Timestamp.fromDate(prioritySetAt!)
          : null,
    };
  }
}
