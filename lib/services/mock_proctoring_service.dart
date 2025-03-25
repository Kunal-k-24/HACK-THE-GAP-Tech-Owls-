import 'package:onlineex/services/mock_exam_service.dart';

class MockProctoringService {
  final MockExamService _examService;

  MockProctoringService(this._examService);

  void startMonitoring(String submissionId, String examId, String userId) {
    // In a real app, this would start face detection and tab change monitoring
  }

  Future<void> recordTabChange() async {
    // In a real app, this would record a warning for tab change
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void dispose() {
    // Clean up resources
  }
} 