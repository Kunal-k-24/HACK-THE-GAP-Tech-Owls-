import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';

class MockExamService {
  static final MockExamService _instance = MockExamService._internal();
  factory MockExamService() => _instance;
  MockExamService._internal();

  Future<void> submitExam(ExamSubmissionModel submission) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return;
  }

  Future<void> recordWarning(String submissionId, String type, String description) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return;
  }
} 