import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/services/mock_exam_service.dart';
import 'package:onlineex/services/mock_proctoring_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TakeExamScreen extends StatefulWidget {
  final ExamModel exam;
  final ExamSubmissionModel submission;
  final String userRole;
  
  const TakeExamScreen({
    super.key,
    required this.exam,
    required this.submission,
    required this.userRole,
  });

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> with WidgetsBindingObserver {
  final _examService = MockExamService();
  late final MockProctoringService _proctoringService;
  late final CameraController _cameraController;
  late Timer _examTimer;
  late Timer _warningTimer;
  
  // Add text editing controllers map
  final Map<String, TextEditingController> _textControllers = {};
  
  Map<String, AnswerModel> _answers = {};
  List<QuestionModel> _questions = [];
  List<ExamWarningModel> _warnings = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentQuestionIndex = 0;
  Duration _remainingTime = Duration.zero;
  bool _isCameraInitialized = false;
  bool _showWarning = false;
  int _consecutiveWarnings = 0;
  bool _warningSystemActive = true;
  
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  bool _isBlindMode = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupServices();
    _loadExamData();
    _startExamTimer();
    _initializeCamera();
    _startWarningTimer();
    _initializeTts();
    _initializeSpeech();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _examTimer.cancel();
    _warningTimer.cancel();
    _proctoringService.dispose();
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    // Dispose all text controllers
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    flutterTts.stop();
    speech.stop();
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
      
      // Initialize text controllers for each text/essay question
      for (final question in _questions) {
        if (question.type == 'text' || question.type == 'essay') {
          final answer = _answers[question.id];
          _textControllers[question.id] = TextEditingController(
            text: answer?.textAnswer ?? '',
          );
        }
      }
      
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
      // Dismiss warning when user answers
      _showWarning = false;
      _consecutiveWarnings = 0;
    });
  }
  
  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        // Permanently stop warnings
        _warningSystemActive = false;
        _showWarning = false;
      });
    }
  }
  
  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        // Permanently stop warnings
        _warningSystemActive = false;
        _showWarning = false;
      });
    }
  }
  
  void _startWarningTimer() {
    _warningTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || 
          widget.submission.status == 'completed' || 
          !_warningSystemActive) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _showWarning = true;
        _consecutiveWarnings++;
        
        // Add warning to the list
        _warnings.add(ExamWarningModel(
          id: 'warning_${_warnings.length + 1}',
          type: 'face_not_detected',
          description: 'Face not detected in frame',
          timestamp: DateTime.now(),
        ));
        
        // Auto-terminate after 5 consecutive warnings
        if (_consecutiveWarnings >= 5) {
          timer.cancel();
          _submitExam(isAutoSubmit: true, reason: 'Too many warnings');
        }
      });
    });
  }
  
  void _handleWarningDismiss() {
    setState(() {
      _showWarning = false;
      _consecutiveWarnings = 0;
    });
  }
  
  Future<void> _submitExam({bool isAutoSubmit = false, String? reason}) async {
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
        status: isAutoSubmit ? 'terminated' : 'completed',
        totalScore: totalScore,
        maxScore: maxScore,
      );
      
      await _examService.submitExam(submission);
      
      if (mounted) {
        _examTimer.cancel();
        _warningTimer.cancel();
        
        // Show result dialog and then navigate
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(isAutoSubmit ? 'Exam Terminated' : 'Exam Completed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reason != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Reason: $reason',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Text('Your score: $totalScore'),
                Text(
                  'Percentage: ${((totalScore / maxScore) * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 8),
                Text(
                  'Total warnings: ${_warnings.length}',
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to previous screen
                  // Navigate to respective dashboard
                  Navigator.pushReplacementNamed(
                    context,
                    widget.userRole == 'student' ? '/student/dashboard' : '/teacher/dashboard',
                  );
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
  
  Future<void> _initializeTts() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initializeSpeech() async {
    await speech.initialize();
  }

  Future<void> _speakQuestion() async {
    if (_isSpeaking) return;

    final question = _questions[_currentQuestionIndex];
    final options = question.options ?? [];
    
    setState(() => _isSpeaking = true);
    
    // Speak question
    await flutterTts.speak('Question ${_currentQuestionIndex + 1}: ${question.text}');
    await Future.delayed(const Duration(seconds: 3));
    
    // Speak options
    for (int i = 0; i < options.length; i++) {
      await flutterTts.speak('Option ${String.fromCharCode(65 + i)}: ${options[i]}');
      await Future.delayed(const Duration(seconds: 2));
    }
    
    setState(() => _isSpeaking = false);

    // For text/essay questions in blind mode, start listening automatically
    if (_isBlindMode && (question.type == 'text' || question.type == 'essay')) {
      await flutterTts.speak('Please speak your answer now');
      await Future.delayed(const Duration(seconds: 2));
      _startListening();
    }
    // For multiple choice in blind mode, select option B
    else if (_isBlindMode && question.type == 'multiple_choice') {
      await Future.delayed(const Duration(seconds: 1));
      _saveAnswer(question.id, '1', question.type); // '1' represents option B (0-based index)
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isCompleted = widget.submission.status == 'completed' || 
                            widget.submission.status == 'timed_out';

    return WillPopScope(
      onWillPop: () async {
        // Allow back navigation if exam is completed
        return isCompleted;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.exam.title),
              if (isCompleted)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          centerTitle: true,
          automaticallyImplyLeading: isCompleted,
          actions: [
            if (!isCompleted)
              IconButton(
                icon: Icon(_isBlindMode ? Icons.accessibility : Icons.accessibility_new),
                onPressed: () {
                  setState(() {
                    _isBlindMode = !_isBlindMode;
                    if (_isBlindMode) {
                      _warningSystemActive = false; // Disable warnings for blind mode
                      _speakQuestion(); // Start speaking the current question
                    }
                  });
                },
                tooltip: 'Toggle Blind Mode',
              ),
            if (!isCompleted)
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
            // Only show camera preview if not in blind mode
            if (_isCameraInitialized && !_isBlindMode)
              Expanded(
                flex: 1,
                child: _buildCameraPreview(),
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
              if (_isBlindMode && !_isSpeaking)
                ElevatedButton.icon(
                  onPressed: _speakQuestion,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Read Question'),
                ),
              if (_currentQuestionIndex > 0)
                TextButton.icon(
                  onPressed: () {
                    _previousQuestion();
                    if (_isBlindMode) _speakQuestion();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
              const SizedBox(width: 8),
              if (_currentQuestionIndex < _questions.length - 1)
                TextButton.icon(
                  onPressed: () {
                    _nextQuestion();
                    if (_isBlindMode) _speakQuestion();
                  },
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
              onChanged: widget.submission.status == 'completed' ? null : (value) {
                if (value != null) {
                  _saveAnswer(question.id, value, question.type);
                }
              },
            );
          },
        );
      case 'text':
      case 'essay':
        // Use the persistent text controller
        final controller = _textControllers[question.id]!;
        return Column(
          children: [
            TextField(
              maxLines: question.type == 'essay' ? 8 : 1,
              decoration: InputDecoration(
                hintText: _isBlindMode ? 'Speaking mode active...' : 'Enter your answer here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              controller: controller,
              enabled: !_isBlindMode && widget.submission.status != 'completed',
              onChanged: (value) {
                _saveAnswer(question.id, value, question.type);
              },
            ),
            if (_isListening) ...[
              const SizedBox(height: 8),
              const Text(
                'Listening... Speak your answer',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        );
      default:
        return const Center(child: Text('Unsupported question type'));
    }
  }
  
  Future<void> _startListening() async {
    bool available = await speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() => _isListening = false);
          // After finishing listening, read back the answer
          if (_isBlindMode) {
            _readBackAnswer();
          }
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        if (_isBlindMode) {
          flutterTts.speak('Sorry, there was an error with speech recognition. Please try again.');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );

    if (available) {
      setState(() => _isListening = true);
      
      await speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final currentQuestion = _questions[_currentQuestionIndex];
            final controller = _textControllers[currentQuestion.id]!;
            
            setState(() {
              // Append to existing text with a space if there's already text
              String newText = controller.text.isEmpty 
                ? result.recognizedWords 
                : '${controller.text} ${result.recognizedWords}';
              
              controller.text = newText;
              _saveAnswer(currentQuestion.id, newText, currentQuestion.type);
              _isListening = false;
            });
          }
        },
        localeId: 'en_US',
      );
    } else {
      if (_isBlindMode) {
        flutterTts.speak('Speech recognition is not available on this device');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available on this device'),
        ),
      );
    }
  }

  Future<void> _readBackAnswer() async {
    final currentQuestion = _questions[_currentQuestionIndex];
    final controller = _textControllers[currentQuestion.id]!;
    
    if (controller.text.isNotEmpty) {
      await flutterTts.speak('Your answer is: ${controller.text}');
      await Future.delayed(const Duration(seconds: 2));
      await flutterTts.speak('Say a new answer to change it, or use next or previous to move between questions');
    }
  }
  
  Widget _buildCameraPreview() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _showWarning ? Colors.red : Colors.grey.shade300,
              width: _showWarning ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraController),
              ),
              // Always show warning count
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Warnings: ${_warnings.length}/5',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Warning overlay
              if (_showWarning)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 2),
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Warning ${_warnings.length}/5',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Face not detected',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                        if (_warningSystemActive)
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Click Next/Previous to stop warnings',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
} 