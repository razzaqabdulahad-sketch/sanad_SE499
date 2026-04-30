import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'employee_home_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({super.key});

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _selectedDepartment;
  DateTime? _dateOfJoining;

  final List<String> _departments = [
    'Human Resources',
    'Finance',
    'Engineering',
    'Marketing',
    'Sales',
    'Operations',
    'Legal',
    'IT Support',
    'Administration',
    'Customer Service',
  ];

  /// Gets the next employee ID using a Firestore transaction on a counter doc.
  Future<int> _getNextEmployeeId() async {
    final counterRef = _firestore.collection('metadata').doc('employeeCounter');
    return _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int nextId;
      if (!snapshot.exists) {
        nextId = 1;
        transaction.set(counterRef, {'lastId': 1});
      } else {
        nextId = (snapshot.data()?['lastId'] ?? 0) + 1;
        transaction.update(counterRef, {'lastId': nextId});
      }
      return nextId;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfJoining() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF0D3B66),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfJoining = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a department'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _authService.currentUser!.uid;
      final employeeId = await _getNextEmployeeId();

      await _firestore.collection('users').doc(uid).update({
        'employeeId': employeeId,
        'department': _selectedDepartment,
        'position': _positionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dateOfJoining': _dateOfJoining != null
            ? Timestamp.fromDate(_dateOfJoining!)
            : null,
        'profileCompleted': true,
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  elevation: 4,
                  color: const Color(0xFF1A4D7A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: const Icon(
                            Icons.badge_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to Sanad!',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please fill in your employee details to get started.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
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
                const SizedBox(height: 28),

                // Employee ID info
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your Employee ID will be assigned automatically.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Department Dropdown
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline,
                    ),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDepartment,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      hint: Row(
                        children: [
                          Icon(Icons.business_rounded,
                              size: 20, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Text(
                            'Select Department',
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Row(
                            children: [
                              const Icon(Icons.business_rounded, size: 20),
                              const SizedBox(width: 12),
                              Text(dept),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedDepartment = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Position / Job Title
                TextFormField(
                  controller: _positionController,
                  decoration: InputDecoration(
                    labelText: 'Position / Job Title',
                    prefixIcon: const Icon(Icons.work_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your position';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date of Joining
                InkWell(
                  onTap: _pickDateOfJoining,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Joining',
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                    ),
                    child: Text(
                      _dateOfJoining != null
                          ? '${_dateOfJoining!.day}/${_dateOfJoining!.month}/${_dateOfJoining!.year}'
                          : 'Select date',
                      style: TextStyle(
                        color: _dateOfJoining != null
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
