import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/screens/student/take_exam_screen.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class ExamDetailsScreen extends StatefulWidget {
  final ExamModel exam;
  
  const ExamDetailsScreen({super.key, required this.exam});

  @override
  State<ExamDetailsScreen> createState() => _ExamDetailsScreenState();
}

class _ExamDetailsScreenState extends State<ExamDetailsScreen> {
  late ExamService _examService;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _setupExamService();
  }
  
  void _setupExamService() {
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _examService = ExamService(connectivityService);
  }
  
  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request();
    }
    
    if (await Permission.camera.isPermanentlyDenied) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
            'Camera access is required for exam proctoring. Please enable camera access in your device settings to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }
  }
  
  Future<bool> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return false;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No camera found on your device.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
  
  Future<void> _startExam() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to take the exam.')),
      );
      return;
    }
    
    // Check camera permission
    await _checkCameraPermission();
    if (!(await Permission.camera.isGranted)) {
      return;
    }
    
    // Initialize camera
    if (!(await _initializeCamera())) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final submission = await _examService.startExam(widget.exam.id, user.uid);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TakeExamScreen(
            exam: widget.exam,
            submission: submission,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start exam: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final now = DateTime.now();
    final isExamLive = exam.startTime.isBefore(now) && exam.endTime.isAfter(now);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isExamLive ? 'LIVE NOW' : 'SCHEDULED',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Exam Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.timer),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: ${exam.duration} minutes',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.quiz),
                        const SizedBox(width: 8),
                        Text(
                          'Questions: ${exam.questions.length}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.grade),
                        const SizedBox(width: 8),
                        Text(
                          'Total marks: ${exam.questions.fold<int>(0, (prev, q) => prev + q.marks)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Schedule',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
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
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(
                          'Start: ${DateFormat('MMM dd, yyyy • hh:mm a').format(exam.startTime)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.event_busy),
                        const SizedBox(width: 8),
                        Text(
                          'End: ${DateFormat('MMM dd, yyyy • hh:mm a').format(exam.endTime)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (isExamLive) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.timelapse, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Time remaining: ${_formatDuration(exam.endTime.difference(now))}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rules & Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRule('Once started, you cannot pause the exam.'),
                    _buildRule('Don\'t leave the app during the exam.'),
                    _buildRule('Your face must be visible throughout the exam.'),
                    _buildRule('5 warnings will automatically terminate your exam.'),
                    _buildRule('Ensure you have stable internet connection.'),
                    _buildRule('Answer all questions to maximize your score.'),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Proctoring will be active during the exam:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildProctoring(
                      'Camera access is required for face detection',
                      Icons.camera_alt,
                    ),
                    _buildProctoring(
                      'Switching tabs or windows is not allowed',
                      Icons.tab,
                    ),
                    _buildProctoring(
                      'Multiple faces detection will trigger warnings',
                      Icons.face,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: isExamLive ? _startExam : null,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isExamLive ? 'Start Exam' : 'Exam not active yet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
  
  Widget _buildProctoring(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
} 