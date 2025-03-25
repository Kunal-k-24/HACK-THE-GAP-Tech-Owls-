import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/services/connectivity_service.dart';

class ExamService {
  static const String _baseUrl = 'https://api.onlineex.com/api';
  final ConnectivityService _connectivityService;

  ExamService(this._connectivityService);

  // Get available exams for a student
  Future<List<ExamModel>> getAvailableExamsForStudent(
    String userId,
    String token,
    String className,
    String division,
  ) async {
    await _ensureConnectivity();
    
    try {
      // Filter exams by class and division
      final exams = _mockExams.where((exam) => 
        exam.isActive &&
        exam.startTime.isBefore(DateTime.now()) &&
        exam.endTime.isAfter(DateTime.now()) &&
        exam.targetClass == className &&
        exam.targetDivision == division
      ).toList();
      
      return exams;
    } catch (e) {
      debugPrint('Error getting available exams: $e');
      rethrow;
    }
  }

  // Get upcoming exams for a student
  Future<List<ExamModel>> getUpcomingExamsForStudent(
    String userId,
    String token,
    String className,
    String division,
  ) async {
    await _ensureConnectivity();
    
    try {
      // Filter exams by class and division
      final exams = _mockExams.where((exam) => 
        exam.isActive &&
        exam.startTime.isAfter(DateTime.now()) &&
        exam.targetClass == className &&
        exam.targetDivision == division
      ).toList();
      
      return exams;
    } catch (e) {
      debugPrint('Error getting upcoming exams: $e');
      rethrow;
    }
  }

  // Get exams created by a teacher
  Future<List<ExamModel>> getExamsByTeacher(String teacherId, String token) async {
    await _ensureConnectivity();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exams/teacher/$teacherId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> examsJson = data['exams'] as List;
        
        return examsJson
            .map((examJson) => ExamModel.fromJson(examJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load teacher exams');
      }
    } catch (e) {
      debugPrint('Error getting teacher exams: $e');
      rethrow;
    }
  }

