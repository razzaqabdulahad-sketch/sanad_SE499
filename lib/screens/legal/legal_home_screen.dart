import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/complaint_service.dart';
import '../../models/complaint.dart';
import '../shared/notification_bell_button.dart';
import '../shared/manage_complaints_screen.dart';
import 'contracts_screen.dart';

class LegalHomeScreen extends StatefulWidget {
  const LegalHomeScreen({super.key});

  @override
  State<LegalHomeScreen> createState() => _LegalHomeScreenState();
}

class _LegalHomeScreenState extends State<LegalHomeScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _complaintService = ComplaintService();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _legalComplaintsStream =>
      _firestore
          .collection('complaints')
          .where('department', isEqualTo: ComplaintDepartment.legal.value)
          .snapshots();

  Stream<List<Complaint>> get _assignedToMeStream =>
      _complaintService.getComplaintsAssignedToCurrentUser(
        department: ComplaintDepartment.legal,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> get _recentComplaintsStream =>
      _firestore
          .collection('complaints')
          .where('department', isEqualTo: ComplaintDepartment.legal.value)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: Brightness.light,
      primary: const Color(0xFF00695C),
      secondary: const Color(0xFF00897B),
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal Dashboard'),
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
          actions: [
            const NotificationBellButton(role: UserRole.legal),
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
              // Welcome Card
              Card(
                elevation: 4,
                color: const Color(0xFF00796B),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Icon(
                          Icons.gavel_rounded,
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
                              'Sanad Legal',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            Text(
                              'Compliance & Documentation',
                              style: Theme.of(context).textTheme.bodyMedium
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

              // Stats Overview
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _legalComplaintsStream,
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? const [];
                        final openCases = docs.where((doc) {
                          final status = (doc.data()['status'] ?? '')
                              .toString()
                              .toLowerCase();
                          return status != ComplaintStatus.resolved.value &&
                              status != ComplaintStatus.dismissed.value;
                        }).length;

                        return _buildStatCard(
                          context,
                          snapshot.connectionState == ConnectionState.waiting
                              ? '—'
                              : '$openCases',
                          'Open Legal Cases',
                          Icons.folder_open_rounded,
                          colorScheme.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<List<Complaint>>(
                      stream: _assignedToMeStream,
                      builder: (context, snapshot) {
                        final complaints = snapshot.data ?? const [];
                        final assignedOpen = complaints.where((c) {
                          return c.status != ComplaintStatus.resolved &&
                              c.status != ComplaintStatus.dismissed;
                        }).length;

                        return _buildStatCard(
                          context,
                          snapshot.connectionState == ConnectionState.waiting
                              ? '—'
                              : '$assignedOpen',
                          'Assigned To Me',
                          Icons.assignment_ind_rounded,
                          Colors.amber,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 980
                      ? 4
                      : width >= 680
                      ? 3
                      : 2;
                  final childAspectRatio = width < 420
                      ? 0.9
                      : width < 760
                      ? 0.96
                      : 1.15;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildActionCard(
                        context,
                        'Contracts',
                        Icons.description_rounded,
                        colorScheme.primary,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContractsScreen(),
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
                              builder: (context) => const ManageComplaintsScreen(
                                department: ComplaintDepartment.legal,
                                primaryColor: Color(0xFF00695C),
                                accentColor: Color(0xFF00897B),
                              ),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        context,
                        'Assigned Cases',
                        Icons.assignment_ind_rounded,
                        Colors.amber.shade700,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageComplaintsScreen(
                                department: ComplaintDepartment.legal,
                                primaryColor: Color(0xFF00695C),
                                accentColor: Color(0xFF00897B),
                                initialAssignedOnly: true,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        context,
                        'Compliance',
                        Icons.verified_user_rounded,
                        colorScheme.secondary,
                        () => _openComplianceSnapshot(context),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Recent Cases (same behavior pattern as HR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Cases',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageComplaintsScreen(
                          department: ComplaintDepartment.legal,
                          primaryColor: Color(0xFF00695C),
                          accentColor: Color(0xFF00897B),
                        ),
                      ),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _recentComplaintsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return _buildEmptyState(
                      'No complaints yet',
                      Icons.report_off_rounded,
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final subject = (data['subject'] as String?) ?? 'No subject';
                      final status = ComplaintStatus.fromString(
                        (data['status'] as String?) ?? 'submitted',
                      );
                      final isAnonymous = data['isAnonymous'] == true;
                      final employeeName = isAnonymous
                          ? 'Anonymous'
                          : ((data['employeeName'] as String?) ?? 'Unknown');
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
                                department: ComplaintDepartment.legal,
                                primaryColor: Color(0xFF00695C),
                                accentColor: Color(0xFF00897B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 130 || constraints.maxHeight < 130;
            final iconPadding = compact ? 10.0 : 12.0;
            final iconSize = compact ? 28.0 : 32.0;
            final spacing = compact ? 8.0 : 12.0;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(icon, size: iconSize, color: Colors.white),
                  ),
                  SizedBox(height: spacing),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

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
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
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
                child: const Icon(
                  Icons.report_rounded,
                  color: Color(0xFFC62828),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'By $employeeName',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(createdAt),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  void _openComplianceSnapshot(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _legalComplaintsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final complaints =
                    (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                        .map((doc) => Complaint.fromFirestore(doc))
                        .toList();

                final openCases = complaints.where((complaint) {
                  return complaint.status != ComplaintStatus.resolved &&
                      complaint.status != ComplaintStatus.dismissed;
                }).toList();

                final now = DateTime.now();
                final overdueOpen = openCases.where((complaint) {
                  return now.difference(complaint.createdAt).inDays >= 14;
                }).length;

                final urgentOpen = openCases.where((complaint) {
                  final urgency = complaint.aiUrgency?.toLowerCase();
                  return urgency == 'high' || urgency == 'critical';
                }).length;

                final routingMismatch = openCases.where((complaint) {
                  final recommended = complaint.aiRecommendedDepartment;
                  if (recommended == null || recommended.isEmpty) return false;
                  return recommended != ComplaintDepartment.legal.value;
                }).length;

                final needsAttention = overdueOpen + urgentOpen + routingMismatch;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF00695C),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compliance Snapshot',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  needsAttention == 0
                                      ? 'All clear for now.'
                                      : '$needsAttention items need legal attention.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildComplianceMetricTile(
                        title: 'Open over 14 days',
                        value: overdueOpen,
                        subtitle: 'Aging cases that may create compliance risk.',
                        color: const Color(0xFFEF6C00),
                      ),
                      const SizedBox(height: 10),
                      _buildComplianceMetricTile(
                        title: 'High/Critical urgency open',
                        value: urgentOpen,
                        subtitle: 'Urgent complaints requiring quick review.',
                        color: const Color(0xFFC62828),
                      ),
                      const SizedBox(height: 10),
                      _buildComplianceMetricTile(
                        title: 'Routing mismatches',
                        value: routingMismatch,
                        subtitle: 'AI suggests another department should own these.',
                        color: const Color(0xFF6A1B9A),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ManageComplaintsScreen(
                                  department: ComplaintDepartment.legal,
                                  primaryColor: Color(0xFF00695C),
                                  accentColor: Color(0xFF00897B),
                                  initialAssignedOnly: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.assignment_ind_rounded),
                          label: const Text('Review Assigned Cases'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildComplianceMetricTile({
    required String title,
    required int value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
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
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
