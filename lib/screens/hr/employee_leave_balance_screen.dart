import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/leave_request.dart';
import '../../services/leave_service.dart';

class EmployeeLeaveBalanceScreen extends StatefulWidget {
  const EmployeeLeaveBalanceScreen({super.key});

  @override
  State<EmployeeLeaveBalanceScreen> createState() =>
      _EmployeeLeaveBalanceScreenState();
}

class _EmployeeLeaveBalanceScreenState
    extends State<EmployeeLeaveBalanceScreen> {
  final _leaveService = LeaveService();
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employees = await _leaveService.getAllEmployeesWithBalances();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employees: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editLeaveBalance(
    String employeeId,
    String employeeName,
    LeaveBalance currentBalance,
  ) async {
    final casualController =
        TextEditingController(text: currentBalance.casualLeaves.toString());
    final medicalController =
        TextEditingController(text: currentBalance.medicalLeaves.toString());
    final annualController =
        TextEditingController(text: currentBalance.annualLeaves.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Leave Balance'),
            const SizedBox(height: 4),
            Text(
              employeeName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: casualController,
                decoration: const InputDecoration(
                  labelText: 'Casual Leaves',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_available),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: medicalController,
                decoration: const InputDecoration(
                  labelText: 'Medical Leaves',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: annualController,
                decoration: const InputDecoration(
                  labelText: 'Annual Leaves',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.beach_access),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currently Used:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Casual: ${currentBalance.casualUsed}, Medical: ${currentBalance.medicalUsed}, Annual: ${currentBalance.annualUsed}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
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
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final casual = int.tryParse(casualController.text) ?? 10;
        final medical = int.tryParse(medicalController.text) ?? 10;
        final annual = int.tryParse(annualController.text) ?? 10;

        await _leaveService.updateLeaveBalance(
          employeeId: employeeId,
          casualLeaves: casual,
          medicalLeaves: medical,
          annualLeaves: annual,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave balance updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadEmployees();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating balance: $e'),
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
        title: const Text('Employee Leave Balances'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No employees found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    final balance =
                        employee['leaveBalance'] as LeaveBalance;
                    return _buildEmployeeCard(employee, balance);
                  },
                ),
    );
  }

  Widget _buildEmployeeCard(
    Map<String, dynamic> employee,
    LeaveBalance balance,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    employee['fullName'].toString().isNotEmpty
                        ? employee['fullName'].toString()[0].toUpperCase()
                        : 'E',
                    style: const TextStyle(
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee['email'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editLeaveBalance(
                    employee['id'],
                    employee['fullName'] ?? 'Unknown',
                    balance,
                  ),
                  color: const Color(0xFF6A1B9A),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Leave Balance Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Leaves',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${balance.totalRemaining}/${balance.totalLeaves}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLeaveTypeChip(
                          'Casual',
                          balance.casualRemaining,
                          balance.casualLeaves,
                          Icons.event_available,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLeaveTypeChip(
                          'Medical',
                          balance.medicalRemaining,
                          balance.medicalLeaves,
                          Icons.local_hospital,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLeaveTypeChip(
                          'Annual',
                          balance.annualRemaining,
                          balance.annualLeaves,
                          Icons.beach_access,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeChip(
    String label,
    int remaining,
    int total,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            '$remaining/$total',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
