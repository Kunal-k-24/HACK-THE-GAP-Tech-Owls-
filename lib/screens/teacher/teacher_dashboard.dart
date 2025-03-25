import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/models/user_model.dart';
import 'package:onlineex/screens/teacher/create_exam_screen.dart';
import 'package:onlineex/screens/teacher/exam_monitoring_screen.dart';
import 'package:onlineex/screens/auth/login_screen.dart';
import 'package:intl/intl.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ExamService _examService;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupServices();
  }
  
  Future<void> _setupServices() async {
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _examService = ExamService(connectivityService);
    
    setState(() {
      _isLoading = false;
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
  
  void _navigateToCreateExam() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateExamScreen(),
      ),
    );

    if (result == true) {
      // Refresh the exams list
      setState(() {
        _isLoading = true;
      });
      
      // Wait a bit for the stream to update
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.userModel;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Exams'),
            Tab(text: 'Past Exams'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveExams(user),
                _buildPastExams(user),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateExam,
        label: const Text('Create Exam'),
        icon: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildActiveExams(UserModel user) {
    return StreamBuilder<List<ExamModel>>(
      stream: _examService.watchTeacherExams(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No active exams available. Create your first exam!'),
          );
        }
        
        final exams = snapshot.data!;
        final now = DateTime.now();
        
        // Filter for active exams (not ended yet)
        final activeExams = exams.where((exam) => 
          exam.isActive && exam.endTime.isAfter(now)).toList();
        
        if (activeExams.isEmpty) {
          return const Center(
            child: Text('No active exams available. Create your first exam!'),
          );
        }
        
        // Sort by start time (most recent first)
        activeExams.sort((a, b) => b.startTime.compareTo(a.startTime));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeExams.length,
          itemBuilder: (context, index) {
            final exam = activeExams[index];
            return _buildExamCard(exam, true);
          },
        );
      },
    );
  }
  
  Widget _buildPastExams(UserModel user) {
    return StreamBuilder<List<ExamModel>>(
      stream: _examService.watchTeacherExams(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No past exams available.'),
          );
        }
        
        final exams = snapshot.data!;
        final now = DateTime.now();
        
        // Filter for past exams (ended)
        final pastExams = exams.where((exam) => 
          !exam.isActive || exam.endTime.isBefore(now)).toList();
        
        if (pastExams.isEmpty) {
          return const Center(
            child: Text('No past exams available.'),
          );
        }
        
        // Sort by end time (most recent first)
        pastExams.sort((a, b) => b.endTime.compareTo(a.endTime));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pastExams.length,
          itemBuilder: (context, index) {
            final exam = pastExams[index];
            return _buildExamCard(exam, false);
          },
        );
      },
    );
  }

  Widget _buildExamCard(ExamModel exam, bool isActive) {
    final now = DateTime.now();
    final isLive = exam.startTime.isBefore(now) && exam.endTime.isAfter(now);
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isLive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isLive ? Icons.wifi_tethering : Icons.schedule,
                  size: 16,
                  color: isLive ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isLive ? 'LIVE NOW' : 'SCHEDULED',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLive ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(exam.description),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 4),
                    Text('Duration: ${exam.duration} minutes'),
                    const SizedBox(width: 16),
                    const Icon(Icons.school, size: 16),
                    const SizedBox(width: 4),
                    Text('${exam.questions.length} questions'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'From: ${DateFormat('MMM dd, yyyy • hh:mm a').format(exam.startTime)}',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_busy, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'To: ${DateFormat('MMM dd, yyyy • hh:mm a').format(exam.endTime)}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder(
                      stream: _examService.watchExamSubmissions(exam.id),
                      builder: (context, submissionsSnapshot) {
                        final submissionsCount = submissionsSnapshot.hasData 
                            ? submissionsSnapshot.data!.length 
                            : 0;
                        return Chip(
                          avatar: const Icon(Icons.people, size: 16),
                          label: Text('$submissionsCount participants'),
                          backgroundColor: Colors.grey.shade100,
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExamMonitoringScreen(exam: exam),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('Monitor'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 