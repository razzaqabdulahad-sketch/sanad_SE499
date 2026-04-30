import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request.dart';
import '../../services/leave_service.dart';
import '../../services/auth_service.dart';
import '../shared/chat_fab.dart';
import 'apply_leave_screen.dart';

class MyLeavesScreen extends StatelessWidget {
  const MyLeavesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final leaveService = LeaveService();
    final authService = AuthService();
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Leaves'),
          backgroundColor: const Color(0xFF0D3B66),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Leave Balance Card
          StreamBuilder<LeaveBalance>(
            stream: leaveService.streamLeaveBalance(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final balance = snapshot.data!;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D3B66), Color(0xFF1A5490)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Leave Balance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBalanceColumn(
                          context,
                          'Casual',
                          balance.casualRemaining,
                          balance.casualLeaves,
                          Icons.event_available,
                        ),
                        _buildDivider(),
                        _buildBalanceColumn(
                          context,
                          'Medical',
                          balance.medicalRemaining,
                          balance.medicalLeaves,
                          Icons.local_hospital,
                        ),
                        _buildDivider(),
                        _buildBalanceColumn(
                          context,
                          'Annual',
                          balance.annualRemaining,
                          balance.annualLeaves,
                          Icons.beach_access,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Total: ${balance.totalRemaining}/${balance.totalLeaves} days remaining',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Leave Requests List
          Expanded(
            child: StreamBuilder<List<LeaveRequest>>(
              stream: leaveService.getEmployeeLeaveRequests(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final leaveRequests = snapshot.data ?? [];

                if (leaveRequests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No leave requests yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to apply for leave',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: leaveRequests.length,
                  itemBuilder: (context, index) {
                    final leave = leaveRequests[index];
                    return _buildLeaveRequestCard(context, leave);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ChatFab(heroTag: 'chatFabLeaves'),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'applyLeaveFab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApplyLeaveScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFF0D3B66),
            icon: const Icon(Icons.add),
            label: const Text('Apply Leave'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceColumn(
    BuildContext context,
    String label,
    int remaining,
    int total,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          '$remaining',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'of $total',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 60,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildLeaveRequestCard(BuildContext context, LeaveRequest leave) {
    Color statusColor;
    IconData statusIcon;

    switch (leave.status) {
      case LeaveStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case LeaveStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case LeaveStatus.pending:
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getLeaveTypeColor(leave.leaveType)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getLeaveTypeIcon(leave.leaveType),
                          color: _getLeaveTypeColor(leave.leaveType),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leave.leaveType.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${leave.totalDays} ${leave.totalDays == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        leave.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(leave.startDate)} - ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leave.reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (leave.reviewComment != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment,
                        size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HR Comment:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            leave.reviewComment!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (leave.overrideReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        size: 16, color: Colors.deepPurple.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Override Reason:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            leave.overrideReason!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.deepPurple.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getLeaveTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.casual:
        return Colors.blue;
      case LeaveType.medical:
        return Colors.red;
      case LeaveType.annual:
        return Colors.green;
    }
  }

  IconData _getLeaveTypeIcon(LeaveType type) {
    switch (type) {
      case LeaveType.casual:
        return Icons.event_available;
      case LeaveType.medical:
        return Icons.local_hospital;
      case LeaveType.annual:
        return Icons.beach_access;
    }
  }
}
