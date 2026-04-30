import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification.dart';
import '../models/complaint.dart';
import '../models/user_role.dart';
import 'gemini_service.dart';
import 'notification_service.dart';

class ComplaintService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  String? get _currentUserId => _auth.currentUser?.uid;
  String? get _currentUserName => _auth.currentUser?.displayName;
  String? get _currentUserEmail => _auth.currentUser?.email;
  String? get _currentActorName =>
      _currentUserName ?? _currentUserEmail ?? _currentUserId;

  String? get currentUserId => _currentUserId;
  String? get currentActorName => _currentActorName;

  UserRole _roleForDepartment(ComplaintDepartment department) {
    return department == ComplaintDepartment.hr ? UserRole.hr : UserRole.legal;
  }

  String _safeComplaintSubject(String subject) {
    final trimmed = subject.trim();
    if (trimmed.isEmpty) return 'Complaint';
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 77)}...';
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  Future<String> _encodeAttachmentAsDataUri({
    required File file,
    required String originalFileName,
  }) async {
    if (!await file.exists()) {
      throw Exception(
        'Selected file no longer exists. Please attach it again.',
      );
    }

    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    return 'data:${_guessContentType(originalFileName)};base64,$base64Data';
  }

  /// Submit a new complaint with optional file attachments.
  /// The department is auto-detected by Gemini based on complaint content.
  /// Returns a record with the complaint ID and detected department.
  Future<({String id, ComplaintDepartment department})> submitComplaint({
    required String subject,
    required String description,
    required bool isAnonymous,
    List<File> attachments = const [],
    List<String> attachmentFileNames = const [],
  }) async {
    if (_currentUserId == null) throw 'User not authenticated';

    // Auto-classify department using Gemini
    final department = await GeminiService.classifyComplaint(
      subject: subject,
      description: description,
    );

    // Store attachments directly in Firestore as base64 data URIs.
    final List<String> attachmentUrls = [];
    final List<String> attachmentNames = [];

    for (int i = 0; i < attachments.length; i++) {
      final file = attachments[i];
      final fileName = attachmentFileNames.length > i
          ? attachmentFileNames[i]
          : 'attachment_${DateTime.now().millisecondsSinceEpoch}_$i';

      final dataUri = await _encodeAttachmentAsDataUri(
        file: file,
        originalFileName: fileName,
      );

      attachmentUrls.add(dataUri);
      attachmentNames.add(fileName);
    }

    final now = DateTime.now();
    final complaint = Complaint(
      id: '',
      userId: _currentUserId!,
      employeeName: isAnonymous ? null : _currentUserName,
      isAnonymous: isAnonymous,
      subject: subject,
      description: description,
      department: department,
      status: ComplaintStatus.submitted,
      attachmentUrls: attachmentUrls,
      attachmentNames: attachmentNames,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _firestore
        .collection('complaints')
        .add(complaint.toFirestore());

    final safeSubject = _safeComplaintSubject(subject);
    await _notificationService.notifyUser(
      userId: _currentUserId!,
      title: 'Complaint Submitted',
      message:
          'Your complaint "$safeSubject" was submitted to ${department.displayName}.',
      topic: NotificationTopic.complaint,
      entityId: docRef.id,
      entityType: 'complaint',
    );

    await _notificationService.notifyUsersByRole(
      role: _roleForDepartment(department),
      title: 'New Complaint Received',
      message:
          'A new complaint "$safeSubject" was routed to ${department.displayName}.',
      topic: NotificationTopic.complaint,
      entityId: docRef.id,
      entityType: 'complaint',
    );

    return (id: docRef.id, department: department);
  }

  /// Get real-time stream of complaints for the current user
  Stream<List<Complaint>> getMyComplaintsStream() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList(),
        );
  }

  /// Get real-time stream of a single complaint
  Stream<Complaint?> getComplaintStream(String complaintId) {
    return _firestore.collection('complaints').doc(complaintId).snapshots().map(
      (doc) {
        if (doc.exists) {
          return Complaint.fromFirestore(doc);
        }
        return null;
      },
    );
  }

  /// Get complaints directed to a specific department (for HR/Legal dashboards)
  Stream<List<Complaint>> getComplaintsByDepartment(
    ComplaintDepartment department,
  ) {
    return _firestore
        .collection('complaints')
        .where('department', isEqualTo: department.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList(),
        );
  }

  /// Get complaints currently assigned to the authenticated user.
  /// This is primarily used by legal users to review their own case queue.
  Stream<List<Complaint>> getComplaintsAssignedToCurrentUser({
    ComplaintDepartment? department,
  }) {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('complaints')
        .where('assignedToUserId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs
              .map((doc) => Complaint.fromFirestore(doc))
              .where(
                (complaint) =>
                    department == null || complaint.department == department,
              )
              .toList();

          complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return complaints;
        });
  }

  /// Update complaint status (for HR/Legal use).
  /// Appends a [StatusUpdate] entry to the complaint's status history
  /// so every change is fully documented with who, when, and why.
  Future<void> updateComplaintStatus({
    required String complaintId,
    required ComplaintStatus newStatus,
    String? resolutionNote,
    String? caseOutcome,
    String? caseOutcomeDetails,
  }) async {
    final docRef = _firestore.collection('complaints').doc(complaintId);
    final complaintDoc = await docRef.get();
    if (!complaintDoc.exists) throw Exception('Complaint not found');

    final complaintData = complaintDoc.data()!;
    final complaintOwnerId = (complaintData['userId'] ?? '').toString();
    final complaintSubject = _safeComplaintSubject(
      (complaintData['subject'] ?? '').toString(),
    );

    final isClosingStatus =
        newStatus == ComplaintStatus.resolved ||
        newStatus == ComplaintStatus.dismissed;
    final normalizedOutcome = caseOutcome?.trim();
    final normalizedOutcomeDetails = caseOutcomeDetails?.trim();

    if (isClosingStatus &&
        (normalizedOutcome == null || normalizedOutcome.isEmpty)) {
      throw Exception('A case outcome is required to close this complaint.');
    }

    final now = DateTime.now();
    final actor = _currentActorName;
    final String? historyNote = isClosingStatus
        ? [
            if (normalizedOutcome != null && normalizedOutcome.isNotEmpty)
              'Outcome: $normalizedOutcome',
            if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
              resolutionNote.trim(),
          ].join(' • ')
        : resolutionNote;

    final historyEntry = StatusUpdate(
      status: newStatus,
      note: (historyNote != null && historyNote.isNotEmpty)
          ? historyNote
          : null,
      updatedBy: actor,
      timestamp: now,
    );

    final updateData = <String, dynamic>{
      'status': newStatus.value,
      'updatedAt': Timestamp.fromDate(now),
      'statusHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    };

    if (resolutionNote != null) {
      updateData['resolutionNote'] = resolutionNote;
      updateData['resolvedBy'] = actor;
    }

    if (isClosingStatus) {
      updateData['caseOutcome'] = normalizedOutcome;
      updateData['caseOutcomeDetails'] =
          (normalizedOutcomeDetails != null &&
              normalizedOutcomeDetails.isNotEmpty)
          ? normalizedOutcomeDetails
          : null;
      updateData['closedAt'] = Timestamp.fromDate(now);
      updateData['resolvedBy'] = actor;
    }

    await docRef.update(updateData);

    if (complaintOwnerId.isNotEmpty) {
      final message = isClosingStatus
          ? 'Your complaint "$complaintSubject" was marked ${newStatus.displayName.toLowerCase()}${normalizedOutcome != null && normalizedOutcome.isNotEmpty ? ' with outcome: $normalizedOutcome' : ''}.'
          : 'Your complaint "$complaintSubject" status is now ${newStatus.displayName}.';

      await _notificationService.notifyUser(
        userId: complaintOwnerId,
        title: 'Complaint Updated',
        message: message,
        topic: NotificationTopic.complaint,
        entityId: complaintId,
        entityType: 'complaint',
      );
    }
  }

  /// Assigns a complaint to the currently logged-in user.
  /// If the case was just submitted, it automatically moves to under review.
  Future<void> assignComplaintToCurrentUser({
    required String complaintId,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final actor = _currentActorName;

    final docRef = _firestore.collection('complaints').doc(complaintId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Complaint not found');

    final complaintData = doc.data() ?? <String, dynamic>{};
    final complaintOwnerId = (complaintData['userId'] ?? '').toString();
    final complaintSubject = _safeComplaintSubject(
      (complaintData['subject'] ?? '').toString(),
    );

    final currentStatus = ComplaintStatus.fromString(
      (doc.data()?['status'] as String?) ?? ComplaintStatus.submitted.value,
    );

    final shouldMoveToReview = currentStatus == ComplaintStatus.submitted;
    final nextStatus = shouldMoveToReview
        ? ComplaintStatus.underReview
        : currentStatus;

    final historyEntry = StatusUpdate(
      status: nextStatus,
      note: 'Assigned to $actor',
      updatedBy: actor,
      timestamp: now,
    );

    await docRef.update({
      'assignedToUserId': _currentUserId,
      'assignedToName': actor,
      'assignedAt': Timestamp.fromDate(now),
      'status': nextStatus.value,
      'updatedAt': Timestamp.fromDate(now),
      'statusHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });

    if (complaintOwnerId.isNotEmpty) {
      await _notificationService.notifyUser(
        userId: complaintOwnerId,
        title: 'Complaint Assigned for Review',
        message:
            'Your complaint "$complaintSubject" has been assigned and is now under review.',
        topic: NotificationTopic.complaint,
        entityId: complaintId,
        entityType: 'complaint',
      );
    }
  }

  /// Clears any active assignee from the complaint.
  Future<void> clearComplaintAssignment({required String complaintId}) async {
    final now = DateTime.now();
    final actor = _currentActorName;
    final docRef = _firestore.collection('complaints').doc(complaintId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Complaint not found');

    final complaintData = doc.data() ?? <String, dynamic>{};
    final complaintOwnerId = (complaintData['userId'] ?? '').toString();
    final complaintSubject = _safeComplaintSubject(
      (complaintData['subject'] ?? '').toString(),
    );

    final historyEntry = StatusUpdate(
      status: ComplaintStatus.underReview,
      note: 'Assignment cleared by $actor',
      updatedBy: actor,
      timestamp: now,
    );

    await docRef.update({
      'assignedToUserId': null,
      'assignedToName': null,
      'assignedAt': null,
      'updatedAt': Timestamp.fromDate(now),
      'statusHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });

    if (complaintOwnerId.isNotEmpty) {
      await _notificationService.notifyUser(
        userId: complaintOwnerId,
        title: 'Complaint Assignment Updated',
        message:
            'Assignment for your complaint "$complaintSubject" was cleared and the case remains under review.',
        topic: NotificationTopic.complaint,
        entityId: complaintId,
        entityType: 'complaint',
      );
    }
  }

  /// Uses Gemini AI to classify a complaint's category and generate
  /// a summary. Saves the result to Firestore so it's only computed once.
  Future<({String category, String summary})> classifyComplaintWithAI({
    required String complaintId,
    required String subject,
    required String description,
  }) async {
    final result = await GeminiService.classifyComplaintCategory(
      subject: subject,
      description: description,
    );

    await _firestore.collection('complaints').doc(complaintId).update({
      'aiCategory': result.category,
      'aiSummary': result.summary,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return result;
  }

  /// Uses Gemini AI to verify whether this complaint is routed
  /// to the correct department. Saves the recommendation to Firestore.
  Future<ComplaintDepartment> checkDepartmentRouting({
    required String complaintId,
    required String subject,
    required String description,
  }) async {
    final recommended = await GeminiService.classifyComplaint(
      subject: subject,
      description: description,
    );

    await _firestore.collection('complaints').doc(complaintId).update({
      'aiRecommendedDepartment': recommended.value,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return recommended;
  }

  /// Escalate (re-route) a complaint to a different department.
  /// Records who performed the escalation in the status history.
  Future<void> escalateComplaint({
    required String complaintId,
    required ComplaintDepartment targetDepartment,
  }) async {
    final docRef = _firestore.collection('complaints').doc(complaintId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Complaint not found');

    final complaintData = doc.data() ?? <String, dynamic>{};
    final complaintOwnerId = (complaintData['userId'] ?? '').toString();
    final complaintSubject = _safeComplaintSubject(
      (complaintData['subject'] ?? '').toString(),
    );

    final actor = _currentActorName;
    final now = DateTime.now();

    final historyEntry = StatusUpdate(
      status: ComplaintStatus.submitted,
      note: 'Escalated to ${targetDepartment.displayName}',
      updatedBy: actor,
      timestamp: now,
    );

    await docRef.update({
      'department': targetDepartment.value,
      'status': ComplaintStatus.submitted.value,
      'assignedToUserId': null,
      'assignedToName': null,
      'assignedAt': null,
      'updatedAt': Timestamp.fromDate(now),
      'statusHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });

    if (complaintOwnerId.isNotEmpty) {
      await _notificationService.notifyUser(
        userId: complaintOwnerId,
        title: 'Complaint Escalated',
        message:
            'Your complaint "$complaintSubject" was escalated to ${targetDepartment.displayName}.',
        topic: NotificationTopic.complaint,
        entityId: complaintId,
        entityType: 'complaint',
      );
    }

    await _notificationService.notifyUsersByRole(
      role: _roleForDepartment(targetDepartment),
      title: 'Complaint Escalated to ${targetDepartment.displayName}',
      message:
          'Complaint "$complaintSubject" has been escalated and needs review.',
      topic: NotificationTopic.complaint,
      entityId: complaintId,
      entityType: 'complaint',
      excludeUserId: _currentUserId,
    );
  }

  /// Delete a complaint.
  /// Usually only allowed for the employee who created it, and only if unresolved.
  Future<void> deleteComplaint(String complaintId) async {
    if (_currentUserId == null) throw 'User not authenticated';

    // Verify ownership and status before deleting (though UI already filters, backend check is safer)
    final doc = await _firestore
        .collection('complaints')
        .doc(complaintId)
        .get();
    if (!doc.exists) throw 'Complaint not found';

    final complaintData = doc.data()!;
    if (complaintData['userId'] != _currentUserId) {
      throw 'Not authorized to delete this complaint';
    }

    final String statusString = complaintData['status'] as String;
    final status = ComplaintStatus.fromString(statusString);

    if (status == ComplaintStatus.resolved ||
        status == ComplaintStatus.dismissed) {
      throw 'Cannot delete a resolved or dismissed complaint';
    }

    await _firestore.collection('complaints').doc(complaintId).delete();
  }

  /// Uses Gemini AI to assess the urgency level of a complaint.
  /// Saves the result (urgency + reasoning) to Firestore.
  Future<({String urgency, String reason})> assessUrgencyWithAI({
    required String complaintId,
    required String subject,
    required String description,
  }) async {
    final result = await GeminiService.assessUrgency(
      subject: subject,
      description: description,
    );

    await _firestore.collection('complaints').doc(complaintId).update({
      'aiUrgency': result.urgency,
      'aiUrgencyReason': result.reason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return result;
  }

  /// Manually set or override the urgency of a complaint (HR/Legal override).
  Future<void> setUrgencyManually({
    required String complaintId,
    required String urgency,
  }) async {
    final docRef = _firestore.collection('complaints').doc(complaintId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Complaint not found');

    final complaintData = doc.data() ?? <String, dynamic>{};
    final complaintOwnerId = (complaintData['userId'] ?? '').toString();
    final complaintSubject = _safeComplaintSubject(
      (complaintData['subject'] ?? '').toString(),
    );

    final actor = _currentActorName;
    final now = DateTime.now();
    await docRef.update({
      'aiUrgency': urgency,
      'aiUrgencyReason': 'Manually set to $urgency by $actor',
      'updatedAt': Timestamp.fromDate(now),
    });

    if (complaintOwnerId.isNotEmpty) {
      await _notificationService.notifyUser(
        userId: complaintOwnerId,
        title: 'Complaint Urgency Updated',
        message:
            'Urgency for your complaint "$complaintSubject" was updated to $urgency.',
        topic: NotificationTopic.complaint,
        entityId: complaintId,
        entityType: 'complaint',
      );
    }
  }

  /// Manually assign a corporate priority level (P0/P1/P2) to a complaint.
  /// Both HR and Legal can use this method.
  /// Records who set the priority and when, plus a status history entry.
  Future<void> updateComplaintPriority({
    required String complaintId,
    required ComplaintPriority priority,
  }) async {
    final docRef = _firestore.collection('complaints').doc(complaintId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Complaint not found');

    final complaintData = doc.data() ?? <String, dynamic>{};
    final complaintOwnerId = (complaintData['userId'] ?? '').toString();
    final complaintSubject = _safeComplaintSubject(
      (complaintData['subject'] ?? '').toString(),
    );

    final actor = _currentActorName;
    final now = DateTime.now();

    final historyEntry = StatusUpdate(
      status: ComplaintStatus.underReview,
      note: 'Priority set to ${priority.displayName} by $actor',
      updatedBy: actor,
      timestamp: now,
    );

    await docRef.update({
      'priority': priority.value,
      'prioritySetBy': actor,
      'prioritySetAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'statusHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });

    if (complaintOwnerId.isNotEmpty) {
      await _notificationService.notifyUser(
        userId: complaintOwnerId,
        title: 'Complaint Priority Updated',
        message:
            'Priority for your complaint "$complaintSubject" was set to ${priority.displayName}.',
        topic: NotificationTopic.complaint,
        entityId: complaintId,
        entityType: 'complaint',
      );
    }
  }
}
