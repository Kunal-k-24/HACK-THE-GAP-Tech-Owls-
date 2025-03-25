import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/services/mock_exam_service.dart';
import 'package:onlineex/services/mock_proctoring_service.dart';
import 'package:camera/camera.dart';

class TakeExamScreen extends StatefulWidget {
  final ExamModel exam;
  final ExamSubmissionModel submission;
  
  const TakeExamScreen({
    super.key,
    required this.exam,
    required this.submission,
  });

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> with WidgetsBindingObserver {
  final _examService = MockExamService();
  late final MockProctoringService _proctoringService;
  late final CameraController _cameraController;
  late Timer _examTimer;
  
  Map<String, AnswerModel> _answers = {};
  List<QuestionModel> _questions = [];
  List<ExamWarningModel> _warnings = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentQuestionIndex = 0;
  Duration _remainingTime = Duration.zero;
  bool _isCameraInitialized = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupServices();
    _loadExamData();
    _startExamTimer();
    _initializeCamera();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _examTimer.cancel();
    _proctoringService.dispose();
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      _proctoringService.recordTabChange();
    }
  }
  
  void _setupServices() {
    _proctoringService = MockProctoringService(_examService);
    
    // Start proctoring
    _proctoringService.startMonitoring(
      widget.submission.id,
      widget.exam.id,
      'dummy-user-id',
    );
  }
  
  Future<void> _loadExamData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      _questions = widget.exam.questions;
      _answers = widget.submission.answers ?? {};
      _warnings = widget.submission.warnings ?? [];
      
      // Calculate remaining time
      final now = DateTime.now();
      final endTime = widget.submission.startedAt.add(Duration(minutes: widget.exam.duration));
      _remainingTime = endTime.difference(now);
      
      if (_remainingTime.isNegative) {
        _submitExam(isAutoSubmit: true);
      }
    } catch (e) {
      debugPrint('Error loading exam data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading exam: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _startExamTimer() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingTime = _remainingTime - const Duration(seconds: 1);
        if (_remainingTime.isNegative) {
          timer.cancel();
          _submitExam(isAutoSubmit: true);
        }
      });
    });
  }
  
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found');
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _saveAnswer(String questionId, String answer, String type) {
    setState(() {
      _answers[questionId] = AnswerModel(
        id: 'answer_$questionId',
        questionId: questionId,
        questionType: type,
        selectedOption: type == 'multiple_choice' ? answer : '',
        textAnswer: type == 'multiple_choice' ? '' : answer,
        score: 0,
      );
    });
  }
  
  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }
  
  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }
  
  Future<void> _submitExam({bool isAutoSubmit = false}) async {
    if (_isSubmitting) return;
    
    if (!isAutoSubmit) {
      // Confirm submission
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit Exam?'),
          content: Text(
            'You are about to submit your exam with ${_answers.length} of ${_questions.length} questions answered. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      );
      
      if (shouldSubmit != true) return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Calculate score for objective questions
      int totalScore = 0;
      int maxScore = 0;
      
      for (final question in _questions) {
        maxScore += question.marks;
        final answer = _answers[question.id];
        
        if (answer != null && question.type == 'multiple_choice') {
          if (answer.selectedOption == question.correctAnswer) {
            answer.score = question.marks;
            totalScore += question.marks;
          } else {
            answer.score = 0;
          }
        }
      }
      
      final submission = widget.submission.copyWith(
        submittedAt: DateTime.now(),
        answers: _answers,
        warnings: _warnings,
        status: isAutoSubmit ? 'timed_out' : 'completed',
        totalScore: totalScore,
        maxScore: maxScore,
      );
      
      await _examService.submitExam(submission);
      
      if (mounted) {
        _examTimer.cancel();
        
        // Show result dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Exam Completed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your score: $totalScore'),
                Text(
                  'Percentage: ${((totalScore / maxScore) * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting exam: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button during exam
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exam.title),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingTime.inMinutes <= 5 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _remainingTime.inMinutes <= 5 ? Colors.red : Colors.blue,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: _remainingTime.inMinutes <= 5 ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_remainingTime.inHours.toString().padLeft(2, '0')}:${(_remainingTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _remainingTime.inMinutes <= 5 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            // Main exam content
            Expanded(
              flex: 3,
              child: _buildExamContent(),
            ),
            // Camera preview
            if (_isCameraInitialized)
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CameraPreview(_cameraController),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExamContent() {
    final question = _questions[_currentQuestionIndex];
    final answer = _answers[question.id];
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question navigation
          Row(
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_currentQuestionIndex > 0)
                TextButton.icon(
                  onPressed: _previousQuestion,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
              const SizedBox(width: 8),
              if (_currentQuestionIndex < _questions.length - 1)
                TextButton.icon(
                  onPressed: _nextQuestion,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Question text
          Text(
            question.text,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          // Answer input based on question type
          Expanded(
            child: _buildAnswerInput(question, answer),
          ),
          // Submit button
          if (_currentQuestionIndex == _questions.length - 1)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitExam(isAutoSubmit: false),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Exam'),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAnswerInput(QuestionModel question, AnswerModel? answer) {
    switch (question.type) {
      case 'multiple_choice':
        final options = question.options ?? [];
        return ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return RadioListTile<String>(
              title: Text(option),
              value: index.toString(),
              groupValue: answer?.selectedOption,
              onChanged: (value) {
                if (value != null) {
                  _saveAnswer(question.id, value, question.type);
                }
              },
            );
          },
        );
      case 'text':
      case 'essay':
        return TextField(
          maxLines: question.type == 'essay' ? 8 : 1,
          decoration: InputDecoration(
            hintText: 'Enter your answer here',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          controller: TextEditingController(text: answer?.textAnswer ?? ''),
          onChanged: (value) {
            _saveAnswer(question.id, value, question.type);
          },
        );
      default:
        return const Center(child: Text('Unsupported question type'));
    }
  }
} 