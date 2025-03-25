import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/models/user_model.dart';
import 'package:onlineex/screens/student/exam_details_screen.dart';
import 'package:onlineex/screens/student/exam_result_screen.dart';
import 'package:onlineex/screens/auth/login_screen.dart';
import 'package:intl/intl.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ExamService _examService;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Results'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableExams(user),
                _buildUpcomingExams(user),
                _buildExamResults(user),
              ],
            ),
    );
  }
  
  Widget _buildAvailableExams(UserModel user) {
    return StreamBuilder<List<ExamModel>>(
      stream: _examService.watchActiveExams(
        user.className ?? '10th',
        user.division ?? 'A',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No exams available at the moment.'),
          );
        }
        
        final exams = snapshot.data!;
        final now = DateTime.now();
        
        // Filter for currently active exams
        final activeExams = exams.where((exam) => 
          exam.startTime.isBefore(now) && exam.endTime.isAfter(now)).toList();
        
        if (activeExams.isEmpty) {
          return const Center(
            child: Text('No exams available at the moment.'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeExams.length,
          itemBuilder: (context, index) {
            final exam = activeExams[index];
            final remainingTime = exam.endTime.difference(now);
            
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  exam.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(exam.description),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 4),
                        Text('${exam.duration} minutes'),
                        const SizedBox(width: 16),
                        const Icon(Icons.school, size: 16),
                        const SizedBox(width: 4),
                        Text('${exam.questions.length} questions'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ends in: ${_formatDuration(remainingTime)}',
                      style: TextStyle(
                        color: remainingTime.inMinutes < 30 
                            ? Colors.red 
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExamDetailsScreen(exam: exam),
                      ),
                    );
                  },
                  child: const Text('Start'),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildUpcomingExams(UserModel user) {
    return StreamBuilder<List<ExamModel>>(
      stream: _examService.watchActiveExams(
        user.className ?? '10th',
        user.division ?? 'A',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No upcoming exams scheduled.'),
          );
        }
        
        final exams = snapshot.data!;
        final now = DateTime.now();
        
        // Filter for upcoming exams
        final upcomingExams = exams.where((exam) => 
          exam.startTime.isAfter(now)).toList();
        
        if (upcomingExams.isEmpty) {
          return const Center(
            child: Text('No upcoming exams scheduled.'),
          );
        }
        
        // Sort by start time
        upcomingExams.sort((a, b) => a.startTime.compareTo(b.startTime));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcomingExams.length,
          itemBuilder: (context, index) {
            final exam = upcomingExams[index];
            final startTime = exam.startTime;
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  exam.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(exam.description),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 4),
                        Text('${exam.duration} minutes'),
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
                        Text('Starts on: ${DateFormat('MMM dd, yyyy').format(startTime)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Text('Time: ${DateFormat('hh:mm a').format(startTime)}'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildExamResults(UserModel user) {
    return StreamBuilder<List<ExamSubmissionModel>>(
      stream: _examService.watchStudentSubmissions(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No exam results available.'),
          );
        }
        
        final submissions = snapshot.data!;
        
        // Filter for completed exams
        final completedSubmissions = submissions.where((sub) => 
          sub.isCompleted).toList();
        
        if (completedSubmissions.isEmpty) {
          return const Center(
            child: Text('No exam results available.'),
          );
        }
        
        // Sort by submission date (most recent first)
        completedSubmissions.sort((a, b) => 
          b.submittedAt!.compareTo(a.submittedAt!));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedSubmissions.length,
          itemBuilder: (context, index) {
            final submission = completedSubmissions[index];
            final percentage = submission.maxScore > 0 
                ? (submission.totalScore / submission.maxScore * 100).round() 
                : 0;
            
            Color resultColor;
            if (percentage >= 80) {
              resultColor = Colors.green;
            } else if (percentage >= 60) {
              resultColor = Colors.orange;
            } else {
              resultColor = Colors.red;
            }
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExamResultScreen(submission: submission),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FutureBuilder<ExamModel?>(
                              future: _examService.getExam(submission.examId),
                              builder: (context, examSnapshot) {
                                if (!examSnapshot.hasData) {
                                  return const Text(
                                    'Loading exam details...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  );
                                }
                                
                                return Text(
                                  examSnapshot.data?.title ?? 'Unknown Exam',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: resultColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: resultColor),
                            ),
                            child: Text(
                              '$percentage%',
                              style: TextStyle(
                                color: resultColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.score, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Score: ${submission.totalScore}/${submission.maxScore}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Submitted: ${DateFormat('MMM dd, yyyy • hh:mm a').format(submission.submittedAt!)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            submission.status == 'completed' 
                                ? Icons.check_circle 
                                : Icons.cancel,
                            size: 16,
                            color: submission.status == 'completed' 
                                ? Colors.green 
                                : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Status: ${submission.status == 'completed' ? 'Completed' : 'Terminated'}',
                            style: TextStyle(
                              color: submission.status == 'completed' 
                                  ? Colors.green 
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
} 