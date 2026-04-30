import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import '../models/leave_request.dart';
import '../models/user_role.dart';
import 'notification_service.dart';

class LeaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  String _guessContentType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<String> _encodePrescriptionAsDataUri(File file) async {
    if (!await file.exists()) {
      throw Exception(
        'Selected prescription file no longer exists. Please attach it again.',
      );
    }

    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    return 'data:${_guessContentType(file.path)};base64,$base64Data';
  }

  // Submit a leave request
  Future<String> submitLeaveRequest({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    File? attachmentFile,
  }) async {
    try {
      // Check if employee has sufficient leave balance
      final leaveBalance = await getLeaveBalance(employeeId);
      final requestedDays = endDate.difference(startDate).inDays + 1;

      int remainingBalance = 0;
      switch (leaveType) {
        case LeaveType.casual:
          remainingBalance = leaveBalance.casualRemaining;
          break;
        case LeaveType.medical:
          remainingBalance = leaveBalance.medicalRemaining;
          break;
        case LeaveType.annual:
          remainingBalance = leaveBalance.annualRemaining;
          break;
      }

      if (requestedDays > remainingBalance) {
        throw 'Insufficient ${leaveType.displayName} balance. You have $remainingBalance days remaining.';
      }

      String? finalAttachmentUrl;

      if (attachmentFile != null) {
        finalAttachmentUrl = await _encodePrescriptionAsDataUri(attachmentFile);
      }

      final leaveRequest = LeaveRequest(
        id: '',
        employeeId: employeeId,
        employeeName: employeeName,
        employeeEmail: employeeEmail,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        status: LeaveStatus.pending,
        createdAt: DateTime.now(),
        attachmentUrl: finalAttachmentUrl,
      );

      final docRef = await _firestore
          .collection('leave_requests')
          .add(leaveRequest.toMap());

      final summary =
          '${leaveType.displayName} request for $requestedDays day${requestedDays == 1 ? '' : 's'}';

      await _notificationService.notifyUser(
        userId: employeeId,
        title: 'Leave Request Submitted',
        message: 'Your $summary has been submitted for HR review.',
        topic: NotificationTopic.leave,
        entityId: docRef.id,
        entityType: 'leave',
      );

      await _notificationService.notifyUsersByRole(
        role: UserRole.hr,
        title: 'New Leave Request',
        message: '$employeeName submitted a $summary.',
        topic: NotificationTopic.leave,
        entityId: docRef.id,
        entityType: 'leave',
      );

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get leave requests for an employee
  Stream<List<LeaveRequest>> getEmployeeLeaveRequests(String employeeId) {
    return _firestore
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaveRequest.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Get all pending leave requests (for HR)
  Stream<List<LeaveRequest>> getPendingLeaveRequests() {
    return _firestore
        .collection('leave_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaveRequest.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Get all leave requests (for HR)
  Stream<List<LeaveRequest>> getAllLeaveRequests() {
    return _firestore
        .collection('leave_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaveRequest.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Approve a leave request
  Future<void> approveLeaveRequest({
    required String leaveRequestId,
    required String reviewedBy,
    String? reviewComment,
  }) async {
    try {
      // Get the leave request
      final leaveDoc =
          await _firestore.collection('leave_requests').doc(leaveRequestId).get();
      
      if (!leaveDoc.exists) {
        throw 'Leave request not found';
      }

      final leaveRequest = LeaveRequest.fromMap(leaveDoc.id, leaveDoc.data()!);

      // Update leave request status
      await _firestore.collection('leave_requests').doc(leaveRequestId).update({
        'status': LeaveStatus.approved.value,
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewComment': reviewComment,
      });

      // Update employee leave balance
      final leaveBalance = await getLeaveBalance(leaveRequest.employeeId);
      final daysToDeduct = leaveRequest.totalDays;

      int casualUsed = leaveBalance.casualUsed;
      int medicalUsed = leaveBalance.medicalUsed;
      int annualUsed = leaveBalance.annualUsed;

      switch (leaveRequest.leaveType) {
        case LeaveType.casual:
          casualUsed += daysToDeduct;
          break;
        case LeaveType.medical:
          medicalUsed += daysToDeduct;
          break;
        case LeaveType.annual:
          annualUsed += daysToDeduct;
          break;
      }

      await _firestore
          .collection('leave_balances')
          .doc(leaveRequest.employeeId)
          .update({
        'casualUsed': casualUsed,
        'medicalUsed': medicalUsed,
        'annualUsed': annualUsed,
      });

      await _notificationService.notifyUser(
        userId: leaveRequest.employeeId,
        title: 'Leave Request Approved',
        message:
            'Your ${leaveRequest.leaveType.displayName} request has been approved.',
        topic: NotificationTopic.leave,
        entityId: leaveRequestId,
        entityType: 'leave',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Reject a leave request
  Future<void> rejectLeaveRequest({
    required String leaveRequestId,
    required String reviewedBy,
    String? reviewComment,
  }) async {
    try {
      final leaveDoc =
          await _firestore.collection('leave_requests').doc(leaveRequestId).get();

      if (!leaveDoc.exists) {
        throw 'Leave request not found';
      }

      final leaveRequest = LeaveRequest.fromMap(leaveDoc.id, leaveDoc.data()!);

      await _firestore.collection('leave_requests').doc(leaveRequestId).update({
        'status': LeaveStatus.rejected.value,
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewComment': reviewComment,
      });

      await _notificationService.notifyUser(
        userId: leaveRequest.employeeId,
        title: 'Leave Request Rejected',
        message:
            'Your ${leaveRequest.leaveType.displayName} request has been rejected.',
        topic: NotificationTopic.leave,
        entityId: leaveRequestId,
        entityType: 'leave',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Override a previously approved or rejected leave decision.
  /// Handles leave balance adjustments automatically:
  ///  - Overriding approved → rejected: restores the deducted leave days.
  ///  - Overriding rejected → approved: deducts the leave days from balance.
  Future<void> overrideLeaveDecision({
    required String leaveRequestId,
    required LeaveStatus newStatus,
    required String overriddenBy,
    required String overrideReason,
  }) async {
    try {
      final leaveDoc =
          await _firestore.collection('leave_requests').doc(leaveRequestId).get();

      if (!leaveDoc.exists) {
        throw 'Leave request not found';
      }

      final leaveRequest = LeaveRequest.fromMap(leaveDoc.id, leaveDoc.data()!);
      final oldStatus = leaveRequest.status;

      if (oldStatus == newStatus) {
        throw 'Leave is already ${newStatus.displayName}';
      }

      // Update the leave request with override info
      await _firestore
          .collection('leave_requests')
          .doc(leaveRequestId)
          .update({
        'status': newStatus.value,
        'isOverridden': true,
        'overrideReason': overrideReason,
        'overriddenBy': overriddenBy,
        'overriddenAt': FieldValue.serverTimestamp(),
        'previousStatus': oldStatus.value,
      });

      // Adjust leave balance based on the override direction
      final leaveBalance = await getLeaveBalance(leaveRequest.employeeId);
      final days = leaveRequest.totalDays;

      int casualUsed = leaveBalance.casualUsed;
      int medicalUsed = leaveBalance.medicalUsed;
      int annualUsed = leaveBalance.annualUsed;

      if (oldStatus == LeaveStatus.approved && newStatus == LeaveStatus.rejected) {
        // Was approved, now rejected → restore days
        switch (leaveRequest.leaveType) {
          case LeaveType.casual:
            casualUsed = (casualUsed - days).clamp(0, leaveBalance.casualLeaves);
            break;
          case LeaveType.medical:
            medicalUsed = (medicalUsed - days).clamp(0, leaveBalance.medicalLeaves);
            break;
          case LeaveType.annual:
            annualUsed = (annualUsed - days).clamp(0, leaveBalance.annualLeaves);
            break;
        }
      } else if (oldStatus == LeaveStatus.rejected && newStatus == LeaveStatus.approved) {
        // Was rejected, now approved → deduct days
        switch (leaveRequest.leaveType) {
          case LeaveType.casual:
            casualUsed += days;
            break;
          case LeaveType.medical:
            medicalUsed += days;
            break;
          case LeaveType.annual:
            annualUsed += days;
            break;
        }
      } else if (oldStatus == LeaveStatus.pending && newStatus == LeaveStatus.approved) {
        // Pending → approved → deduct days
        switch (leaveRequest.leaveType) {
          case LeaveType.casual:
            casualUsed += days;
            break;
          case LeaveType.medical:
            medicalUsed += days;
            break;
          case LeaveType.annual:
            annualUsed += days;
            break;
        }
      }
      // pending → rejected: no balance change needed

      await _firestore
          .collection('leave_balances')
          .doc(leaveRequest.employeeId)
          .update({
        'casualUsed': casualUsed,
        'medicalUsed': medicalUsed,
        'annualUsed': annualUsed,
      });

      await _notificationService.notifyUser(
        userId: leaveRequest.employeeId,
        title: 'Leave Decision Overridden',
        message:
            'Your ${leaveRequest.leaveType.displayName} request is now ${newStatus.displayName.toLowerCase()}.',
        topic: NotificationTopic.leave,
        entityId: leaveRequestId,
        entityType: 'leave',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get leave balance for an employee
  Future<LeaveBalance> getLeaveBalance(String employeeId) async {
    try {
      final doc = await _firestore
          .collection('leave_balances')
          .doc(employeeId)
          .get();

      if (doc.exists) {
        return LeaveBalance.fromMap(doc.data()!);
      } else {
        // Create default leave balance if it doesn't exist
        final defaultBalance = LeaveBalance(
          employeeId: employeeId,
          casualLeaves: 10,
          medicalLeaves: 10,
          annualLeaves: 10,
        );
        
        await _firestore
            .collection('leave_balances')
            .doc(employeeId)
            .set(defaultBalance.toMap());
        
        return defaultBalance;
      }
    } catch (e) {
      rethrow;
    }
  }

  // Stream leave balance for an employee
  Stream<LeaveBalance> streamLeaveBalance(String employeeId) {
    return _firestore
        .collection('leave_balances')
        .doc(employeeId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.exists) {
        return LeaveBalance.fromMap(snapshot.data()!);
      } else {
        // Create default leave balance if it doesn't exist
        final defaultBalance = LeaveBalance(
          employeeId: employeeId,
          casualLeaves: 10,
          medicalLeaves: 10,
          annualLeaves: 10,
        );
        
        await _firestore
            .collection('leave_balances')
            .doc(employeeId)
            .set(defaultBalance.toMap());
        
        return defaultBalance;
      }
    });
  }

  // Update leave balance for an employee (HR only)
  Future<void> updateLeaveBalance({
    required String employeeId,
    required int casualLeaves,
    required int medicalLeaves,
    required int annualLeaves,
  }) async {
    try {
      final doc = await _firestore
          .collection('leave_balances')
          .doc(employeeId)
          .get();

      if (doc.exists) {
        final currentBalance = LeaveBalance.fromMap(doc.data()!);
        await _firestore.collection('leave_balances').doc(employeeId).update({
          'casualLeaves': casualLeaves,
          'medicalLeaves': medicalLeaves,
          'annualLeaves': annualLeaves,
          // Keep the used counts
          'casualUsed': currentBalance.casualUsed,
          'medicalUsed': currentBalance.medicalUsed,
          'annualUsed': currentBalance.annualUsed,
        });
      } else {
        // Create new balance
        final newBalance = LeaveBalance(
          employeeId: employeeId,
          casualLeaves: casualLeaves,
          medicalLeaves: medicalLeaves,
          annualLeaves: annualLeaves,
        );
        await _firestore
            .collection('leave_balances')
            .doc(employeeId)
            .set(newBalance.toMap());
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get all employees with their leave balances (HR only)
  Future<List<Map<String, dynamic>>> getAllEmployeesWithBalances() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      List<Map<String, dynamic>> employeesWithBalances = [];

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final leaveBalance = await getLeaveBalance(userDoc.id);

        employeesWithBalances.add({
          'id': userDoc.id,
          'fullName': userData['fullName'] ?? '',
          'email': userData['email'] ?? '',
          'leaveBalance': leaveBalance,
        });
      }

      return employeesWithBalances;
    } catch (e) {
      rethrow;
    }
  }
}
