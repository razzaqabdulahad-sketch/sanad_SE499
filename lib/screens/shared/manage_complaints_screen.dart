import 'package:flutter/material.dart';
import '../../models/complaint.dart';
import '../../services/complaint_service.dart';
import 'manage_complaint_detail_screen.dart';

/// Shared complaint management screen used by both HR and Legal dashboards.
/// Pass the [department] and [primaryColor] to match each role's design.
class ManageComplaintsScreen extends StatefulWidget {
  final ComplaintDepartment department;
  final Color primaryColor;
  final Color accentColor;
  final bool initialAssignedOnly;

  const ManageComplaintsScreen({
    super.key,
    required this.department,
    required this.primaryColor,
    required this.accentColor,
    this.initialAssignedOnly = false,
  });

  @override
  State<ManageComplaintsScreen> createState() => _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState extends State<ManageComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _complaintService = ComplaintService();
  bool _showAssignedOnly = false;

  @override
  void initState() {
    super.initState();
    final initialTabIndex = widget.initialAssignedOnly ? 1 : 0;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTabIndex,
    );
    _showAssignedOnly = widget.initialAssignedOnly;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.department.displayName} Complaints'),
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: _showAssignedOnly
                ? 'Showing assigned only'
                : 'Show assigned to me',
            icon: Icon(
              _showAssignedOnly
                  ? Icons.assignment_ind_rounded
                  : Icons.assignment_turned_in_outlined,
            ),
            onPressed: () {
              setState(() {
                _showAssignedOnly = !_showAssignedOnly;
                if (_showAssignedOnly && _tabController.index == 0) {
                  _tabController.animateTo(1);
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: _showAssignedOnly
            ? _complaintService.getComplaintsAssignedToCurrentUser(
                department: widget.department,
              )
            : _complaintService.getComplaintsByDepartment(widget.department),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to load complaints. Please try again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allComplaints = snapshot.data ?? [];

          // Split into tabs
          final pending = allComplaints
              .where((c) => c.status == ComplaintStatus.submitted)
              .toList();
          final inProgress = allComplaints
              .where(
                (c) =>
                    c.status == ComplaintStatus.underReview ||
                    c.status == ComplaintStatus.inProgress,
              )
              .toList();
          final closed = allComplaints
              .where(
                (c) =>
                    c.status == ComplaintStatus.resolved ||
                    c.status == ComplaintStatus.dismissed,
              )
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildComplaintList(
                context,
                pending,
                _showAssignedOnly
                    ? 'No Assigned Pending Complaints'
                    : 'No Pending Complaints',
                _showAssignedOnly
                  ? 'No pending complaints are assigned to you. Newly assigned cases usually move to In Progress.'
                    : 'All complaints have been reviewed.',
              ),
              _buildComplaintList(
                context,
                inProgress,
                _showAssignedOnly
                    ? 'No Assigned Active Complaints'
                    : 'No Active Complaints',
                _showAssignedOnly
                    ? 'No active complaints are currently assigned to you.'
                    : 'No complaints are currently being worked on.',
              ),
              _buildComplaintList(
                context,
                closed,
                _showAssignedOnly
                    ? 'No Assigned Closed Complaints'
                    : 'No Closed Complaints',
                _showAssignedOnly
                    ? 'You do not have any closed assigned complaints yet.'
                    : 'Resolved or dismissed complaints will appear here.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComplaintList(
    BuildContext context,
    List<Complaint> complaints,
    String emptyTitle,
    String emptySubtitle,
  ) {
    if (complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final complaint = complaints[index];
        return _ManageComplaintCard(
          complaint: complaint,
          primaryColor: widget.primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageComplaintDetailScreen(
                  complaintId: complaint.id,
                  primaryColor: widget.primaryColor,
                  accentColor: widget.accentColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ManageComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ManageComplaintCard({
    required this.complaint,
    required this.primaryColor,
    required this.onTap,
  });

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return const Color(0xFF1A7FA0);
      case ComplaintStatus.underReview:
        return const Color(0xFFE65100);
      case ComplaintStatus.inProgress:
        return const Color(0xFF6A1B9A);
      case ComplaintStatus.resolved:
        return const Color(0xFF2E7D32);
      case ComplaintStatus.dismissed:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return Icons.send_rounded;
      case ComplaintStatus.underReview:
        return Icons.hourglass_top_rounded;
      case ComplaintStatus.inProgress:
        return Icons.autorenew_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      case ComplaintStatus.dismissed:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(complaint.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: anonymous/name + status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: Icon(
                              complaint.isAnonymous
                                  ? Icons.visibility_off_rounded
                                  : Icons.person_rounded,
                              size: 16,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              complaint.isAnonymous
                                  ? 'Anonymous'
                                  : (complaint.employeeName ?? 'Unknown'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(complaint.status),
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            complaint.status.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Subject
                Text(
                  complaint.subject,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Description preview
                Text(
                  complaint.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Footer
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(complaint.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (complaint.attachmentUrls.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.attach_file_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${complaint.attachmentUrls.length} file${complaint.attachmentUrls.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (complaint.assignedToName != null &&
                        complaint.assignedToName!.trim().isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.assignment_ind_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        complaint.assignedToName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (complaint.caseOutcome != null &&
                        complaint.caseOutcome!.trim().isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          complaint.caseOutcome!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
