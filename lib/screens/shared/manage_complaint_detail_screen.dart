import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/complaint.dart';
import '../../services/complaint_service.dart';

/// Detail screen for HR/Legal to view and act on a complaint.
class ManageComplaintDetailScreen extends StatefulWidget {
  final String complaintId;
  final Color primaryColor;
  final Color accentColor;

  const ManageComplaintDetailScreen({
    super.key,
    required this.complaintId,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<ManageComplaintDetailScreen> createState() =>
      _ManageComplaintDetailScreenState();
}

class _ManageComplaintDetailScreenState
    extends State<ManageComplaintDetailScreen> {
  final _complaintService = ComplaintService();
  final _noteController = TextEditingController();
  static const List<String> _legalCaseOutcomes = [
    'Resolved with corrective action',
    'Resolved through mediation',
    'Referred for legal action',
    'Policy breach confirmed',
    'No policy/legal breach found',
    'Insufficient evidence',
  ];

  bool _isUpdating = false;
  bool _isClassifying = false;
  bool _isCheckingDepartment = false;
  bool _isEscalating = false;
  bool _isAssessingUrgency = false;
  bool _isSettingPriority = false;
  bool _isOverridingUrgency = false;
  bool _isAssigningCase = false;
  bool _isClearingAssignment = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
    ComplaintStatus newStatus,
    String? note, {
    String? caseOutcome,
    String? caseOutcomeDetails,
  }) async {
    setState(() => _isUpdating = true);
    try {
      await _complaintService.updateComplaintStatus(
        complaintId: widget.complaintId,
        newStatus: newStatus,
        resolutionNote: note,
        caseOutcome: caseOutcome,
        caseOutcomeDetails: caseOutcomeDetails,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    caseOutcome != null && caseOutcome.trim().isNotEmpty
                        ? 'Case closed as ${newStatus.displayName}: $caseOutcome'
                        : 'Status updated to ${newStatus.displayName}',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _assignCaseToMe(Complaint complaint) async {
    setState(() => _isAssigningCase = true);
    try {
      await _complaintService.assignComplaintToCurrentUser(
        complaintId: complaint.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Complaint assigned to you for legal review.'),
            backgroundColor: const Color(0xFF00695C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to assign complaint: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigningCase = false);
    }
  }

  Future<void> _clearCaseAssignment(Complaint complaint) async {
    setState(() => _isClearingAssignment = true);
    try {
      await _complaintService.clearComplaintAssignment(
        complaintId: complaint.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Case assignment cleared.'),
            backgroundColor: Colors.blueGrey.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to clear assignment: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingAssignment = false);
    }
  }

  Future<void> _classifyWithAI(Complaint complaint) async {
    setState(() => _isClassifying = true);
    try {
      await _complaintService.classifyComplaintWithAI(
        complaintId: complaint.id,
        subject: complaint.subject,
        description: complaint.description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('AI classification complete')),
              ],
            ),
            backgroundColor: Colors.teal.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classification failed: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  Future<void> _checkDepartmentRouting(Complaint complaint) async {
    setState(() => _isCheckingDepartment = true);
    try {
      await _complaintService.checkDepartmentRouting(
        complaintId: complaint.id,
        subject: complaint.subject,
        description: complaint.description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.route_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Department check complete')),
              ],
            ),
            backgroundColor: Colors.indigo.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Department check failed: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingDepartment = false);
    }
  }

  Future<void> _escalateToLegal(Complaint complaint) async {
    var targetDepartment = ComplaintDepartment.legal;
    if (complaint.aiRecommendedDepartment != null &&
        complaint.aiRecommendedDepartment!.trim().isNotEmpty) {
      targetDepartment = ComplaintDepartment.fromString(
        complaint.aiRecommendedDepartment!,
      );
    }

    if (targetDepartment == complaint.department) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This complaint is already in the recommended department.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text('Route to ${targetDepartment.displayName}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This complaint will be moved to the recommended department and removed from your current queue.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Subject: ${complaint.subject}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: Text('Route to ${targetDepartment.displayName}'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isEscalating = true);
    try {
      await _complaintService.escalateComplaint(
        complaintId: complaint.id,
        targetDepartment: targetDepartment,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complaint routed to ${targetDepartment.displayName}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.indigo.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Escalation failed: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isEscalating = false);
    }
  }

  void _showUrgencyOverrideSheet(Complaint complaint) {
    final levels = ['Low', 'Medium', 'High', 'Critical'];
    String? selected = complaint.aiUrgency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 20,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Override Urgency',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Override the AI-assigned urgency level',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...levels.map((level) {
                final color = _getUrgencyColor(level);
                final isActive = selected?.toLowerCase() == level.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => setSheet(() => selected = level),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive ? color : Colors.grey.shade200,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getUrgencyIcon(level),
                            color: isActive ? color : Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            level,
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive ? color : Colors.grey.shade700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          if (isActive)
                            Icon(
                              Icons.check_circle_rounded,
                              color: color,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        setState(() => _isOverridingUrgency = true);
                        try {
                          await _complaintService.setUrgencyManually(
                            complaintId: complaint.id,
                            urgency: selected!,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.bolt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Text('Urgency set to $selected'),
                                  ],
                                ),
                                backgroundColor: _getUrgencyColor(selected!),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: \$e'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isOverridingUrgency = false);
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: selected != null
                      ? _getUrgencyColor(selected!)
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Set Urgency to ${selected ?? '…'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assessUrgency(Complaint complaint) async {
    setState(() => _isAssessingUrgency = true);
    try {
      await _complaintService.assessUrgencyWithAI(
        complaintId: complaint.id,
        subject: complaint.subject,
        description: complaint.description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Urgency assessment complete')),
              ],
            ),
            backgroundColor: Colors.deepOrange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Urgency assessment failed: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssessingUrgency = false);
    }
  }

  Future<void> _runFullAIAnalysis(Complaint complaint) async {
    setState(() {
      _isClassifying = true;
      _isCheckingDepartment = true;
      _isAssessingUrgency = true;
    });
    try {
      await Future.wait([
        _complaintService.classifyComplaintWithAI(
          complaintId: complaint.id,
          subject: complaint.subject,
          description: complaint.description,
        ),
        _complaintService.checkDepartmentRouting(
          complaintId: complaint.id,
          subject: complaint.subject,
          description: complaint.description,
        ),
        _complaintService.assessUrgencyWithAI(
          complaintId: complaint.id,
          subject: complaint.subject,
          description: complaint.description,
        ),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('AI analysis complete')),
              ],
            ),
            backgroundColor: Colors.teal.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClassifying = false;
          _isCheckingDepartment = false;
          _isAssessingUrgency = false;
        });
      }
    }
  }

  Future<void> _updatePriority(
    Complaint complaint,
    ComplaintPriority priority,
  ) async {
    setState(() => _isSettingPriority = true);
    try {
      await _complaintService.updateComplaintPriority(
        complaintId: complaint.id,
        priority: priority,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Priority set to ${priority.displayName}'),
                ),
              ],
            ),
            backgroundColor: _getPriorityColor(priority),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set priority: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettingPriority = false);
    }
  }

