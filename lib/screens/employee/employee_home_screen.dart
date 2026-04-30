import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../shared/chat_fab.dart';
import '../../models/leave_request.dart';
import '../../models/user_role.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/leave_service.dart';
import 'attendance_screen.dart';
import 'file_complaint_screen.dart';
import 'my_complaints_screen.dart';
import 'my_leaves_screen.dart';
import 'profile_screen.dart';
import '../shared/notification_bell_button.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final AuthService _authService = AuthService();
  final AttendanceService _attendanceService = AttendanceService();
  final LeaveService _leaveService = LeaveService();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isLoading = false;

  Future<void> _handleCheckIn() async {
    setState(() => _isLoading = true);
    try {
      await _attendanceService.checkIn(_uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in recorded!'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isLoading = true);
    try {
      await _attendanceService.checkOut(_uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-out recorded!'),
            backgroundColor: Color(0xFF1A7FA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _primary = Color(0xFF0D3B66);
  static const _secondary = Color(0xFF1A7FA0);
  static const _complaint = Color(0xFFC62828);
  static const _purple = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
          primary: _primary,
          secondary: _secondary,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Employee Dashboard'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          actions: const [
            NotificationBellButton(role: UserRole.employee),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: _primary,
                ),
                accountName: Text(FirebaseAuth.instance.currentUser?.displayName ?? 'Employee'),
                accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: _primary),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _authService.signOut();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildAttendanceCard(),
              const SizedBox(height: 14),
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),
              _buildRecentActivitySection(),
            ],
          ),
        ),
        floatingActionButton: const ChatFab(),
      ),
    );
  }

  // ── Welcome Card ──────────────────────────────────────────────────────────

  Widget _buildWelcomeCard() {
    final displayName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Employee';

    return Card(
      elevation: 4,
      color: const Color(0xFF1A4D7A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person_rounded,
                  size: 35, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final now = DateTime.now();
    final workingDays = _attendanceService.workingDaysElapsed(now: now);

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<AttendanceRecord>>(
            stream: _attendanceService.streamMonthAttendance(
                _uid, now.year, now.month),
            builder: (context, snapshot) {
              final records = snapshot.data ?? [];
              final present =
                  records.where((r) => r.status == 'present').length;
              return _buildStatCard(
                label: 'Days Present',
                value: '$present / $workingDays',
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFF2E7D32),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<LeaveBalance>(
            stream: _leaveService.streamLeaveBalance(_uid),
            builder: (context, snapshot) {
              final balance = snapshot.data;
              final used = balance != null
                  ? balance.casualUsed +
                      balance.medicalUsed +
                      balance.annualUsed
                  : 0;
              final total = balance != null
                  ? balance.casualLeaves +
                      balance.medicalLeaves +
                      balance.annualLeaves
                  : 0;
              return _buildStatCard(
                label: 'Leaves Used',
                value: '$used / $total',
                icon: Icons.beach_access_rounded,
                color: const Color(0xFFE65100),
              );
            },
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance Card ────────────────────────────────────────────────────────

  Widget _buildAttendanceCard() {
    return StreamBuilder<AttendanceRecord?>(
      stream: _attendanceService.streamTodayAttendance(_uid),
      builder: (context, snapshot) {
        final record = snapshot.data;
        final checkedIn = record?.hasCheckedIn ?? false;
        final checkedOut = record?.hasCheckedOut ?? false;

        String statusText;
        Color statusColor;

        if (!checkedIn) {
          statusText = 'Not checked in yet';
          statusColor = Colors.orange;
        } else if (!checkedOut) {
          statusText = 'In at ${record!.formattedCheckIn}';
          statusColor = const Color(0xFF2E7D32);
        } else {
          statusText =
              'In ${record!.formattedCheckIn}  ·  Out ${record.formattedCheckOut}';
          statusColor = _primary;
        }

        return Card(
          elevation: 3,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_today_rounded,
                        color: _primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  // Title + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'My Attendance',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0D3B66),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Check-in / Check-out buttons
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary),
                    )
                  else if (!checkedIn)
                    _buildPillButton(
                      label: 'Check In',
                      color: const Color(0xFF2E7D32),
                      onTap: _handleCheckIn,
                    )
                  else if (!checkedOut)
                    _buildPillButton(
                      label: 'Check Out',
                      color: _secondary,
                      onTap: _handleCheckOut,
                    )
                  else
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32), size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPillButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _buildActionCard(
          'Leave Request',
          Icons.event_busy_rounded,
          _secondary,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyLeavesScreen())),
        ),
        _buildActionCard(
          'File Complaint',
          Icons.report_problem_rounded,
          _complaint,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FileComplaintScreen())),
        ),
        _buildActionCard(
          'My Complaints',
          Icons.track_changes_rounded,
          _purple,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyComplaintsScreen())),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildRecentAttendanceTiles(),
        const SizedBox(height: 8),
        _buildRecentLeavesTiles(),
      ],
    );
  }

  Widget _buildRecentAttendanceTiles() {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: _attendanceService.streamRecentAttendance(_uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final records = snapshot.data!.take(3).toList();
        return Column(
          children: records.map((r) {
            final label = r.hasCheckedOut
                ? 'In: ${r.formattedCheckIn}  ·  Out: ${r.formattedCheckOut}'
                : r.hasCheckedIn
                    ? 'Checked in at ${r.formattedCheckIn}'
                    : 'Absent';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildActivityTile(
                title: 'Attendance — ${_shortDate(r.date)}',
                subtitle: label,
                icon: Icons.fingerprint_rounded,
                color: Colors.green,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecentLeavesTiles() {
    return StreamBuilder<List<LeaveRequest>>(
      stream: _leaveService.getEmployeeLeaveRequests(_uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final leaves = snapshot.data!.take(3).toList();
        return Column(
          children: leaves.map((l) {
            final statusColor = l.status == LeaveStatus.approved
                ? Colors.green
                : l.status == LeaveStatus.rejected
                    ? Colors.red
                    : Colors.orange;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildActivityTile(
                title: '${l.leaveType.displayName} — ${l.status.displayName}',
                subtitle:
                    '${_shortDate(l.startDate)} → ${_shortDate(l.endDate)}  (${l.totalDays}d)',
                icon: Icons.event_busy_rounded,
                color: statusColor,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}
