import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/models/user_model.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:onlineex/screens/student/exam_result_screen.dart';
import 'package:intl/intl.dart';

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
  late final ExamService _examService;
  late final ConnectivityService _connectivityService;
  late final Timer _examTimer;
  late final UserModel _currentUser;
  
  Map<String, AnswerModel> _answers = {};
  List<QuestionModel> _questions = [];
  List<ExamWarningModel> _warnings = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _remainingTimeInSeconds = 0;
  int _currentQuestionIndex = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupServices();
    _loadExamData();
    _startExamTimer();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _examTimer.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      _addWarning('app_background', 'App was sent to background.');
    }
  }
  
  void _setupServices() {
    _connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _examService = ExamService(_connectivityService);
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser!;
  }
  
  Future<void> _loadExamData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      _questions = widget.exam.questions;
      _answers = widget.submission.answers;
      _warnings = widget.submission.warnings;
      
      // Calculate remaining time
      final now = DateTime.now();
      final endTime = widget.exam.endTime;
      _remainingTimeInSeconds = endTime.difference(now).inSeconds;
      
      if (_remainingTimeInSeconds <= 0) {
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
        if (_remainingTimeInSeconds > 0) {
          _remainingTimeInSeconds--;
        } else {
          timer.cancel();
          _submitExam(isAutoSubmit: true);
        }
      });
    });
  }
  
  void _addWarning(String type, String description) {
    setState(() {
      _warnings.add(ExamWarningModel(
        id: 'warning_${_warnings.length}',
        type: type,
        description: description,
        timestamp: DateTime.now(),
      ));
    });
  }
  
  void _saveAnswer(AnswerModel answer) {
    setState(() {
      _answers[answer.questionId] = answer;
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
  
  void _goToQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      setState(() {
        _currentQuestionIndex = index;
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
      
      final submission = ExamSubmissionModel(
        id: 'submission_${DateTime.now().millisecondsSinceEpoch}',
        examId: widget.exam.id,
        userId: _currentUser.id,
        startedAt: widget.submission.startedAt,
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
        
        // Navigate to results page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamResultScreen(submission: submission),
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
    final currentQuestion = _questions[_currentQuestionIndex];
    final answer = _answers[currentQuestion.id];
    
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Exam?'),
            content: const Text(
              'If you exit now, your answers will not be saved. '
              'Are you sure you want to exit the exam?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('STAY'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('EXIT'),
              ),
            ],
          ),
        );
        
        return shouldExit ?? false;
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
                    color: _remainingTimeInSeconds <= 300 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _remainingTimeInSeconds <= 300 ? Colors.red : Colors.blue,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: _remainingTimeInSeconds <= 300 ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_remainingTimeInSeconds ~/ 60}:${(_remainingTimeInSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _remainingTimeInSeconds <= 300 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isSubmitting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Submitting your exam...',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please do not close the app',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildQuestionNavigation(),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuestionHeader(currentQuestion),
                          const SizedBox(height: 24),
                          _buildQuestionContent(currentQuestion, answer),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildBottomNavigation(),
                ],
              ),
      ),
    );
  }
  
  Widget _buildQuestionNavigation() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => _buildQuestionList(),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Row(
              children: [
                Icon(Icons.list, size: 18),
                SizedBox(width: 8),
                Text('Question Navigator'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionList() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Question Navigator',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusIndicator(Colors.green, 'Answered'),
              const SizedBox(width: 16),
              _buildStatusIndicator(Colors.grey, 'Not Answered'),
              const SizedBox(width: 16),
              _buildStatusIndicator(Colors.blue, 'Current'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final isAnswered = _answers.containsKey(_questions[index].id);
                final isCurrentQuestion = index == _currentQuestionIndex;
                
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _goToQuestion(index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrentQuestion 
                          ? Colors.blue 
                          : isAnswered 
                              ? Colors.green 
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentQuestion 
                            ? Colors.blue.shade800 
                            : isAnswered 
                                ? Colors.green.shade800 
                                : Colors.grey.shade400,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrentQuestion || isAnswered
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back to Exam'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
  
  Widget _buildQuestionHeader(QuestionModel question) {
    String questionTypeText;
    IconData questionTypeIcon;
    
    switch (question.type) {
      case 'multiple_choice':
        questionTypeText = 'Multiple Choice';
        questionTypeIcon = Icons.check_circle_outline;
        break;
      case 'text':
        questionTypeText = 'Text Answer';
        questionTypeIcon = Icons.text_fields;
        break;
      case 'essay':
        questionTypeText = 'Essay';
        questionTypeIcon = Icons.subject;
        break;
      default:
        questionTypeText = 'Question';
        questionTypeIcon = Icons.help_outline;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(questionTypeIcon, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    questionTypeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Marks: ${question.marks}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          question.text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              question.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 150,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Text('Failed to load image'),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildQuestionContent(QuestionModel question, AnswerModel? answer) {
    switch (question.type) {
      case 'multiple_choice':
        return _buildMultipleChoiceQuestion(question, answer);
      case 'text':
        return _buildTextQuestion(question, answer);
      case 'essay':
        return _buildEssayQuestion(question, answer);
      default:
        return const Text('Unsupported question type');
    }
  }
  
  Widget _buildMultipleChoiceQuestion(QuestionModel question, AnswerModel? answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select one answer:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...question.options!.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = answer?.selectedOption == index.toString();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                _saveAnswer(AnswerModel(
                  id: 'answer_${question.id}',
                  questionId: question.id,
                  questionType: question.type,
                  selectedOption: index.toString(),
                  textAnswer: '',
                  score: 0,
                ));
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.blue.withOpacity(0.1) 
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.blue 
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected 
                            ? Colors.blue 
                            : Colors.white,
                        border: Border.all(
                          color: isSelected 
                              ? Colors.blue 
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontWeight: isSelected 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildTextQuestion(QuestionModel question, AnswerModel? answer) {
    final textController = TextEditingController(text: answer?.textAnswer ?? '');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Answer:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: textController,
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: 3,
          onChanged: (value) {
            _saveAnswer(AnswerModel(
              id: 'answer_${question.id}',
              questionId: question.id,
              questionType: question.type,
              selectedOption: '',
              textAnswer: value,
              score: 0,
            ));
          },
        ),
      ],
    );
  }
  
  Widget _buildEssayQuestion(QuestionModel question, AnswerModel? answer) {
    final textController = TextEditingController(text: answer?.textAnswer ?? '');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Your Essay:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Min words: ${question.minWords ?? 0}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: textController,
          decoration: InputDecoration(
            hintText: 'Write your essay here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: 10,
          onChanged: (value) {
            _saveAnswer(AnswerModel(
              id: 'answer_${question.id}',
              questionId: question.id,
              questionType: question.type,
              selectedOption: '',
              textAnswer: value,
              score: 0,
            ));
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Word count: ${_countWords(textController.text)}',
          style: TextStyle(
            fontSize: 12,
            color: _countWords(textController.text) >= (question.minWords ?? 0)
                ? Colors.green
                : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  int _countWords(String text) {
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }
  
  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0) ...[
            ElevatedButton(
              onPressed: _previousQuestion,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back, size: 16),
                  SizedBox(width: 8),
                  Text('Previous'),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (_currentQuestionIndex < _questions.length - 1) ...[
            ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                children: [
                  Text('Next'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => _submitExam(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                children: [
                  Text('Submit Exam'),
                  SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 