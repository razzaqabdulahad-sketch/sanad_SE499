import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractType {
  nda,
  serviceAgreement,
  employmentAgreement,
  vendorAgreement,
  other;

  String get displayName {
    switch (this) {
      case ContractType.nda:
        return 'NDA';
      case ContractType.serviceAgreement:
        return 'Service Agreement';
      case ContractType.employmentAgreement:
        return 'Employment Agreement';
      case ContractType.vendorAgreement:
        return 'Vendor Agreement';
      case ContractType.other:
        return 'Other';
    }
  }

  String get value => name;

  static ContractType fromString(String raw) {
    return ContractType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => ContractType.other,
    );
  }
}

enum ContractStatus {
  draft,
  inReview,
  active,
  closed;

  String get displayName {
    switch (this) {
      case ContractStatus.draft:
        return 'Draft';
      case ContractStatus.inReview:
        return 'In Review';
      case ContractStatus.active:
        return 'Active';
      case ContractStatus.closed:
        return 'Closed';
    }
  }

  String get value => name;

  static ContractStatus fromString(String raw) {
    return ContractStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => ContractStatus.draft,
    );
  }
}

class LegalContract {
  final String id;
  final String title;
  final String counterparty;
  final ContractType type;
  final ContractStatus status;
  final String? description;
  final double? contractValue;
  final DateTime effectiveDate;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LegalContract({
    required this.id,
    required this.title,
    required this.counterparty,
    required this.type,
    required this.status,
    this.description,
    this.contractValue,
    required this.effectiveDate,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LegalContract.fromMap(String id, Map<String, dynamic> map) {
    final rawValue = map['contractValue'];
    final parsedValue = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse((rawValue ?? '').toString());

    return LegalContract(
      id: id,
      title: (map['title'] ?? '').toString(),
      counterparty: (map['counterparty'] ?? '').toString(),
      type: ContractType.fromString((map['type'] ?? 'other').toString()),
      status: ContractStatus.fromString((map['status'] ?? 'draft').toString()),
      description: map['description']?.toString(),
      contractValue: parsedValue,
      effectiveDate:
          (map['effectiveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUserId: (map['createdByUserId'] ?? '').toString(),
      createdByName: (map['createdByName'] ?? 'Legal User').toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'counterparty': counterparty,
      'type': type.value,
      'status': status.value,
      'description': description,
      'contractValue': contractValue,
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}