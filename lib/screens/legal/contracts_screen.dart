import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/contract.dart';
import '../../services/contract_service.dart';
import 'contract_detail_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen>
    with SingleTickerProviderStateMixin {
  static const _primaryColor = Color(0xFF00695C);

  final _contractService = ContractService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _currencyFormatter = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 0,
  );

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _counterpartyController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showCreateContractDialog() async {
    _formKey.currentState?.reset();
    _titleController.clear();
    _counterpartyController.clear();
    _valueController.clear();
    _descriptionController.clear();

    ContractType selectedType = ContractType.serviceAgreement;
    DateTime selectedEffectiveDate = DateTime.now();
    bool isSubmitting = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth < 560 ? screenWidth * 0.86 : 460.0;

            return AlertDialog(
              title: const Text('Create Contract'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              content: SizedBox(
                width: dialogWidth,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Contract Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Contract title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _counterpartyController,
                          decoration: const InputDecoration(
                            labelText: 'Counterparty',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Counterparty is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ContractType>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Contract Type',
                            border: OutlineInputBorder(),
                          ),
                          items: ContractType.values
                              .map(
                                (type) => DropdownMenuItem<ContractType>(
                                  value: type,
                                  child: Text(type.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedType = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _valueController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Contract Value (Optional)',
                            hintText: 'e.g. 25000',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            if (double.tryParse(text) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedEffectiveDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (pickedDate != null) {
                              setDialogState(
                                () => selectedEffectiveDate = pickedDate,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Effective Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy',
                                  ).format(selectedEffectiveDate),
                                ),
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;

                          final valueText = _valueController.text.trim();
                          final contractValue =
                              valueText.isEmpty ? null : double.tryParse(valueText);

                          setDialogState(() => isSubmitting = true);
                          try {
                            await _contractService.createContract(
                              title: _titleController.text,
                              counterparty: _counterpartyController.text,
                              type: selectedType,
                              effectiveDate: selectedEffectiveDate,
                              description: _descriptionController.text,
                              contractValue: contractValue,
                            );

                            if (mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create contract: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(isSubmitting ? 'Creating...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract created successfully'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  Future<void> _updateStatus(LegalContract contract, ContractStatus status) async {
    if (contract.status == status) return;

    try {
      await _contractService.updateContractStatus(
        contractId: contract.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${status.displayName}'),
          backgroundColor: _primaryColor,
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

  Widget _buildWorkspaceHeader({
    required bool isCompact,
    required double horizontalPadding,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 14),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contract Workspace',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Create and track legal contracts in one place.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showCreateContractDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New Contract'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contract Workspace',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Create and track legal contracts in one place.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showCreateContractDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildContractsList(
    List<LegalContract> contracts, {
    required String emptyTitle,
    required String emptySubtitle,
    required bool isCompact,
    required double horizontalPadding,
  }) {
    if (contracts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.note_add_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _showCreateContractDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Contract'),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: !isCompact,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 20),
        itemCount: contracts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final contract = contracts[index];
          final statusColor = _statusColor(contract.status);

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
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          );

          return Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContractDetailScreen(contractId: contract.id),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCompact) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contract.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<ContractStatus>(
                            tooltip: 'Update status',
                            onSelected: (status) => _updateStatus(contract, status),
                            itemBuilder: (context) => ContractStatus.values
                                .map(
                                  (status) => PopupMenuItem<ContractStatus>(
                                    value: status,
                                    child: Text(status.displayName),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      statusChip,
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contract.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          statusChip,
                          PopupMenuButton<ContractStatus>(
                            tooltip: 'Update status',
                            onSelected: (status) => _updateStatus(contract, status),
                            itemBuilder: (context) => ContractStatus.values
                                .map(
                                  (status) => PopupMenuItem<ContractStatus>(
                                    value: status,
                                    child: Text(status.displayName),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${contract.type.displayName} · ${contract.counterparty}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Effective: ${DateFormat('MMM d, yyyy').format(contract.effectiveDate)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          contract.contractValue == null
                              ? 'Value: Not set'
                              : 'Value: ${_currencyFormatter.format(contract.contractValue)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'By ${contract.createdByName}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (contract.description != null &&
                        contract.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        contract.description!,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
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
            Tab(text: 'Draft'),
            Tab(text: 'In Review'),
            Tab(text: 'Active'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final horizontalPadding = isCompact ? 12.0 : 20.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                children: [
                  _buildWorkspaceHeader(
                    isCompact: isCompact,
                    horizontalPadding: horizontalPadding,
                  ),
                  Expanded(
                    child: StreamBuilder<List<LegalContract>>(
                      stream: _contractService.getContractsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Failed to load contracts. Please try again.',
                                style: TextStyle(color: Colors.red.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final contracts = snapshot.data ?? const <LegalContract>[];
                        final draftContracts = contracts
                            .where((contract) => contract.status == ContractStatus.draft)
                            .toList();
                        final inReviewContracts = contracts
                            .where(
                              (contract) =>
                                  contract.status == ContractStatus.inReview,
                            )
                            .toList();
                        final activeContracts = contracts
                            .where((contract) => contract.status == ContractStatus.active)
                            .toList();
                        final closedContracts = contracts
                            .where((contract) => contract.status == ContractStatus.closed)
                            .toList();

                        return Column(
                          children: [
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildContractsList(
                                    draftContracts,
                                    emptyTitle: 'No draft contracts',
                                    emptySubtitle:
                                        'Create a contract to start your drafting workflow.',
                                    isCompact: isCompact,
                                    horizontalPadding: horizontalPadding,
                                  ),
                                  _buildContractsList(
                                    inReviewContracts,
                                    emptyTitle: 'No contracts in review',
                                    emptySubtitle:
                                        'Move a draft to In Review when legal review starts.',
                                    isCompact: isCompact,
                                    horizontalPadding: horizontalPadding,
                                  ),
                                  _buildContractsList(
                                    activeContracts,
                                    emptyTitle: 'No active contracts',
                                    emptySubtitle:
                                        'Approved active contracts will appear here.',
                                    isCompact: isCompact,
                                    horizontalPadding: horizontalPadding,
                                  ),
                                  _buildContractsList(
                                    closedContracts,
                                    emptyTitle: 'No closed contracts',
                                    emptySubtitle:
                                        'Closed or completed contracts will appear here.',
                                    isCompact: isCompact,
                                    horizontalPadding: horizontalPadding,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}