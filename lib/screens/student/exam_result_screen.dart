import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:intl/intl.dart';

class ExamResultScreen extends StatefulWidget {
  final ExamSubmissionModel submission;
  
  const ExamResultScreen({super.key, required this.submission});

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  late ExamService _examService;
  ExamModel? _exam;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _setupAndLoadData();
  }
  
  Future<void> _setupAndLoadData() async {
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    _examService = ExamService(connectivityService);
    
    try {
      _exam = await _examService.getExam(widget.submission.examId);
    } catch (e) {
      debugPrint('Error loading exam: $e');
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
    final submission = widget.submission;
    final percentage = submission.maxScore > 0 
      ? (submission.totalScore / submission.maxScore * 100).round() 
      : 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Result'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultHeader(percentage),
                const SizedBox(height: 24),
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
                          _exam?.title ?? 'Unknown Exam',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_exam?.description ?? ''),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.score),
                            const SizedBox(width: 8),
                            Text(
                              'Score: ${submission.totalScore}/${submission.maxScore}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              submission.status == 'completed' 
                                ? Icons.check_circle 
                                : Icons.cancel,
                              color: submission.status == 'completed' 
                                ? Colors.green 
                                : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${submission.status == 'completed' ? 'Completed' : 'Terminated'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: submission.status == 'completed' 
                                  ? Colors.green 
                                  : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(
                              'Submitted: ${DateFormat('MMM dd, yyyy • hh:mm a').format(submission.submittedAt!)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.timer),
                            const SizedBox(width: 8),
                            Text(
                              'Time taken: ${_formatDuration(submission.submittedAt!.difference(submission.startedAt))}',
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
                  'Answer Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnswerSummary(),
                const SizedBox(height: 24),
                if (submission.warnings.isNotEmpty) ...[
                  const Text(
                    'Warnings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildWarningsList(),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
    );
  }
  
  Widget _buildResultHeader(int percentage) {
    Color resultColor;
    String resultText;
    
    if (percentage >= 80) {
      resultColor = Colors.green;
      resultText = 'Excellent!';
    } else if (percentage >= 70) {
      resultColor = Colors.blue;
      resultText = 'Good Job!';
    } else if (percentage >= 60) {
      resultColor = Colors.orange;
      resultText = 'Passed';
    } else {
      resultColor = Colors.red;
      resultText = 'Needs Improvement';
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: resultColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            resultText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: resultColor,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(resultColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                  Text(
                    'Score',
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnswerSummary() {
    if (_exam == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Exam data not available'),
        ),
      );
    }
    
    final answeredQuestions = widget.submission.answers.length;
    final totalQuestions = _exam!.questions.length;
    final correctAnswers = widget.submission.answers.values
        .where((answer) => answer.score > 0)
        .length;
    
    return Card(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  Icons.help_outline,
                  'Total Questions',
                  '$totalQuestions',
                  Colors.blue,
                ),
                _buildSummaryItem(
                  Icons.check_circle_outline,
                  'Answered',
                  '$answeredQuestions',
                  Colors.green,
                ),
                _buildSummaryItem(
                  Icons.star_outline,
                  'Correct',
                  '$correctAnswers',
                  Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Question Performance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exam!.questions.length,
              itemBuilder: (context, index) {
                final question = _exam!.questions[index];
                final answer = widget.submission.answers[question.id];
                final isCorrect = answer != null && answer.score > 0;
                final isPartiallyCorrect = answer != null && 
                    answer.score > 0 && answer.score < question.marks;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: answer == null 
                        ? Colors.grey 
                        : (isCorrect 
                            ? (isPartiallyCorrect ? Colors.orange : Colors.green) 
                            : Colors.red),
                    child: Icon(
                      answer == null 
                          ? Icons.remove 
                          : (isCorrect 
                              ? (isPartiallyCorrect ? Icons.star_half : Icons.check) 
                              : Icons.close),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    'Question ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: answer != null 
                      ? Text('Score: ${answer.score}/${question.marks}')
                      : const Text('Not answered'),
                  trailing: answer != null 
                      ? Text(
                          '${(answer.score / question.marks * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect 
                                ? (isPartiallyCorrect ? Colors.orange : Colors.green) 
                                : Colors.red,
                          ),
                        ) 
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
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
            fontSize: 20,
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
  
  Widget _buildWarningsList() {
    final warnings = widget.submission.warnings;
    
    return Card(
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
              '${warnings.length} Warning${warnings.length > 1 ? 's' : ''} Detected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: warnings.length >= 5 ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: warnings.length,
              itemBuilder: (context, index) {
                final warning = warnings[index];
                
                IconData warningIcon;
                switch (warning.type) {
                  case 'face_not_detected':
                    warningIcon = Icons.face;
                    break;
                  case 'multiple_faces':
                    warningIcon = Icons.groups;
                    break;
                  case 'face_looking_away':
                    warningIcon = Icons.face_retouching_off;
                    break;
                  case 'tab_change':
                    warningIcon = Icons.tab_unselected;
                    break;
                  default:
                    warningIcon = Icons.warning_amber;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(warningIcon, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              warning.description,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Time: ${DateFormat('hh:mm:ss a').format(warning.timestamp)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inHours}h ${twoDigitMinutes}m ${twoDigitSeconds}s';
  }
} 