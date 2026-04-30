import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the Firestore document ID for a given employee + date.
  /// Format: `{employeeId}_{YYYY-MM-DD}`
  String _docId(String employeeId, DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${employeeId}_$dateStr';
  }

  /// Mark check-in for today. Throws if already checked in.
  Future<void> checkIn(String employeeId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docId = _docId(employeeId, today);
    final ref = _firestore.collection('attendance').doc(docId);

    final snapshot = await ref.get();
    if (snapshot.exists) {
      final record = AttendanceRecord.fromMap(snapshot.id, snapshot.data()!);
      if (record.hasCheckedIn) {
        throw 'You have already checked in today at ${record.formattedCheckIn}.';
      }
      // Record exists (created by system) but no check-in yet
      await ref.update({
        'checkInTime': Timestamp.fromDate(now),
        'status': 'present',
      });
    } else {
      final record = AttendanceRecord(
        id: docId,
        employeeId: employeeId,
        date: today,
        checkInTime: now,
        status: 'present',
      );
      await ref.set(record.toMap());
    }
  }

  /// Mark check-out for today. Throws if not checked in yet.
  Future<void> checkOut(String employeeId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docId = _docId(employeeId, today);
    final ref = _firestore.collection('attendance').doc(docId);

    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw 'You have not checked in today yet.';
    }
    final record = AttendanceRecord.fromMap(snapshot.id, snapshot.data()!);
    if (!record.hasCheckedIn) {
      throw 'You have not checked in today yet.';
    }
    if (record.hasCheckedOut) {
      throw 'You have already checked out today at ${record.formattedCheckOut}.';
    }

    await ref.update({'checkOutTime': Timestamp.fromDate(now)});
  }

  /// Stream today's attendance record (null if none exists yet).
  Stream<AttendanceRecord?> streamTodayAttendance(String employeeId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docId = _docId(employeeId, today);

    return _firestore
        .collection('attendance')
        .doc(docId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return AttendanceRecord.fromMap(snap.id, snap.data()!);
    });
  }

  /// Stream all attendance records for a given month.
  Stream<List<AttendanceRecord>> streamMonthAttendance(
    String employeeId,
    int year,
    int month,
  ) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    return _firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Returns count of days present in the current month.
  Stream<int> streamDaysPresentThisMonth(String employeeId) {
    final now = DateTime.now();
    return streamMonthAttendance(employeeId, now.year, now.month).map(
      (records) =>
          records.where((r) => r.status == 'present').length,
    );
  }

  /// Returns total working days elapsed so far this month (Mon–Sat).
  int workingDaysElapsed({DateTime? now}) {
    final today = now ?? DateTime.now();
    int count = 0;
    for (int d = 1; d <= today.day; d++) {
      final day = DateTime(today.year, today.month, d);
      if (day.weekday != DateTime.sunday) count++;
    }
    return count;
  }

  /// Stream recent attendance records (last 7 records).
  Stream<List<AttendanceRecord>> streamRecentAttendance(String employeeId) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 30));

    return _firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('date', descending: true)
        .limit(7)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}
