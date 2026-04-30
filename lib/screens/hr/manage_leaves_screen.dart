import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request.dart';
import '../../services/leave_service.dart';
import '../../services/auth_service.dart';

class ManageLeavesScreen extends StatefulWidget {
  const ManageLeavesScreen({super.key});

  @override
  State<ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<ManageLeavesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _leaveService = LeaveService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLeaveAction(
    LeaveRequest leave,
    bool approve,
  ) async {
    final commentController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve Leave' : 'Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${leave.employeeName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${leave.leaveType.displayName} - ${leave.totalDays} days',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final reviewerId = _authService.currentUser?.uid ?? '';
        
        if (approve) {
          await _leaveService.approveLeaveRequest(
            leaveRequestId: leave.id,
            reviewedBy: reviewerId,
            reviewComment: commentController.text.trim().isEmpty
                ? null
                : commentController.text.trim(),
          );
        } else {
          await _leaveService.rejectLeaveRequest(
            leaveRequestId: leave.id,
            reviewedBy: reviewerId,
            reviewComment: commentController.text.trim().isEmpty
                ? null
                : commentController.text.trim(),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                approve
                    ? 'Leave request approved successfully'
                    : 'Leave request rejected',
              ),
              backgroundColor: approve ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Show dialog for HR to override a previously decided leave request.
  Future<void> _handleOverride(LeaveRequest leave) async {
    final reasonController = TextEditingController();
    LeaveStatus? selectedStatus;

    // Determine available override statuses (opposite of current)
    final availableStatuses = <LeaveStatus>[];
    if (leave.status == LeaveStatus.approved) {
      availableStatuses.add(LeaveStatus.rejected);
    } else if (leave.status == LeaveStatus.rejected) {
      availableStatuses.add(LeaveStatus.approved);
    } else if (leave.status == LeaveStatus.pending) {
      availableStatuses.addAll([LeaveStatus.approved, LeaveStatus.rejected]);
    }

    if (availableStatuses.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.deepPurple, size: 24),
              const SizedBox(width: 8),
              const Text('Override Decision'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will override the current ${leave.status.displayName.toLowerCase()} decision.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${leave.employeeName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${leave.leaveType.displayName} - ${leave.totalDays} days',
              ),
              const SizedBox(height: 16),
              const Text(
                'New Status:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...availableStatuses.map((status) {
                final isSelected = selectedStatus == status;
                final color =
                    status == LeaveStatus.approved ? Colors.green : Colors.red;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () =>
                        setDialogState(() => selectedStatus = status),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == LeaveStatus.approved
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: isSelected ? color : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.displayName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected ? color : Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: color, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Override Reason (required)',
                  hintText: 'Explain why this decision is being overridden...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedStatus != null &&
                      reasonController.text.trim().isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Confirm Override'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedStatus != null) {
      try {
        final reviewerId = _authService.currentUser?.uid ?? '';
        await _leaveService.overrideLeaveDecision(
          leaveRequestId: leave.id,
          newStatus: selectedStatus!,
          overriddenBy: reviewerId,
          overrideReason: reasonController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Leave decision overridden to ${selectedStatus!.displayName}',
              ),
              backgroundColor: Colors.deepPurple,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Leave Requests'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'All Requests', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingLeaves(),
          _buildAllLeaves(),
        ],
      ),
    );
  }

  Widget _buildPendingLeaves() {
    return StreamBuilder<List<LeaveRequest>>(
      stream: _leaveService.getPendingLeaveRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final leaves = snapshot.data ?? [];

        if (leaves.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No pending leave requests',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            return _buildLeaveCard(leaves[index], showActions: true, showOverride: false);
          },
        );
      },
    );
  }

  Widget _buildAllLeaves() {
    return StreamBuilder<List<LeaveRequest>>(
      stream: _leaveService.getAllLeaveRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final leaves = snapshot.data ?? [];

        if (leaves.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No leave requests',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            return _buildLeaveCard(leaves[index], showActions: false, showOverride: true);
          },
        );
      },
    );
  }

  Widget _buildLeaveCard(LeaveRequest leave, {required bool showActions, required bool showOverride}) {
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
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                  child: Text(
                    leave.employeeName.isNotEmpty
                        ? leave.employeeName[0].toUpperCase()
                        : 'E',
                    style: const TextStyle(
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        leave.employeeEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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

            // Leave Type
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getLeaveTypeColor(leave.leaveType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getLeaveTypeIcon(leave.leaveType),
                    color: _getLeaveTypeColor(leave.leaveType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.leaveType.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${leave.totalDays} ${leave.totalDays == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dates
            _buildInfoRow(
              Icons.calendar_today,
              'Dates',
              '${DateFormat('MMM dd').format(leave.startDate)} - ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
            ),
            const SizedBox(height: 8),

            // Reason
            _buildInfoRow(
              Icons.description,
              'Reason',
              leave.reason,
            ),

            // Review Comment
            if (leave.reviewComment != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'HR Comment:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
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

            // Action Buttons
            if (showActions && leave.status == LeaveStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLeaveAction(leave, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _handleLeaveAction(leave, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Override indicator
            if (leave.isOverridden) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded,
                            size: 16, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Decision Overridden',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                        if (leave.previousStatus != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(was ${leave.previousStatus!.substring(0, 1).toUpperCase()}${leave.previousStatus!.substring(1)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (leave.overrideReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        leave.overrideReason!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.deepPurple.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Override button for already-decided leave requests
            if (showOverride && leave.status != LeaveStatus.pending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleOverride(leave),
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                  label: const Text('Override Decision'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
