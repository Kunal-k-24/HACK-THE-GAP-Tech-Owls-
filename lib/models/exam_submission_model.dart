import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSubmissionModel {
  final String id;
  final String examId;
  final String userId;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final Map<String, AnswerModel> answers;
  final List<ExamWarningModel> warnings;
  final String status; // 'in_progress', 'completed', 'timed_out'
  final int totalScore;
  final int maxScore;

  // Getter for isCompleted
  bool get isCompleted => status == 'completed';

  ExamSubmissionModel({
    required this.id,
    required this.examId,
    required this.userId,
    required this.startedAt,
    this.submittedAt,
    required this.answers,
    required this.warnings,
    required this.status,
    required this.totalScore,
    required this.maxScore,
  });

  // Create ExamSubmissionModel from JSON data
  factory ExamSubmissionModel.fromJson(Map<String, dynamic> json) {
    Map<String, AnswerModel> answers = {};
    if (json['answers'] != null) {
      final answersJson = json['answers'] as Map<String, dynamic>;
      answersJson.forEach((key, value) {
        answers[key] = AnswerModel.fromJson(value as Map<String, dynamic>);
      });
    }

    List<ExamWarningModel> warnings = [];
    if (json['warnings'] != null) {
      final warningsJson = json['warnings'] as List;
      for (var warning in warningsJson) {
        warnings.add(ExamWarningModel.fromJson(warning as Map<String, dynamic>));
      }
    }

    return ExamSubmissionModel(
      id: json['id'] as String,
      examId: json['examId'] as String,
      userId: json['userId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      submittedAt: json['submittedAt'] != null 
          ? DateTime.parse(json['submittedAt'] as String) 
          : null,
      answers: answers,
      warnings: warnings,
      status: json['status'] as String,
      totalScore: json['totalScore'] as int,
      maxScore: json['maxScore'] as int,
    );
  }

  // Convert ExamSubmissionModel to JSON data
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> answersJson = {};
    answers.forEach((key, value) {
      answersJson[key] = value.toJson();
    });

    return {
      'id': id,
      'examId': examId,
      'userId': userId,
      'startedAt': startedAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'answers': answersJson,
      'warnings': warnings.map((warning) => warning.toJson()).toList(),
      'status': status,
      'totalScore': totalScore,
      'maxScore': maxScore,
    };
  }

  ExamSubmissionModel copyWith({
    String? id,
    String? examId,
    String? userId,
    DateTime? startedAt,
    DateTime? submittedAt,
    Map<String, AnswerModel>? answers,
    List<ExamWarningModel>? warnings,
    String? status,
    int? totalScore,
    int? maxScore,
  }) {
    return ExamSubmissionModel(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      answers: answers ?? this.answers,
      warnings: warnings ?? this.warnings,
      status: status ?? this.status,
      totalScore: totalScore ?? this.totalScore,
      maxScore: maxScore ?? this.maxScore,
    );
  }
}

class AnswerModel {
  final String id;
  final String questionId;
  final String questionType;
  final String selectedOption; // For multiple choice questions
  final String textAnswer; // For text or essay questions
  int score; // Set after grading

  AnswerModel({
    required this.id,
    required this.questionId,
    required this.questionType,
    required this.selectedOption,
    required this.textAnswer,
    required this.score,
  });

  // Create AnswerModel from JSON data
  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      id: json['id'] as String,
      questionId: json['questionId'] as String,
      questionType: json['questionType'] as String,
      selectedOption: json['selectedOption'] as String,
      textAnswer: json['textAnswer'] as String,
      score: json['score'] as int,
    );
  }

  // Convert AnswerModel to JSON data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionId': questionId,
      'questionType': questionType,
      'selectedOption': selectedOption,
      'textAnswer': textAnswer,
      'score': score,
    };
  }
}

class ExamWarningModel {
  final String id;
  final String type; // 'face_not_detected', 'multiple_faces', 'tab_change', etc.
  final String description;
  final DateTime timestamp;

  ExamWarningModel({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  // Create ExamWarningModel from JSON data
  factory ExamWarningModel.fromJson(Map<String, dynamic> json) {
    return ExamWarningModel(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  // Convert ExamWarningModel to JSON data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class WarningModel {
  final String id;
  final String type;
  final String description;
  final DateTime timestamp;
  final String? evidence;

  WarningModel({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.evidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'evidence': evidence,
    };
  }

  factory WarningModel.fromJson(Map<String, dynamic> json) {
    return WarningModel(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      evidence: json['evidence'] as String?,
    );
  }
} 