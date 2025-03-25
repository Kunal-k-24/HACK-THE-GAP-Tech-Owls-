import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/screens/auth/login_screen.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showApprovalDialog(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teacher Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${teacher['name']}'),
            const SizedBox(height: 8),
            Text('Email: ${teacher['email']}'),
            const SizedBox(height: 8),
            Text('Qualifications: ${teacher['qualifications']}'),
            const SizedBox(height: 8),
            Text(
              'Request Date: ${DateFormat('MMM dd, yyyy').format(teacher['requestDate'])}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authService = Provider.of<AuthService>(context, listen: false);
                final specialCode = await authService.approveTeacher(teacher['id']);
                
                if (!mounted) return;
                Navigator.pop(context);
                
                // Show the special code
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Teacher Approved'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Please provide these credentials to the teacher:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          'Email: ${teacher['email']}\nSpecial Code: $specialCode',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final pendingTeachers = authService.pendingTeachers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Teacher Approvals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: pendingTeachers.isEmpty
                  ? const Center(
                      child: Text(
                        'No pending teacher approvals',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: pendingTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = pendingTeachers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(teacher['name']),
                            subtitle: Text(teacher['email']),
                            trailing: ElevatedButton(
                              onPressed: () => _showApprovalDialog(teacher),
                              child: const Text('Review'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 