  Color _getPriorityColor(ComplaintPriority priority) {
    switch (priority) {
      case ComplaintPriority.p0:
        return const Color(0xFF1565C0);
      case ComplaintPriority.p1:
        return const Color(0xFFE65100);
      case ComplaintPriority.p2:
        return const Color(0xFFC62828);
      case ComplaintPriority.none:
        return Colors.grey;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return const Color(0xFFC62828);
      case 'high':
        return const Color(0xFFE65100);
      case 'medium':
        return const Color(0xFFF9A825);
      case 'low':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return Icons.error_rounded;
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      case 'low':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  void _showStatusUpdateDialog(Complaint complaint) {
    ComplaintStatus? selectedStatus;
    String? selectedOutcome;
    final outcomeDetailsController = TextEditingController();
    _noteController.clear();

    bool requiresCaseOutcome(ComplaintStatus? status) {
      return status == ComplaintStatus.resolved ||
          status == ComplaintStatus.dismissed;
    }

    // Determine available next statuses
    final availableStatuses = <ComplaintStatus>[];
    switch (complaint.status) {
      case ComplaintStatus.submitted:
        availableStatuses.addAll([
          ComplaintStatus.underReview,
          ComplaintStatus.dismissed,
        ]);
        break;
      case ComplaintStatus.underReview:
        availableStatuses.addAll([
          ComplaintStatus.inProgress,
          ComplaintStatus.resolved,
          ComplaintStatus.dismissed,
        ]);
        break;
      case ComplaintStatus.inProgress:
        availableStatuses.addAll([
          ComplaintStatus.resolved,
          ComplaintStatus.dismissed,
        ]);
        break;
      case ComplaintStatus.resolved:
      case ComplaintStatus.dismissed:
        // Terminal states — no further action
        break;
    }

    if (availableStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This complaint is already closed.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Update Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select the new status for this complaint',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status options
                  ...availableStatuses.map((status) {
                    final isSelected = selectedStatus == status;
                    final color = _getStatusColor(status);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedStatus = status;
                            if (!requiresCaseOutcome(status)) {
                              selectedOutcome = null;
                              outcomeDetailsController.clear();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                color: isSelected ? color : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                status.displayName,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? color
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: color,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // Note field
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: requiresCaseOutcome(selectedStatus)
                          ? 'Closure note (optional)'
                          : 'Add a note (optional)',
                      hintText: requiresCaseOutcome(selectedStatus)
                          ? 'Optional context for legal closure...'
                          : 'Provide details about this status change...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                    ),
                  ),
                  if (requiresCaseOutcome(selectedStatus)) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOutcome,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Case outcome',
                        hintText: 'Select closure outcome',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                      ),
                      items: _legalCaseOutcomes
                          .map(
                            (outcome) => DropdownMenuItem<String>(
                              value: outcome,
                              child: Text(
                                outcome,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => selectedOutcome = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: outcomeDetailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Outcome details (optional)',
                        hintText:
                            'Record legal rationale, action taken, or next steps...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Action button
                  FilledButton(
                    onPressed:
                        selectedStatus == null ||
                            _isUpdating ||
                            (requiresCaseOutcome(selectedStatus) &&
                                (selectedOutcome == null ||
                                    selectedOutcome!.trim().isEmpty))
                        ? null
                        : () {
                            Navigator.pop(context);
                            _updateStatus(
                              selectedStatus!,
                              _noteController.text.trim().isNotEmpty
                                  ? _noteController.text.trim()
                                  : null,
                              caseOutcome: requiresCaseOutcome(selectedStatus)
                                  ? selectedOutcome
                                  : null,
                              caseOutcomeDetails:
                                  requiresCaseOutcome(selectedStatus) &&
                                      outcomeDetailsController.text
                                          .trim()
                                          .isNotEmpty
                                  ? outcomeDetailsController.text.trim()
                                  : null,
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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

  Widget _buildLegalCaseAssignmentCard(
    BuildContext context,
    Complaint complaint, {
    required bool isClosed,
  }) {
    final isAssigned =
        complaint.assignedToUserId != null &&
        complaint.assignedToUserId!.trim().isNotEmpty;
    final isAssignedToMe =
        isAssigned &&
        complaint.assignedToUserId == _complaintService.currentUserId;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_ind_rounded,
                  size: 18,
                  color: widget.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Legal Case Assignment',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isAssigned
                  ? 'Assigned to ${complaint.assignedToName ?? 'Unknown reviewer'}'
                  : 'This case has not been assigned yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (complaint.assignedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Assigned on ${_formatDate(complaint.assignedAt!)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isClosed || _isAssigningCase || isAssignedToMe
                        ? null
                        : () => _assignCaseToMe(complaint),
                    icon: _isAssigningCase
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isAssigned
                                ? Icons.swap_horiz_rounded
                                : Icons.person_add_alt_1_rounded,
                            size: 16,
                          ),
                    label: Text(
                      isAssignedToMe
                          ? 'Assigned to you'
                          : isAssigned
                          ? 'Take ownership'
                          : 'Assign to me',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (isAssigned && !isClosed) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _isClearingAssignment
                        ? null
                        : () => _clearCaseAssignment(complaint),
                    icon: _isClearingAssignment
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseOutcomeCard(BuildContext context, Complaint complaint) {
    return Card(
      elevation: 1,
      color: const Color(0xFF2E7D32).withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF2E7D32).withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.gavel_rounded,
                  size: 18,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Text(
                  'Case Outcome',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                if (complaint.closedAt != null)
                  Text(
                    _formatDate(complaint.closedAt!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              complaint.caseOutcome ?? 'Outcome recorded',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (complaint.caseOutcomeDetails != null &&
                complaint.caseOutcomeDetails!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                complaint.caseOutcomeDetails!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<Complaint?>(
        stream: _complaintService.getComplaintStream(widget.complaintId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final complaint = snapshot.data;
          if (complaint == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Complaint not found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          final isClosed =
              complaint.status == ComplaintStatus.resolved ||
              complaint.status == ComplaintStatus.dismissed;
          final isLegalCase = complaint.department == ComplaintDepartment.legal;
          final hasCaseOutcome =
              complaint.caseOutcome != null &&
              complaint.caseOutcome!.trim().isNotEmpty;
          final statusColor = _getStatusColor(complaint.status);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(complaint.status),
                              color: statusColor,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    complaint.status.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: statusColor,
                                    ),
                                  ),
                                  Text(
                                    'Last updated: ${_formatDate(complaint.updatedAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: statusColor.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (isLegalCase) ...[
                        _buildLegalCaseAssignmentCard(
                          context,
                          complaint,
                          isClosed: isClosed,
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (hasCaseOutcome) ...[
                        _buildCaseOutcomeCard(context, complaint),
                        const SizedBox(height: 12),
                      ],

                      // AI Insights (compact)
                      _buildAIInsightsCard(context, complaint),
                      const SizedBox(height: 12),

                      // Priority (compact)
                      _buildCompactPriorityCard(context, complaint),
                      const SizedBox(height: 16),

                      // Complainant info
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: widget.primaryColor
                                        .withOpacity(0.1),
                                    child: Icon(
                                      complaint.isAnonymous
                                          ? Icons.visibility_off_rounded
                                          : Icons.person_rounded,
                                      color: widget.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          complaint.isAnonymous
                                              ? 'Anonymous Employee'
                                              : (complaint.employeeName ??
                                                    'Unknown Employee'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          complaint.isAnonymous
                                              ? 'Identity hidden by the employee'
                                              : 'Filed with name',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Filed: ${_formatDate(complaint.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Complaint content
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subject',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: widget.primaryColor,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                complaint.subject,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                'Description',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: widget.primaryColor,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                complaint.description,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      height: 1.6,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attachments
                      if (complaint.attachmentUrls.isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_file_rounded,
                                      size: 20,
                                      color: widget.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Evidence (${complaint.attachmentUrls.length})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: widget.primaryColor,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...complaint.attachmentUrls.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final url = entry.value;
                                  final name =
                                      complaint.attachmentNames.length > index
                                      ? complaint.attachmentNames[index]
                                      : 'Attachment ${index + 1}';
                                  final isImage =
                                      name.toLowerCase().endsWith('.png') ||
                                      name.toLowerCase().endsWith('.jpg') ||
                                      name.toLowerCase().endsWith('.jpeg');

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: InkWell(
                                      onTap: () => _openAttachment(url, name),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: widget
                                                  .primaryColor
                                                  .withOpacity(0.1),
                                              child: Icon(
                                                isImage
                                                    ? Icons.image_rounded
                                                    : Icons.description_rounded,
                                                size: 18,
                                                color: widget.primaryColor,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              url.startsWith('data:')
                                                  ? Icons.visibility_rounded
                                                  : Icons.open_in_new_rounded,
                                              size: 18,
                                              color: widget.primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Resolution note (if exists)
                      if (complaint.resolutionNote != null &&
                          complaint.resolutionNote!.isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          color: complaint.status == ComplaintStatus.resolved
                              ? const Color(0xFF2E7D32).withOpacity(0.05)
                              : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color:
                                  complaint.status == ComplaintStatus.resolved
                                  ? const Color(0xFF2E7D32).withOpacity(0.2)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      complaint.status ==
                                              ComplaintStatus.resolved
                                          ? Icons.check_circle_rounded
                                          : Icons.info_rounded,
                                      size: 20,
                                      color:
                                          complaint.status ==
                                              ComplaintStatus.resolved
                                          ? const Color(0xFF2E7D32)
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Resolution Note',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                complaint.status ==
                                                    ComplaintStatus.resolved
                                                ? const Color(0xFF2E7D32)
                                                : Colors.grey.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  complaint.resolutionNote!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                                ),
                                if (complaint.resolvedBy != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '— ${complaint.resolvedBy}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Status History Timeline
                      if (complaint.statusHistory.isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 20,
                                      color: widget.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Status History',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: widget.primaryColor,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...complaint.statusHistory.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final update = entry.value;
                                  final isLast =
                                      index ==
                                      complaint.statusHistory.length - 1;
                                  final color = _getStatusColor(update.status);

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Timeline line + dot
                                      Column(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          if (!isLast)
                                            Container(
                                              width: 2,
                                              height: 50,
                                              color: Colors.grey.shade300,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: isLast ? 0 : 16,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                update.status.displayName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: color,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${_formatDate(update.timestamp)}${update.updatedBy != null ? ' • ${update.updatedBy}' : ''}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              if (update.note != null &&
                                                  update.note!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    update.note!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom action bar
              if (!isClosed)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: FilledButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () => _showStatusUpdateDialog(complaint),
                      icon: const Icon(Icons.update_rounded),
                      label: const Text(
                        'Update Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── AI Analysis Card ─────────────────────────────────────────────────

  Widget _buildAIInsightsCard(BuildContext context, Complaint complaint) {
    final hasCategory =
        complaint.aiCategory != null && complaint.aiCategory!.isNotEmpty;
    final hasUrgency =
        complaint.aiUrgency != null && complaint.aiUrgency!.isNotEmpty;
    final hasDeptCheck =
        complaint.aiRecommendedDepartment != null &&
        complaint.aiRecommendedDepartment!.isNotEmpty;
    final hasAnyResult = hasCategory || hasUrgency || hasDeptCheck;
    final isRunning =
        _isClassifying || _isCheckingDepartment || _isAssessingUrgency;

    final recommended = hasDeptCheck
        ? ComplaintDepartment.fromString(complaint.aiRecommendedDepartment!)
        : null;
    final isMisrouted = hasDeptCheck && recommended != complaint.department;

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      'Automated complaint intelligence',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (hasAnyResult)
                  TextButton.icon(
                    onPressed: isRunning
                        ? null
                        : () => _runFullAIAnalysis(complaint),
                    icon: isRunning
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal.shade400,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: Colors.teal.shade600,
                          ),
                    label: Text(
                      isRunning ? 'Running…' : 'Re-run',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),

            if (hasAnyResult) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // ── Category Row ──────────────────────────────────────
              _buildAIRow(
                isLoading: _isClassifying,
                icon: Icons.label_rounded,
                iconColor: hasCategory
                    ? _getCategoryColor(complaint.aiCategory!)
                    : Colors.grey.shade400,
                title: 'AI Category ',
                subtitle: hasCategory
                    ? _cleanSummaryText(complaint.aiSummary ?? '')
                    : null,
                trailing: hasCategory
                    ? _buildValuePill(
                        label: complaint.aiCategory!,
                        color: _getCategoryColor(complaint.aiCategory!),
                      )
                    : _buildPendingPill(),
              ),

              const SizedBox(height: 12),

              // ── Urgency Row ───────────────────────────────────────
              _buildAIRow(
                isLoading: _isAssessingUrgency || _isOverridingUrgency,
                icon: _getUrgencyIcon(
                  hasUrgency ? complaint.aiUrgency! : 'low',
                ),
                iconColor: hasUrgency
                    ? _getUrgencyColor(complaint.aiUrgency!)
                    : Colors.grey.shade400,
                title: 'AI Urgency',
                subtitle: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasUrgency)
                      _buildValuePill(
                        label: complaint.aiUrgency!,
                        color: _getUrgencyColor(complaint.aiUrgency!),
                      )
                    else
                      _buildPendingPill(),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: (_isAssessingUrgency || _isOverridingUrgency)
                          ? null
                          : () => _showUrgencyOverrideSheet(complaint),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Urgency level bar
              if (hasUrgency) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Row(
                    children: ['Low', 'Medium', 'High', 'Critical'].map((
                      level,
                    ) {
                      final levels = ['low', 'medium', 'high', 'critical'];
                      final idx = levels.indexOf(level.toLowerCase());
                      final activeIdx = levels.indexOf(
                        complaint.aiUrgency!.toLowerCase(),
                      );
                      final isActive = idx <= activeIdx;
                      final segColor = _getUrgencyColor(level);
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? segColor
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              level,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isActive && idx == activeIdx
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive && idx == activeIdx
                                    ? segColor
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Department Routing Row ────────────────────────────
              _buildAIRow(
                isLoading: _isCheckingDepartment,
                icon: Icons.alt_route_rounded,
                iconColor: hasDeptCheck
                    ? (isMisrouted
                          ? Colors.orange.shade600
                          : Colors.green.shade600)
                    : Colors.grey.shade400,
                title: 'AI Department Routing',
                subtitle: hasDeptCheck
                    ? (isMisrouted
                          ? 'This complaint may belong to ${recommended!.displayName}'
                          : 'Correctly routed to ${complaint.department.displayName}')
                    : null,
                trailing: hasDeptCheck
                    ? _buildValuePill(
                        label: isMisrouted
                            ? complaint.department.displayName
                            : complaint.department.displayName,
                        color: isMisrouted
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                        strikethrough: isMisrouted,
                      )
                    : _buildPendingPill(),
              ),

              // Misrouted escalation banner
              if (isMisrouted) ...[
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.only(left: 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade50,
                        Colors.deepOrange.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Escalate to ${recommended!.displayName}?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            Text(
                              'AI recommends ${recommended.displayName} for this complaint.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _isEscalating
                            ? null
                            : () => _escalateToLegal(complaint),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isEscalating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Escalate'),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // ── Empty state ───────────────────────────────────────
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAIServiceTile(
                      icon: Icons.label_rounded,
                      color: Colors.purple.shade400,
                      title: 'Category',
                      desc: 'Classify type',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAIServiceTile(
                      icon: Icons.bolt_rounded,
                      color: Colors.orange.shade400,
                      title: 'Urgency',
                      desc: 'Set priority',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAIServiceTile(
                      icon: Icons.alt_route_rounded,
                      color: Colors.indigo.shade400,
                      title: 'Routing',
                      desc: 'Dept. check',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isRunning
                      ? null
                      : () => _runFullAIAnalysis(complaint),
                  icon: isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(isRunning ? 'Analyzing…' : 'Run AI Analysis'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A single labeled AI insight row with icon, title, optional subtitle, and trailing widget.
  Widget _buildAIRow({
    required bool isLoading,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              : Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        trailing,
      ],
    );
  }

  Widget _buildValuePill({
    required String label,
    required Color color,
    bool strikethrough = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget _buildPendingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        'Pending',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildAIServiceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            desc,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _cleanSummaryText(String text) {
    final trimmed = text.trim();
    final stripped = trimmed
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '')
        .trim();
    final looksLikeJson =
        stripped.startsWith('{') ||
        stripped.contains('"category"') ||
        stripped.contains('"urgency"') ||
        stripped.contains('"summary"');
    if (looksLikeJson) {
      try {
        final jsonStart = stripped.indexOf('{');
        final jsonEnd = stripped.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          final json =
              jsonDecode(stripped.substring(jsonStart, jsonEnd + 1))
                  as Map<String, dynamic>;
          return (json['summary'] as String?)?.trim() ?? '';
        }
      } catch (_) {}
      return '';
    }
    return stripped;
  }

  // ── Compact Priority Card ─────────────────────────────────────────────

  Widget _buildCompactPriorityCard(BuildContext context, Complaint complaint) {
    final hasPriority = complaint.priority != ComplaintPriority.none;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: Colors.blueGrey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Priority',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
                if (hasPriority) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(
                        complaint.priority,
                      ).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      complaint.priority.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(complaint.priority),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (hasPriority)
                  InkWell(
                    onTap: _isSettingPriority
                        ? null
                        : () => _updatePriority(
                            complaint,
                            ComplaintPriority.none,
                          ),
                    child: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCompactPriorityBtn(
                  complaint,
                  ComplaintPriority.p0,
                  'P0',
                  'Low',
                  const Color(0xFF1565C0),
                ),
                const SizedBox(width: 8),
                _buildCompactPriorityBtn(
                  complaint,
                  ComplaintPriority.p1,
                  'P1',
                  'Medium',
                  const Color(0xFFE65100),
                ),
                const SizedBox(width: 8),
                _buildCompactPriorityBtn(
                  complaint,
                  ComplaintPriority.p2,
                  'P2',
                  'Critical',
                  const Color(0xFFC62828),
                ),
              ],
            ),
            if (hasPriority && complaint.prioritySetBy != null) ...[
              const SizedBox(height: 8),
              Text(
                'Set by ${complaint.prioritySetBy}${complaint.prioritySetAt != null ? ' \u2022 ${_formatDate(complaint.prioritySetAt!)}' : ''}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPriorityBtn(
    Complaint complaint,
    ComplaintPriority priority,
    String label,
    String desc,
    Color color,
  ) {
    final isActive = complaint.priority == priority;
    return Expanded(
      child: InkWell(
        onTap: _isSettingPriority
            ? null
            : () => _updatePriority(complaint, priority),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.12) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : Colors.grey.shade200,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              if (_isSettingPriority)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isActive ? color : Colors.grey.shade400,
                  ),
                ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Legacy methods (not referenced in layout) ─────────────────────────

  Widget _buildAIClassificationCard(BuildContext context, Complaint complaint) {
    final hasClassification =
        complaint.aiCategory != null && complaint.aiCategory!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: hasClassification
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal.shade50, Colors.cyan.shade50],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Classification',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                  if (hasClassification)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(
                          complaint.aiCategory!,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getCategoryColor(
                            complaint.aiCategory!,
                          ).withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        complaint.aiCategory!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getCategoryColor(complaint.aiCategory!),
                        ),
                      ),
                    ),
                ],
              ),
              if (hasClassification) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Summary',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        complaint.aiSummary ?? 'No summary available.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isClassifying
                        ? null
                        : () => _classifyWithAI(complaint),
                    icon: _isClassifying
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal.shade400,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: Colors.teal.shade600,
                          ),
                    label: Text(
                      'Re-classify',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'Use Gemini AI to automatically classify this complaint and get a prioritized summary.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isClassifying
                        ? null
                        : () => _classifyWithAI(complaint),
                    icon: _isClassifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      _isClassifying ? 'Classifying...' : 'Classify with AI',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIUrgencyCard(BuildContext context, Complaint complaint) {
    final hasUrgency =
        complaint.aiUrgency != null && complaint.aiUrgency!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: hasUrgency
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getUrgencyColor(complaint.aiUrgency!).withOpacity(0.08),
                    Colors.orange.shade50,
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.speed_rounded,
                      size: 20,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Urgency Assessment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade800,
                      ),
                    ),
                  ),
                  if (hasUrgency)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(
                          complaint.aiUrgency!,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getUrgencyColor(
                            complaint.aiUrgency!,
                          ).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getUrgencyIcon(complaint.aiUrgency!),
                            size: 14,
                            color: _getUrgencyColor(complaint.aiUrgency!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            complaint.aiUrgency!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getUrgencyColor(complaint.aiUrgency!),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (hasUrgency) ...[
                const SizedBox(height: 14),
                // Urgency bar visualization
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ...['Low', 'Medium', 'High', 'Critical'].map((level) {
                            final isActive =
                                complaint.aiUrgency!.toLowerCase() ==
                                level.toLowerCase();
                            final color = _getUrgencyColor(level);
                            return Expanded(
                              child: Container(
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? color
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isAssessingUrgency
                        ? null
                        : () => _assessUrgency(complaint),
                    icon: _isAssessingUrgency
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.deepOrange.shade400,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: Colors.deepOrange.shade600,
                          ),
                    label: Text(
                      'Re-assess',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepOrange.shade600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'Use Gemini AI to assess how urgent this complaint is so high-severity cases can be prioritized.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAssessingUrgency
                        ? null
                        : () => _assessUrgency(complaint),
                    icon: _isAssessingUrgency
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.speed_rounded, size: 18),
                    label: Text(
                      _isAssessingUrgency
                          ? 'Assessing...'
                          : 'Assess Urgency with AI',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityAssignmentCard(
    BuildContext context,
    Complaint complaint,
  ) {
    final hasPriority = complaint.priority != ComplaintPriority.none;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: hasPriority
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getPriorityColor(complaint.priority).withOpacity(0.06),
                    Colors.blueGrey.shade50,
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.flag_rounded,
                      size: 20,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Priority Assignment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  if (hasPriority)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(
                          complaint.priority,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getPriorityColor(
                            complaint.priority,
                          ).withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        complaint.priority.shortLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _getPriorityColor(complaint.priority),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (hasPriority) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Priority',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: _getPriorityColor(complaint.priority),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            complaint.priority.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _getPriorityColor(complaint.priority),
                            ),
                          ),
                        ],
                      ),
                      if (complaint.prioritySetBy != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Set by ${complaint.prioritySetBy}${complaint.prioritySetAt != null ? ' on ${_formatDate(complaint.prioritySetAt!)}' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                hasPriority
                    ? 'Update priority level:'
                    : 'Assign a corporate priority level to this complaint:',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPriorityButton(
                    complaint: complaint,
                    priority: ComplaintPriority.p0,
                    label: 'P0',
                    description: 'Low',
                    color: const Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 10),
                  _buildPriorityButton(
                    complaint: complaint,
                    priority: ComplaintPriority.p1,
                    label: 'P1',
                    description: 'Medium',
                    color: const Color(0xFFE65100),
                  ),
                  const SizedBox(width: 10),
                  _buildPriorityButton(
                    complaint: complaint,
                    priority: ComplaintPriority.p2,
                    label: 'P2',
                    description: 'Critical',
                    color: const Color(0xFFC62828),
                  ),
                ],
              ),
              if (hasPriority) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSettingPriority
                        ? null
                        : () => _updatePriority(
                            complaint,
                            ComplaintPriority.none,
                          ),
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    label: Text(
                      'Clear Priority',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityButton({
    required Complaint complaint,
    required ComplaintPriority priority,
    required String label,
    required String description,
    required Color color,
  }) {
    final isActive = complaint.priority == priority;

    return Expanded(
      child: InkWell(
        onTap: _isSettingPriority
            ? null
            : () => _updatePriority(complaint, priority),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.12) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.grey.shade200,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              if (_isSettingPriority)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isActive ? color : Colors.grey.shade500,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'harassment':
        return const Color(0xFFC62828);
      case 'discrimination':
        return const Color(0xFFAD1457);
      case 'pay dispute':
        return const Color(0xFFE65100);
      case 'workplace safety':
        return const Color(0xFF2E7D32);
      case 'policy violation':
        return const Color(0xFF4527A0);
      case 'performance issue':
        return const Color(0xFF1565C0);
      case 'benefits':
        return const Color(0xFF00838F);
      case 'misconduct':
        return const Color(0xFF6A1B9A);
      case 'retaliation':
        return const Color(0xFF424242);
      default:
        return const Color(0xFF455A64);
    }
  }

  Widget _buildDepartmentRoutingCard(
    BuildContext context,
    Complaint complaint,
  ) {
    final hasCheck =
        complaint.aiRecommendedDepartment != null &&
        complaint.aiRecommendedDepartment!.isNotEmpty;
    final recommended = hasCheck
        ? ComplaintDepartment.fromString(complaint.aiRecommendedDepartment!)
        : null;
    final isMisrouted = hasCheck && recommended != complaint.department;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: hasCheck
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isMisrouted
                      ? [Colors.orange.shade50, Colors.red.shade50]
                      : [Colors.green.shade50, Colors.teal.shade50],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      size: 20,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Department Routing',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                  if (hasCheck)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isMisrouted
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isMisrouted
                              ? Colors.orange.shade300
                              : Colors.green.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMisrouted
                                ? Icons.swap_horiz_rounded
                                : Icons.check_circle_rounded,
                            size: 14,
                            color: isMisrouted
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMisrouted ? 'Misrouted' : 'Correct',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMisrouted
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (hasCheck) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Current: ${complaint.department.displayName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Colors.indigo.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Recommends: ${recommended!.displayName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isMisrouted
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isMisrouted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI suggests this complaint belongs to ${recommended.displayName}. You can escalate it below.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isEscalating
                          ? null
                          : () => _escalateToLegal(complaint),
                      icon: _isEscalating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.gavel_rounded, size: 18),
                      label: Text(
                        _isEscalating
                            ? 'Escalating...'
                            : 'Escalate to ${recommended.displayName}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This complaint is correctly routed to ${complaint.department.displayName}.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isCheckingDepartment
                        ? null
                        : () => _checkDepartmentRouting(complaint),
                    icon: _isCheckingDepartment
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.indigo.shade400,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: Colors.indigo.shade600,
                          ),
                    label: Text(
                      'Re-check',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'Verify with AI whether this complaint is routed to the correct department.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCheckingDepartment
                        ? null
                        : () => _checkDepartmentRouting(complaint),
                    icon: _isCheckingDepartment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route_rounded, size: 18),
                    label: Text(
                      _isCheckingDepartment
                          ? 'Checking...'
                          : 'Verify Department Routing',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openAttachment(String value, String fileName) async {
    if (value.startsWith('data:')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid embedded attachment data.')),
          );
        }
        return;
      }

      final header = value.substring(0, commaIndex);
      final payload = value.substring(commaIndex + 1);
      final mimeType = header.split(';').first.replaceFirst('data:', '');

      if (mimeType.startsWith('image/')) {
        try {
          final imageBytes = base64Decode(payload);
          if (!mounted) return;

          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 4,
                      child: Image.memory(imageBytes, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to decode image attachment.'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Preview for this embedded file type is not supported yet.',
              ),
            ),
          );
        }
      }
      return;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid attachment URL.')),
        );
      }
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this attachment.')),
      );
    }
  }
}
