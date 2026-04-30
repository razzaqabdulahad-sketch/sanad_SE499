import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // 'present' | 'absent' | 'half_day'

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
  });

  bool get hasCheckedIn => checkInTime != null;
  bool get hasCheckedOut => checkOutTime != null;

  /// Duration worked today (requires both check-in and check-out)
  Duration? get workedDuration {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime!);
  }

  String get formattedCheckIn {
    if (checkInTime == null) return '-';
    return _formatTime(checkInTime!);
  }

  String get formattedCheckOut {
    if (checkOutTime == null) return '-';
    return _formatTime(checkOutTime!);
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'status': status,
    };
  }

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) {
    DateTime? toDateTime(dynamic ts) {
      if (ts == null) return null;
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return AttendanceRecord(
      id: id,
      employeeId: data['employeeId'] ?? '',
      date: toDateTime(data['date']) ?? DateTime.now(),
      checkInTime: toDateTime(data['checkInTime']),
      checkOutTime: toDateTime(data['checkOutTime']),
      status: data['status'] ?? 'present',
    );
  }
}
