import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  Stream<QuerySnapshot> get _employeesStream => _firestore
      .collection('users')
      .where('role', isEqualTo: 'employee')
      .orderBy('fullName')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6A1B9A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee List'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: primaryColor.withOpacity(0.05),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // Employee list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _employeesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = _searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['fullName'] ?? '').toString().toLowerCase();
                        final dept = (data['department'] ?? '').toString().toLowerCase();
                        final pos = (data['position'] ?? '').toString().toLowerCase();
                        final email = (data['email'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) ||
                            dept.contains(_searchQuery) ||
                            pos.contains(_searchQuery) ||
                            email.contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No employees found'
                              : 'No results for "$_searchQuery"',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final data =
                        filtered[index].data() as Map<String, dynamic>;
                    final name = data['fullName'] ?? 'Unknown';
                    final department = data['department'] ?? 'N/A';
                    final position = data['position'] ?? 'N/A';
                    final email = data['email'] ?? '';
                    final empId = data['employeeId'];
                    final initials = _getInitials(name);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: primaryColor.withOpacity(0.15),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          if (empId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '#${empId.toString().padLeft(4, '0')}',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.business_rounded,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '$position • $department',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _showEmployeeDetails(context, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  void _showEmployeeDetails(BuildContext context, Map<String, dynamic> data) {
    const primaryColor = Color(0xFF6A1B9A);
    final name = data['fullName'] ?? 'Unknown';
    final department = data['department'] ?? 'N/A';
    final position = data['position'] ?? 'N/A';
    final email = data['email'] ?? 'N/A';
    final phone = data['phone'] ?? 'N/A';
    final empId = data['employeeId'];

    DateTime? joiningDate;
    final joiningTs = data['dateOfJoining'];
    if (joiningTs is Timestamp) {
      joiningDate = joiningTs.toDate();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    child: Text(
                      _getInitials(name),
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        if (empId != null)
                          Text(
                            'Employee #${empId.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _detailRow(Icons.business_rounded, 'Department', department),
              _detailRow(Icons.work_rounded, 'Position', position),
              _detailRow(Icons.email_outlined, 'Email', email),
              _detailRow(Icons.phone_rounded, 'Phone', phone),
              if (joiningDate != null)
                _detailRow(
                  Icons.calendar_today_rounded,
                  'Date of Joining',
                  '${joiningDate.day}/${joiningDate.month}/${joiningDate.year}',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6A1B9A)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
