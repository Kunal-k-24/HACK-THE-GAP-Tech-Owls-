import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:flutter/material.dart';

class MockExamService {
  static final MockExamService _instance = MockExamService._internal();
  factory MockExamService() => _instance;
  MockExamService._internal();

  // Demo C programming questions
  final List<QuestionModel> _demoCQuestions = [
    QuestionModel(
      id: 'q1',
      text: 'What is the output of the following C code?\n\n```c\n#include <stdio.h>\nint main() {\n    int x = 5;\n    printf("%d", ++x);\n    return 0;\n}\n```',
      type: 'multiple_choice',
      marks: 2,
      options: ['5', '6', '4', 'Error'],
      correctAnswer: '1', // Index 1 corresponds to '6'
    ),
    QuestionModel(
      id: 'q2',
      text: 'Which header file should be included to use malloc() function in C?',
      type: 'multiple_choice',
      marks: 2,
      options: ['<memory.h>', '<stdlib.h>', '<string.h>', '<malloc.h>'],
      correctAnswer: '1', // Index 1 corresponds to '<stdlib.h>'
    ),
    QuestionModel(
      id: 'q3',
      text: 'Explain the concept of pointers in C programming and provide a simple example.',
      type: 'essay',
      marks: 5,
      options: null,
      correctAnswer: null,
    ),
    QuestionModel(
      id: 'q4',
      text: 'What is the size of int data type in C on a typical 32-bit system?',
      type: 'multiple_choice',
      marks: 2,
      options: ['2 bytes', '4 bytes', '8 bytes', 'Depends on the compiler'],
      correctAnswer: '1', // Index 1 corresponds to '4 bytes'
    ),
    QuestionModel(
      id: 'q5',
      text: 'Write a C program to find the factorial of a number using recursion.',
      type: 'essay',
      marks: 5,
      options: null,
      correctAnswer: null,
    ),
  ];

  Future<ExamModel> generateExam({bool useAI = false}) async {
    if (useAI) {
      // In a real implementation, this would call an AI service
      // For now, we'll return the demo questions with a different title
      return ExamModel(
        id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
        title: 'AI Generated C Programming Test',
        description: 'This exam tests your knowledge of C programming concepts.',
        createdBy: 'AI_SYSTEM',
        createdAt: DateTime.now(),
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(days: 7)),
        durationMinutes: 60,
        isActive: true,
        questions: _demoCQuestions,
      );
    }

    // Return demo exam with basic questions
    return ExamModel(
      id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Basic C Programming Test',
      description: 'This exam tests your knowledge of fundamental C programming concepts.',
      createdBy: 'SYSTEM',
      createdAt: DateTime.now(),
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(days: 7)),
      durationMinutes: 45,
      isActive: true,
      questions: _demoCQuestions,
    );
  }

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