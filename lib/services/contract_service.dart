import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification.dart';
import '../models/contract.dart';
import '../models/user_role.dart';
import 'notification_service.dart';

class ContractService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  String? get _currentUserId => _auth.currentUser?.uid;
  String? get _currentUserName =>
      _auth.currentUser?.displayName ?? _auth.currentUser?.email;

  Stream<List<LegalContract>> getContractsStream() {
    return _firestore
        .collection('contracts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => LegalContract.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Stream<LegalContract?> getContractStream(String contractId) {
    return _firestore
        .collection('contracts')
        .doc(contractId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          if (data == null) return null;
          return LegalContract.fromMap(doc.id, data);
        });
  }

  Future<String> createContract({
    required String title,
    required String counterparty,
    required ContractType type,
    required DateTime effectiveDate,
    String? description,
    double? contractValue,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final contract = LegalContract(
      id: '',
      title: title.trim(),
      counterparty: counterparty.trim(),
      type: type,
      status: ContractStatus.draft,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      contractValue: contractValue,
      effectiveDate: effectiveDate,
      createdByUserId: _currentUserId!,
      createdByName: _currentUserName ?? 'Legal User',
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _firestore.collection('contracts').add(contract.toMap());

    await _notificationService.notifyUsersByRole(
      role: UserRole.legal,
      title: 'New Contract Created',
      message: '${contract.title} has been created for ${contract.counterparty}.',
      topic: NotificationTopic.contract,
      entityId: docRef.id,
      entityType: 'contract',
      metadata: {
        'status': ContractStatus.draft.value,
      },
    );

    return docRef.id;
  }

  Future<void> updateContractStatus({
    required String contractId,
    required ContractStatus status,
  }) async {
    final contractDoc = await _firestore.collection('contracts').doc(contractId).get();
    if (!contractDoc.exists) {
      throw Exception('Contract not found');
    }

    final contract = LegalContract.fromMap(contractDoc.id, contractDoc.data()!);

    await _firestore.collection('contracts').doc(contractId).update({
      'status': status.value,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    await _notificationService.notifyUser(
      userId: contract.createdByUserId,
      title: 'Contract Status Updated',
      message: '${contract.title} is now ${status.displayName}.',
      topic: NotificationTopic.contract,
      entityId: contractId,
      entityType: 'contract',
      metadata: {
        'status': status.value,
      },
    );

    await _notificationService.notifyUsersByRole(
      role: UserRole.legal,
      title: 'Contract Status Changed',
      message: '${contract.title} status changed to ${status.displayName}.',
      topic: NotificationTopic.contract,
      entityId: contractId,
      entityType: 'contract',
      metadata: {
        'status': status.value,
      },
      excludeUserId: contract.createdByUserId,
    );
  }
}