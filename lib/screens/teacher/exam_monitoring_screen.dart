import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/models/user_model.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:intl/intl.dart';

class ExamMonitoringScreen extends StatefulWidget {
  final ExamModel exam;
  
  const ExamMonitoringScreen({super.key, required this.exam});

  @override
  State<ExamMonitoringScreen> createState() => _ExamMonitoringScreenState();
}

class _ExamMonitoringScreenState extends State<ExamMonitoringScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Timer _refreshTimer;
  List<ExamSubmissionModel> _submissions = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, UserModel> _students = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSubmissions();
    
    // Refresh data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadSubmissions();
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer.cancel();
    super.dispose();
  }
  
  Future<void> _loadSubmissions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
      final examService = ExamService(connectivityService);
      
      final token = authService.token!;
      // In a real app, fetch from API
      final submissions = await examService.getMockSubmissions();
      
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
      
      // Get student information for each submission
      // In a real app, this would be fetched from a user service
      _loadStudentInfo();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  void _loadStudentInfo() {
    // Simulate loading student data
    // In a real app, this would fetch actual user data from a service
    for (var submission in _submissions) {
      if (!_students.containsKey(submission.userId)) {
        _students[submission.userId] = UserModel(
          id: submission.userId,
          email: '${submission.userId}@example.com',
          name: 'Student ${submission.userId.split('_').last}',
          role: 'student',
          isActive: true,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        );
      }
    }
    setState(() {});
  }
  
  String _getExamStatus() {
    final now = DateTime.now();
    final exam = widget.exam;
    
    if (!exam.isActive) {
      return 'Inactive';
    } else if (now.isBefore(exam.startTime)) {
      return 'Scheduled';
    } else if (now.isAfter(exam.endTime)) {
      return 'Completed';
    } else {
      return 'Active';
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Scheduled':
        return Colors.blue;
      case 'Completed':
        return Colors.purple;
      case 'Inactive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  List<ExamSubmissionModel> _getInProgressSubmissions() {
    return _submissions.where((s) => 
      s.examId == widget.exam.id && 
      s.submittedAt == null
    ).toList();
  }
  
  List<ExamSubmissionModel> _getCompletedSubmissions() {
    return _submissions.where((s) => 
      s.examId == widget.exam.id && 
      s.submittedAt != null && 
      s.status == 'completed'
    ).toList();
  }
  
  List<ExamSubmissionModel> _getTerminatedSubmissions() {
    return _submissions.where((s) => 
      s.examId == widget.exam.id && 
      s.submittedAt != null && 
      s.status != 'completed'
    ).toList();
  }
  
  Widget _buildStatsList() {
    final exam = widget.exam;
    final inProgress = _getInProgressSubmissions().length;
    final completed = _getCompletedSubmissions().length;
    final terminated = _getTerminatedSubmissions().length;
    final total = inProgress + completed + terminated;
    
    final averageScore = completed > 0
        ? _getCompletedSubmissions().fold(0, (sum, item) => sum + item.totalScore) / completed
        : 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exam Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Students', 
                  total.toString(), 
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatItem(
                  'In Progress', 
                  inProgress.toString(), 
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Completed', 
                  completed.toString(), 
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Terminated', 
                  terminated.toString(), 
                  Icons.cancel,
                  Colors.red,
                ),
                _buildStatItem(
                  'Avg. Score', 
                  '${averageScore.toStringAsFixed(1)}%', 
                  Icons.bar_chart,
                  Colors.purple,
                ),
                _buildStatItem(
                  'Questions', 
                  exam.questions.length.toString(), 
                  Icons.help,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSubmissionsList(List<ExamSubmissionModel> submissions) {
    if (submissions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No submissions found',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final submission = submissions[index];
        final student = _students[submission.userId];
        final startedAt = DateFormat('MMM dd, yyyy • hh:mm a').format(submission.startedAt);
        
        final submittedAtStr = submission.submittedAt != null 
            ? DateFormat('MMM dd, yyyy • hh:mm a').format(submission.submittedAt!) 
            : 'In progress';
            
        final duration = submission.submittedAt != null 
            ? _formatDuration(submission.submittedAt!.difference(submission.startedAt)) 
            : 'Still taking';
            
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        student?.name.substring(0, 1) ?? '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student?.name ?? 'Unknown Student',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            student?.email ?? '',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (submission.submittedAt != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: submission.status == 'completed'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: submission.status == 'completed'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Text(
                          submission.status == 'completed'
                              ? 'Completed'
                              : 'Terminated',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: submission.status == 'completed'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'In Progress',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Started',
                        startedAt,
                        Icons.play_circle,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Submitted',
                        submittedAtStr,
                        Icons.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Duration',
                        duration,
                        Icons.timer,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Score',
                        submission.submittedAt != null
                            ? '${submission.totalScore}/${submission.maxScore}'
                            : 'N/A',
                        Icons.score,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Questions Answered',
                        '${submission.answers.length}/${widget.exam.questions.length}',
                        Icons.question_answer,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Warnings',
                        submission.warnings.isNotEmpty
                            ? submission.warnings.length.toString()
                            : 'None',
                        Icons.warning,
                        submission.warnings.isNotEmpty
                            ? Colors.orange
                            : null,
                      ),
                    ),
                  ],
                ),
                if (submission.submittedAt == null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Proctor access would be implemented in a real app'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.remove_red_eye),
                        label: const Text('Proctor Access'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showTerminateConfirmDialog(submission);
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Terminate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showTerminateConfirmDialog(ExamSubmissionModel submission) {
    final student = _students[submission.userId];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Exam'),
        content: Text(
          'Are you sure you want to terminate the exam for ${student?.name ?? 'this student'}? '
          'This action cannot be undone and the student will not be able to continue.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, this would call an API to terminate the exam
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exam termination would be implemented in a real app'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('TERMINATE'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value, IconData icon, [Color? color]) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inHours}h ${twoDigitMinutes}m ${twoDigitSeconds}s';
  }
  
  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final status = _getExamStatus();
    final statusColor = _getStatusColor(status);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Monitoring'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSubmissions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Overview Tab
                    RefreshIndicator(
                      onRefresh: _loadSubmissions,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                exam.title,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                exam.description,
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildInfoItem(
                                            'Start Time',
                                            DateFormat('MMM dd, yyyy • hh:mm a')
                                                .format(exam.startTime),
                                            Icons.calendar_today,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildInfoItem(
                                            'End Time',
                                            DateFormat('MMM dd, yyyy • hh:mm a')
                                                .format(exam.endTime),
                                            Icons.event,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildInfoItem(
                                            'Duration',
                                            '${exam.durationMinutes} minutes',
                                            Icons.timer,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildInfoItem(
                                            'Questions',
                                            exam.questions.length.toString(),
                                            Icons.help,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStatsList(),
                            const SizedBox(height: 24),
                            const Text(
                              'Recent Activity',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._submissions
                                .where((s) => s.examId == exam.id)
                                .take(3)
                                .map((submission) {
                              final student = _students[submission.userId];
                              
                              String activityText;
                              IconData activityIcon;
                              Color activityColor;
                              
                              if (submission.submittedAt == null) {
                                activityText = '${student?.name} started the exam';
                                activityIcon = Icons.play_arrow;
                                activityColor = Colors.blue;
                              } else if (submission.status == 'completed') {
                                activityText = '${student?.name} completed the exam';
                                activityIcon = Icons.check_circle;
                                activityColor = Colors.green;
                              } else {
                                activityText = '${student?.name} exam was terminated';
                                activityIcon = Icons.cancel;
                                activityColor = Colors.red;
                              }
                              
                              final time = submission.submittedAt ?? submission.startedAt;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: activityColor.withOpacity(0.1),
                                    child: Icon(activityIcon, color: activityColor),
                                  ),
                                  title: Text(activityText),
                                  subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(time)),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    
                    // In Progress Tab
                    RefreshIndicator(
                      onRefresh: _loadSubmissions,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildSubmissionsList(_getInProgressSubmissions()),
                      ),
                    ),
                    
                    // Completed Tab
                    RefreshIndicator(
                      onRefresh: _loadSubmissions,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildSubmissionsList(
                          [..._getCompletedSubmissions(), ..._getTerminatedSubmissions()]
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
} 