  // Get a specific exam by ID
  Future<ExamModel> getExam(String examId, {String? token}) async {
    await _ensureConnectivity();
    
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse('$_baseUrl/exams/$examId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ExamModel.fromJson(data['exam'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load exam details');
      }
    } catch (e) {
      debugPrint('Error getting exam details: $e');
      rethrow;
    }
  }

  // Mock data storage
  static final List<ExamModel> _mockExams = [];
  static final List<ExamSubmissionModel> _mockSubmissions = [];

  // Create a new exam
  Future<ExamModel> createExam(ExamModel exam, String token) async {
    await _ensureConnectivity();
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    
    try {
      // Add to mock storage
      _mockExams.add(exam);
      return exam;
    } catch (e) {
      debugPrint('Error creating exam: $e');
      rethrow;
    }
  }

  // Update an existing exam
  Future<ExamModel> updateExam(ExamModel exam, String token) async {
    await _ensureConnectivity();
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    
    try {
      // Update in mock storage
      final index = _mockExams.indexWhere((e) => e.id == exam.id);
      if (index != -1) {
        _mockExams[index] = exam;
      } else {
        throw Exception('Exam not found');
      }
      return exam;
    } catch (e) {
      debugPrint('Error updating exam: $e');
      rethrow;
    }
  }

  // Delete an exam
  Future<void> deleteExam(String examId, String token) async {
    await _ensureConnectivity();
    
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/exams/$examId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete exam');
      }
    } catch (e) {
      debugPrint('Error deleting exam: $e');
      rethrow;
    }
  }

  // Submit an exam
  Future<ExamSubmissionModel> submitExam(ExamSubmissionModel submission) async {
    await _ensureConnectivity();
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    
    try {
      // Add to mock storage
      _mockSubmissions.add(submission);
      return submission;
    } catch (e) {
      debugPrint('Error submitting exam: $e');
      rethrow;
    }
  }

  // Get exam submissions for a student
  Future<List<ExamSubmissionModel>> getStudentSubmissions(String userId, String token) async {
    await _ensureConnectivity();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/submissions/student/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> submissionsJson = data['submissions'] as List;
        
        return submissionsJson
            .map((submissionJson) => ExamSubmissionModel.fromJson(submissionJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load student submissions');
      }
    } catch (e) {
      debugPrint('Error getting student submissions: $e');
      rethrow;
    }
  }

  // Get submissions for a specific exam
  Future<List<ExamSubmissionModel>> getExamSubmissions(String examId, String token) async {
    await _ensureConnectivity();
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/submissions/exam/$examId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> submissionsJson = data['submissions'] as List;
        
        return submissionsJson
            .map((submissionJson) => ExamSubmissionModel.fromJson(submissionJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load exam submissions');
      }
    } catch (e) {
      debugPrint('Error getting exam submissions: $e');
      rethrow;
    }
  }

  // Start an exam
  Future<ExamSubmissionModel> startExam(String examId, String userId) async {
    await _ensureConnectivity();
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/exams/$examId/start'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ExamSubmissionModel.fromJson(data['submission'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to start exam');
      }
    } catch (e) {
      debugPrint('Error starting exam: $e');
      rethrow;
    }
  }

  // Mock data for development (remove in production)
  Future<ExamSubmissionModel> mockStartExam(String examId, String userId) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    return ExamSubmissionModel(
      id: 'submission_${DateTime.now().millisecondsSinceEpoch}',
      examId: examId,
      userId: userId,
      startedAt: DateTime.now(),
      submittedAt: null,
      answers: {},
      warnings: [],
      status: 'in_progress',
      totalScore: 0,
      maxScore: 0,
    );
  }

  // Mock data for development (remove in production)
  Future<List<ExamModel>> getMockExams(bool isActive) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    final now = DateTime.now();
    final exams = [
      ExamModel(
        id: 'exam_1',
        title: 'Mathematics Midterm',
        description: 'Basic algebra and calculus concepts.',
        createdBy: 'teacher_1',
        createdAt: now.subtract(const Duration(days: 7)),
        startTime: isActive ? now.subtract(const Duration(hours: 1)) : now.add(const Duration(days: 1)),
        endTime: isActive ? now.add(const Duration(hours: 2)) : now.add(const Duration(days: 1, hours: 2)),
        durationMinutes: 90,
        isActive: isActive,
        questions: _getMockQuestions(),
        targetClass: '10th',
        targetDivision: 'A',
      ),
      ExamModel(
        id: 'exam_2',
        title: 'Computer Science Fundamentals',
        description: 'Introduction to programming concepts and algorithms.',
        createdBy: 'teacher_2',
        createdAt: now.subtract(const Duration(days: 5)),
        startTime: isActive ? now.subtract(const Duration(hours: 2)) : now.add(const Duration(days: 2)),
        endTime: isActive ? now.add(const Duration(hours: 1)) : now.add(const Duration(days: 2, hours: 2)),
        durationMinutes: 120,
        isActive: isActive,
        questions: _getMockQuestions(),
        targetClass: '10th',
        targetDivision: 'B',
      ),
      ExamModel(
        id: 'exam_3',
        title: 'English Literature',
        description: 'Analyzing modern poetry and prose.',
        createdBy: 'teacher_3',
        createdAt: now.subtract(const Duration(days: 3)),
        startTime: isActive ? now.subtract(const Duration(minutes: 30)) : now.add(const Duration(days: 3)),
        endTime: isActive ? now.add(const Duration(hours: 3)) : now.add(const Duration(days: 3, hours: 2)),
        durationMinutes: 60,
        isActive: isActive,
        questions: _getMockQuestions(),
        targetClass: '11th',
        targetDivision: 'A',
      ),
    ];

    return exams;
  }

  List<QuestionModel> _getMockQuestions() {
    return [
      QuestionModel(
        id: 'q_1',
        text: 'What is the result of 2 + 2?',
        type: 'multiple_choice',
        marks: 1,
        options: ['3', '4', '5', '6'],
        correctAnswer: '1', // Index 1 = '4'
      ),
      QuestionModel(
        id: 'q_2',
        text: 'Explain the concept of object-oriented programming.',
        type: 'essay',
        marks: 5,
        minWords: 100,
      ),
      QuestionModel(
        id: 'q_3',
        text: 'What is the capital of France?',
        type: 'text',
        marks: 1,
        correctAnswer: 'Paris',
      ),
      QuestionModel(
        id: 'q_4',
        text: 'Which of the following is a primary color?',
        type: 'multiple_choice',
        marks: 1,
        options: ['Green', 'Purple', 'Red', 'Orange'],
        correctAnswer: '2', // Index 2 = 'Red'
      ),
      QuestionModel(
        id: 'q_5',
        text: 'Solve for x: 3x + 5 = 14',
        type: 'multiple_choice',
        marks: 2,
        options: ['x = 3', 'x = 4', 'x = 5', 'x = 6'],
        correctAnswer: '0', // Index 0 = 'x = 3'
      ),
    ];
  }

  Future<List<ExamSubmissionModel>> getMockSubmissions() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    final now = DateTime.now();
    final submissions = [
      ExamSubmissionModel(
        id: 'sub_1',
        examId: 'exam_1',
        userId: 'student_1',
        startedAt: now.subtract(const Duration(days: 1, hours: 2)),
        submittedAt: now.subtract(const Duration(days: 1, hours: 1)),
        answers: {
          'q_1': AnswerModel(
            id: 'a_1',
            questionId: 'q_1',
            questionType: 'multiple_choice',
            selectedOption: '1',
            textAnswer: '',
            score: 1,
          ),
          'q_2': AnswerModel(
            id: 'a_2',
            questionId: 'q_2',
            questionType: 'essay',
            selectedOption: '',
            textAnswer: 'Object-oriented programming is a programming paradigm based on the concept of "objects", which can contain data and code: data in the form of fields, and code in the form of procedures. A defining feature of object-oriented programming is that procedures (or methods) are attached to the objects they manipulate.',
            score: 4,
          ),
        },
        warnings: [
          ExamWarningModel(
            id: 'w_1',
            type: 'tab_change',
            description: 'Student switched tabs',
            timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 30)),
          ),
        ],
        status: 'completed',
        totalScore: 5,
        maxScore: 10,
      ),
      ExamSubmissionModel(
        id: 'sub_2',
        examId: 'exam_2',
        userId: 'student_1',
        startedAt: now.subtract(const Duration(days: 2, hours: 2)),
        submittedAt: now.subtract(const Duration(days: 2, hours: 1, minutes: 30)),
        answers: {
          'q_1': AnswerModel(
            id: 'a_3',
            questionId: 'q_1',
            questionType: 'multiple_choice',
            selectedOption: '1',
            textAnswer: '',
            score: 1,
          ),
          'q_3': AnswerModel(
            id: 'a_4',
            questionId: 'q_3',
            questionType: 'text',
            selectedOption: '',
            textAnswer: 'Paris',
            score: 1,
          ),
          'q_4': AnswerModel(
            id: 'a_5',
            questionId: 'q_4',
            questionType: 'multiple_choice',
            selectedOption: '2',
            textAnswer: '',
            score: 1,
          ),
        },
        warnings: [],
        status: 'completed',
        totalScore: 3,
        maxScore: 10,
      ),
    ];

    return submissions;
  }

  // Ensure connectivity before making API calls
  Future<void> _ensureConnectivity() async {
    if (!(await _connectivityService.checkConnectivity())) {
      throw Exception('No internet connection');
    }
  }

  // Get active exams as a stream
  Stream<List<ExamModel>> watchActiveExams(String className, String division) async* {
    while (true) {
      try {
        final now = DateTime.now();
        // Filter exams by class and division
        final exams = _mockExams.where((exam) => 
          exam.isActive &&
          exam.startTime.isBefore(now) && 
          exam.endTime.isAfter(now) &&
          exam.targetClass == className &&
          exam.targetDivision == division
        ).toList();
        
        if (exams.isEmpty) {
          // If no exams found, try to get some mock exams
          final mockExams = await getMockExams(true);
          final filteredMockExams = mockExams.where((exam) =>
            exam.targetClass == className &&
            exam.targetDivision == division
          ).toList();
          yield filteredMockExams;
        } else {
          yield exams;
        }
      } catch (e) {
        debugPrint('Error getting active exams: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5)); // Refresh every 5 seconds
    }
  }

  // Get teacher's exams as a stream
  Stream<List<ExamModel>> watchTeacherExams(String teacherId) async* {
    while (true) {
      try {
        // Return exams from mock storage
        final exams = _mockExams.where((exam) => exam.createdBy == teacherId).toList();
        yield exams;
      } catch (e) {
        debugPrint('Error getting teacher exams: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5)); // Refresh every 5 seconds
    }
  }

  // Get exam submissions as a stream
  Stream<List<ExamSubmissionModel>> watchExamSubmissions(String examId) async* {
    while (true) {
      try {
        // Return submissions from mock storage
        final submissions = _mockSubmissions.where((sub) => sub.examId == examId).toList();
        yield submissions;
      } catch (e) {
        debugPrint('Error getting exam submissions: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5)); // Refresh every 5 seconds
    }
  }

  // Get student submissions as a stream
  Stream<List<ExamSubmissionModel>> watchStudentSubmissions(String userId) async* {
    while (true) {
      try {
        final submissions = await getMockSubmissions();
        yield submissions.where((sub) => sub.userId == userId).toList();
      } catch (e) {
        debugPrint('Error getting student submissions: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 30)); // Refresh every 30 seconds
    }
  }
} 