import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/leave_service.dart';
import '../../models/complaint.dart';
import '../../models/leave_request.dart';
import '../shared/manage_complaints_screen.dart';
import '../shared/notification_bell_button.dart';
import 'manage_leaves_screen.dart';
import 'employee_leave_balance_screen.dart';
import 'employee_list_screen.dart';
import 'chatbot_management_screen.dart';

class HRHomeScreen extends StatefulWidget {
  const HRHomeScreen({super.key});

  @override
  State<HRHomeScreen> createState() => _HRHomeScreenState();
}

class _HRHomeScreenState extends State<HRHomeScreen> {
  final _authService = AuthService();
  final _leaveService = LeaveService();
  final _firestore = FirebaseFirestore.instance;

  static const _primaryColor = Color(0xFF6A1B9A);
  static const _secondaryColor = Color(0xFF8E24AA);

  Stream<QuerySnapshot> get _employeesStream => _firestore
      .collection('users')
      .where('role', isEqualTo: 'employee')
      .snapshots();

  Stream<List<LeaveRequest>> get _pendingLeavesStream =>
      _leaveService.getPendingLeaveRequests();

  Stream<QuerySnapshot> get _recentLeavesStream => _firestore
      .collection('leave_requests')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();

  Stream<QuerySnapshot> get _recentComplaintsStream => _firestore
      .collection('complaints')
      .where('department', isEqualTo: 'hr')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
      primary: _primaryColor,
      secondary: _secondaryColor,
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HR Dashboard'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          actions: [
            const NotificationBellButton(role: UserRole.hr),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign Out',
              onPressed: () async {
                await _authService.signOut();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Card ──────────────────────────────────────────
              Card(
                elevation: 4,
                color: const Color(0xFF7B1FA2),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(
                          Icons.people_rounded,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sanad HR Portal',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            Text(
                              'Manage your workforce',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Live Stats ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _employeesStream,
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        return _buildStatCard(
                          context,
                          snapshot.connectionState == ConnectionState.waiting
                              ? '—'
                              : '$count',
                          'Total Employees',
                          Icons.people_alt_rounded,
                          colorScheme.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<List<LeaveRequest>>(
                      stream: _pendingLeavesStream,
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return _buildStatCard(
                          context,
                          snapshot.connectionState == ConnectionState.waiting
                              ? '—'
                              : '$count',
                          'Pending Leave Requests',
                          Icons.pending_actions_rounded,
                          Colors.orange,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Quick Actions ─────────────────────────────────────────
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'Employee List',
                    Icons.list_alt_rounded,
                    colorScheme.primary,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployeeListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Leave Approvals',
                    Icons.approval_rounded,
                    colorScheme.secondary,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageLeavesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Complaints',
                    Icons.report_rounded,
                    const Color(0xFFC62828),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageComplaintsScreen(
                            department: ComplaintDepartment.hr,
                            primaryColor: Color(0xFF6A1B9A),
                            accentColor: Color(0xFF8E24AA),
                          ),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Leave Balances',
                    Icons.event_note_rounded,
                    Colors.teal,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployeeLeaveBalanceScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Chatbot Management',
                    Icons.smart_toy_rounded,
                    const Color(0xFF1A7FA0),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatbotManagementScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Recent Leave Requests ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Leave Requests',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageLeavesScreen()),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: _recentLeavesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _buildEmptyState(
                        'No leave requests yet', Icons.event_busy_rounded);
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['employeeName'] ?? 'Unknown';
                      final leaveType =
                          LeaveType.fromString(data['leaveType'] ?? 'casual');
                      final status =
                          LeaveStatus.fromString(data['status'] ?? 'pending');
                      final startDate =
                          (data['startDate'] as Timestamp?)?.toDate();
                      final endDate =
                          (data['endDate'] as Timestamp?)?.toDate();
                      final createdAt =
                          (data['createdAt'] as Timestamp?)?.toDate();

                      String dateRange = '';
                      if (startDate != null && endDate != null) {
                        dateRange =
                            '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d').format(endDate)}';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildLeaveRequestCard(
                          context,
                          name: name,
                          leaveType: leaveType,
                          status: status,
                          dateRange: dateRange,
                          createdAt: createdAt,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ManageLeavesScreen()),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Recent HR Complaints ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Complaints',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageComplaintsScreen(
                          department: ComplaintDepartment.hr,
                          primaryColor: Color(0xFF6A1B9A),
                          accentColor: Color(0xFF8E24AA),
                        ),
                      ),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: _recentComplaintsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _buildEmptyState(
                        'No complaints yet', Icons.report_off_rounded);
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final subject = data['subject'] ?? 'No subject';
                      final status = ComplaintStatus.fromString(
                          data['status'] ?? 'submitted');
                      final isAnonymous = data['isAnonymous'] == true;
                      final employeeName = isAnonymous
                          ? 'Anonymous'
                          : (data['employeeName'] ?? 'Unknown');
                      final createdAt =
                          (data['createdAt'] as Timestamp?)?.toDate();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildComplaintCard(
                          context,
                          subject: subject,
                          employeeName: employeeName,
                          status: status,
                          createdAt: createdAt,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageComplaintsScreen(
                                department: ComplaintDepartment.hr,
                                primaryColor: Color(0xFF6A1B9A),
                                accentColor: Color(0xFF8E24AA),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────

  Widget _buildEmptyState(String message, IconData icon) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 12),
            Text(message,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestCard(
    BuildContext context, {
    required String name,
    required LeaveType leaveType,
    required LeaveStatus status,
    required String dateRange,
    DateTime? createdAt,
    VoidCallback? onTap,
  }) {
    final statusColor = switch (status) {
      LeaveStatus.pending => Colors.orange,
      LeaveStatus.approved => Colors.green,
      LeaveStatus.rejected => Colors.red,
    };

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.orange.withOpacity(0.15),
                child: const Icon(Icons.event_busy_rounded,
                    color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${leaveType.displayName}${dateRange.isNotEmpty ? ' · $dateRange' : ''}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(createdAt),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(
    BuildContext context, {
    required String subject,
    required String employeeName,
    required ComplaintStatus status,
    DateTime? createdAt,
    VoidCallback? onTap,
  }) {
    final statusColor = switch (status) {
      ComplaintStatus.submitted => Colors.blueGrey,
      ComplaintStatus.underReview => Colors.blue,
      ComplaintStatus.inProgress => Colors.orange,
      ComplaintStatus.resolved => Colors.green,
      ComplaintStatus.dismissed => Colors.grey,
    };

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFC62828).withOpacity(0.12),
                child: const Icon(Icons.report_rounded,
                    color: Color(0xFFC62828), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'By $employeeName',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(createdAt),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
