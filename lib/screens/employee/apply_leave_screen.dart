import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/leave_request.dart';
import '../../services/leave_service.dart';
import '../../services/auth_service.dart';
import '../shared/chat_fab.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _leaveService = LeaveService();
  final _authService = AuthService();

  LeaveType _selectedLeaveType = LeaveType.casual;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  LeaveBalance? _leaveBalance;
  File? _prescriptionFile;

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
  }

  Future<void> _loadLeaveBalance() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      final balance = await _leaveService.getLeaveBalance(userId);
      setState(() {
        _leaveBalance = balance;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start date first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  int get _totalDays {
    if (_startDate != null && _endDate != null) {
      return _endDate!.difference(_startDate!).inDays + 1;
    }
    return 0;
  }

  int get _remainingBalance {
    if (_leaveBalance == null) return 0;
    switch (_selectedLeaveType) {
      case LeaveType.casual:
        return _leaveBalance!.casualRemaining;
      case LeaveType.medical:
        return _leaveBalance!.medicalRemaining;
      case LeaveType.annual:
        return _leaveBalance!.annualRemaining;
    }
  }

  Future<void> _pickPrescription() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _prescriptionFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end dates'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw 'User not found';

      await _leaveService.submitLeaveRequest(
        employeeId: user.uid,
        employeeName: user.displayName ?? '',
        employeeEmail: user.email ?? '',
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        attachmentFile: _selectedLeaveType == LeaveType.medical ? _prescriptionFile : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        final displayError = message.contains('too large for Firestore')
            ? 'Prescription file is too large to store in Firestore. Please upload a smaller file.'
            : message;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
      ),
      body: _leaveBalance == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Leave Balance Card
                    Card(
                      elevation: 4,
                      color: const Color(0xFF0D3B66),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Your Leave Balance',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildBalanceItem(
                                  'Casual',
                                  _leaveBalance!.casualRemaining,
                                  _leaveBalance!.casualLeaves,
                                ),
                                _buildBalanceItem(
                                  'Medical',
                                  _leaveBalance!.medicalRemaining,
                                  _leaveBalance!.medicalLeaves,
                                ),
                                _buildBalanceItem(
                                  'Annual',
                                  _leaveBalance!.annualRemaining,
                                  _leaveBalance!.annualLeaves,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Leave Type
                    Text(
                      'Leave Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<LeaveType>(
                      segments: const [
                        ButtonSegment(
                          value: LeaveType.casual,
                          label: Text('Casual'),
                          icon: Icon(Icons.event_available),
                        ),
                        ButtonSegment(
                          value: LeaveType.medical,
                          label: Text('Medical'),
                          icon: Icon(Icons.local_hospital),
                        ),
                        ButtonSegment(
                          value: LeaveType.annual,
                          label: Text('Annual'),
                          icon: Icon(Icons.beach_access),
                        ),
                      ],
                      selected: {_selectedLeaveType},
                      onSelectionChanged: (Set<LeaveType> newSelection) {
                        setState(() {
                          _selectedLeaveType = newSelection.first;
                          // the file gets discarded if changed to anything but medical (or ignored in backend)
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Date',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _selectStartDate,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today),
                                      const SizedBox(width: 8),
                                      Text(
                                        _startDate == null
                                            ? 'Select'
                                            : DateFormat('MMM dd, yyyy')
                                                .format(_startDate!),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Date',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _selectEndDate,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today),
                                      const SizedBox(width: 8),
                                      Text(
                                        _endDate == null
                                            ? 'Select'
                                            : DateFormat('MMM dd, yyyy')
                                                .format(_endDate!),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Total Days Info
                    if (_totalDays > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _totalDays <= _remainingBalance
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _totalDays <= _remainingBalance
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Days: $_totalDays',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _totalDays <= _remainingBalance
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                            Text(
                              'Available: $_remainingBalance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _totalDays <= _remainingBalance
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Reason
                    Text(
                      'Reason',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for leave...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Medical Attachment (Optional)
                    if (_selectedLeaveType == LeaveType.medical) ...[
                      Text(
                        'Medical Prescription (Optional)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickPrescription,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _prescriptionFile != null ? Icons.check_circle : Icons.upload_file,
                                color: _prescriptionFile != null ? Colors.green : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _prescriptionFile != null
                                      ? 'Prescription Attached: ${_prescriptionFile!.path.split('/').last}'
                                      : 'Tap to upload doctor\'s prescription',
                                  style: TextStyle(
                                    color: _prescriptionFile != null ? Colors.green.shade700 : Colors.grey.shade600,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (_prescriptionFile != null)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _prescriptionFile = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],

                    // Submit Button
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submitLeaveRequest,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color(0xFF0D3B66),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Leave Request',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: const ChatFab(),
    );
  }

  Widget _buildBalanceItem(String label, int remaining, int total) {
    return Column(
      children: [
        Text(
          '$remaining/$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
