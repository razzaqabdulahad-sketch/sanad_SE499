import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/contract.dart';
import '../../services/contract_service.dart';

class ContractDetailScreen extends StatefulWidget {
  final String contractId;

  const ContractDetailScreen({
    super.key,
    required this.contractId,
  });

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  final _contractService = ContractService();
  final _currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  Color _statusColor(ContractStatus status) {
    switch (status) {
      case ContractStatus.draft:
        return Colors.blueGrey;
      case ContractStatus.inReview:
        return Colors.orange;
      case ContractStatus.active:
        return Colors.green;
      case ContractStatus.closed:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(
    LegalContract contract,
    ContractStatus nextStatus,
  ) async {
    if (contract.status == nextStatus) return;

    try {
      await _contractService.updateContractStatus(
        contractId: contract.id,
        status: nextStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${nextStatus.displayName}'),
          backgroundColor: const Color(0xFF00695C),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool stacked,
    IconData? icon,
  }) {
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: icon != null ? 26 : 0),
              child: Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract Details'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<LegalContract?>(
        stream: _contractService.getContractStream(widget.contractId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load contract details. Please try again.',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final contract = snapshot.data;
          if (contract == null) {
            return const Center(
              child: Text('Contract not found.'),
            );
          }

          final statusColor = _statusColor(contract.status);
          final isCompact = MediaQuery.of(context).size.width < 640;

          final statusChip = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              contract.status.displayName,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 12 : 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isCompact) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      contract.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<ContractStatus>(
                                    tooltip: 'Update status',
                                    onSelected: (status) =>
                                        _updateStatus(contract, status),
                                    itemBuilder: (_) => ContractStatus.values
                                        .map(
                                          (status) =>
                                              PopupMenuItem<ContractStatus>(
                                                value: status,
                                                child: Text(status.displayName),
                                              ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                              statusChip,
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      contract.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  statusChip,
                                  PopupMenuButton<ContractStatus>(
                                    tooltip: 'Update status',
                                    onSelected: (status) =>
                                        _updateStatus(contract, status),
                                    itemBuilder: (_) => ContractStatus.values
                                        .map(
                                          (status) =>
                                              PopupMenuItem<ContractStatus>(
                                                value: status,
                                                child: Text(status.displayName),
                                              ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Text(
                              contract.type.displayName,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contract Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildInfoRow(
                              label: 'Counterparty',
                              value: contract.counterparty,
                              icon: Icons.business_center_rounded,
                              stacked: isCompact,
                            ),
                            _buildInfoRow(
                              label: 'Effective Date',
                              value: DateFormat(
                                'MMM d, yyyy',
                              ).format(contract.effectiveDate),
                              icon: Icons.calendar_today_rounded,
                              stacked: isCompact,
                            ),
                            _buildInfoRow(
                              label: 'Value',
                              value: contract.contractValue == null
                                  ? 'Not set'
                                  : _currencyFormatter.format(
                                      contract.contractValue,
                                    ),
                              icon: Icons.payments_rounded,
                              stacked: isCompact,
                            ),
                            _buildInfoRow(
                              label: 'Created By',
                              value: contract.createdByName,
                              icon: Icons.person_rounded,
                              stacked: isCompact,
                            ),
                            _buildInfoRow(
                              label: 'Created At',
                              value: DateFormat(
                                'MMM d, yyyy · h:mm a',
                              ).format(contract.createdAt),
                              icon: Icons.history_rounded,
                              stacked: isCompact,
                            ),
                            _buildInfoRow(
                              label: 'Last Updated',
                              value: DateFormat(
                                'MMM d, yyyy · h:mm a',
                              ).format(contract.updatedAt),
                              icon: Icons.update_rounded,
                              stacked: isCompact,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (contract.description != null &&
                        contract.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                contract.description!,
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}