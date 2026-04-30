import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../shared/chat_fab.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isLoading = false;

  String get _employeeId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _handleCheckIn() async {
    setState(() => _isLoading = true);
    try {
      await _attendanceService.checkIn(_employeeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isLoading = true);
    try {
      await _attendanceService.checkOut(_employeeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-out recorded successfully!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final workingDays = _attendanceService.workingDaysElapsed(now: now);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's status + mark attendance
            StreamBuilder<AttendanceRecord?>(
              stream: _attendanceService.streamTodayAttendance(_employeeId),
              builder: (context, snapshot) {
                final record = snapshot.data;
                return _buildTodayCard(record, workingDays);
              },
            ),
            const SizedBox(height: 24),

            // Monthly stats
            Text(
              'This Month\'s Attendance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D3B66),
                  ),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<AttendanceRecord>>(
              stream: _attendanceService.streamMonthAttendance(
                _employeeId,
                now.year,
                now.month,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data ?? [];
                final daysPresent =
                    records.where((r) => r.status == 'present').length;

                return Column(
                  children: [
                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            label: 'Days Present',
                            value: '$daysPresent',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            label: 'Absent Days',
                            value: '${(workingDays - daysPresent).clamp(0, workingDays)}',
                            icon: Icons.cancel_rounded,
                            color: const Color(0xFFC62828),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            label: 'Working Days',
                            value: '$workingDays',
                            icon: Icons.calendar_month_rounded,
                            color: const Color(0xFF0D3B66),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Records list
                    if (records.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No attendance records this month.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      )
                    else
                      ...records.map((r) => _buildRecordTile(r)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: const ChatFab(),
    );
  }

  Widget _buildTodayCard(AttendanceRecord? record, int workingDays) {
    final isCheckedIn = record?.hasCheckedIn ?? false;
    final isCheckedOut = record?.hasCheckedOut ?? false;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!isCheckedIn) {
      statusText = 'Not Checked In';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule_rounded;
    } else if (!isCheckedOut) {
      statusText = 'Checked In at ${record!.formattedCheckIn}';
      statusColor = Colors.green;
      statusIcon = Icons.login_rounded;
    } else {
      statusText =
          'Checked In: ${record!.formattedCheckIn} — Out: ${record.formattedCheckOut}';
      statusColor = const Color(0xFF0D3B66);
      statusIcon = Icons.logout_rounded;
    }

    return Card(
      elevation: 4,
      color: const Color(0xFF0D3B66),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (record != null && record.workedDuration != null) ...[
              const SizedBox(height: 8),
              Text(
                'Hours worked: ${_formatDuration(record.workedDuration!)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            // Action buttons
            if (!isCheckedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleCheckIn,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (!isCheckedOut)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleCheckOut,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: const Text('Check Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A7FA0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Attendance recorded for today',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(AttendanceRecord record) {
    final color =
        record.status == 'present' ? Colors.green : Colors.red;
    final icon =
        record.status == 'present' ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          _formatDate(record.date),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            if (record.checkInTime != null) ...[
              const Icon(Icons.login_rounded, size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Text(record.formattedCheckIn,
                  style: const TextStyle(fontSize: 12)),
            ],
            if (record.checkOutTime != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.logout_rounded, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text(record.formattedCheckOut,
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        trailing: record.workedDuration != null
            ? Text(
                _formatDuration(record.workedDuration!),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
