import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/complaint.dart';
import '../../services/complaint_service.dart';
import '../shared/chat_fab.dart';

class ComplaintDetailScreen extends StatelessWidget {
  final String complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  Widget build(BuildContext context) {
    final complaintService = ComplaintService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<Complaint?>(
        stream: complaintService.getComplaintStream(complaintId),
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
                  Icon(Icons.error_outline_rounded,
                      size: 64, color: Colors.grey.shade300),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status tracker
                _StatusTracker(currentStatus: complaint.status),
                const SizedBox(height: 24),

                // Complaint info card
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
                        // Department & anonymous badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D3B66).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    complaint.department ==
                                            ComplaintDepartment.hr
                                        ? Icons.people_rounded
                                        : Icons.gavel_rounded,
                                    size: 16,
                                    color: const Color(0xFF0D3B66),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    complaint.department.displayName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0D3B66),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (complaint.isAnonymous) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_off_rounded,
                                        size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Anonymous',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Subject
                        Text(
                          complaint.subject,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),

                        // Dates
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              'Filed: ${_formatDate(complaint.createdAt)}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        if (complaint.updatedAt != complaint.createdAt) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.update_rounded,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                'Updated: ${_formatDate(complaint.updatedAt)}',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          'Description',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D3B66),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          complaint.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                height: 1.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
                              const Icon(Icons.attach_file_rounded,
                                  size: 20, color: Color(0xFF0D3B66)),
                              const SizedBox(width: 8),
                              Text(
                                'Attachments (${complaint.attachmentUrls.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0D3B66),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...complaint.attachmentUrls
                              .asMap()
                              .entries
                              .map((entry) {
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
                                onTap: () => _openAttachment(context, url, name),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFF0D3B66)
                                            .withOpacity(0.1),
                                        child: Icon(
                                          isImage
                                              ? Icons.image_rounded
                                              : Icons.description_rounded,
                                          size: 18,
                                          color: const Color(0xFF0D3B66),
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
                                        color: const Color(0xFF0D3B66),
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

                // Resolution note
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
                        color: complaint.status == ComplaintStatus.resolved
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
                                complaint.status == ComplaintStatus.resolved
                                    ? Icons.check_circle_rounded
                                    : Icons.info_rounded,
                                size: 20,
                                color:
                                    complaint.status == ComplaintStatus.resolved
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
                                      color: complaint.status ==
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
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                    ),
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
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: const ChatFab(),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openAttachment(
    BuildContext context,
    String value,
    String fileName,
  ) async {
    if (value.startsWith('data:')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex <= 0) {
        if (context.mounted) {
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
          if (!context.mounted) return;

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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
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
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to decode image attachment.')),
            );
          }
        }
      } else {
        if (context.mounted) {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid attachment URL.')),
        );
      }
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this attachment.')),
      );
    }
  }
}

/// Visual progress tracker showing complaint status steps
class _StatusTracker extends StatelessWidget {
  final ComplaintStatus currentStatus;

  const _StatusTracker({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    // Define the ordered steps (dismissed is a terminal state, handled separately)
    final steps = [
      ComplaintStatus.submitted,
      ComplaintStatus.underReview,
      ComplaintStatus.inProgress,
      ComplaintStatus.resolved,
    ];

    final isDismissed = currentStatus == ComplaintStatus.dismissed;
    final currentIndex = isDismissed
        ? -1
        : steps.indexOf(currentStatus);

    return Card(
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
                  isDismissed ? Icons.cancel_rounded : Icons.timeline_rounded,
                  size: 20,
                  color: isDismissed ? Colors.grey : const Color(0xFF0D3B66),
                ),
                const SizedBox(width: 8),
                Text(
                  'Complaint Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D3B66),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isDismissed)
              _buildDismissedView(context)
            else
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isActive = index <= currentIndex;
                final isCurrent = index == currentIndex;
                final isLast = index == steps.length - 1;

                return _buildStep(
                  context,
                  step: step,
                  isActive: isActive,
                  isCurrent: isCurrent,
                  isLast: isLast,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissedView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel_rounded, color: Colors.grey.shade600, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complaint Dismissed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This complaint has been reviewed and dismissed.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required ComplaintStatus step,
    required bool isActive,
    required bool isCurrent,
    required bool isLast,
  }) {
    final color = isActive ? const Color(0xFF0D3B66) : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? color : Colors.transparent,
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: isActive
                      ? const Color(0xFF0D3B66).withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Step info
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.displayName,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    fontSize: isCurrent ? 15 : 14,
                    color: isActive
                        ? const Color(0xFF0D3B66)
                        : Colors.grey.shade500,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Current Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1A7FA0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
