import 'package:cloud_firestore/cloud_firestore.dart';

class ExamModel {
  final String id;
  final String title;
  final String description;
  final String createdBy; // Teacher's user ID
  final DateTime createdAt;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool isActive;
  final List<QuestionModel> questions;
  final String? targetClass;
  final String? targetDivision;
  final Map<String, dynamic>? metadata;

  // Getter for duration in minutes
  int get duration => durationMinutes;

  ExamModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.isActive,
    required this.questions,
    this.targetClass,
    this.targetDivision,
    this.metadata,
  });

  // Create ExamModel from JSON data
  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationMinutes: json['durationMinutes'] as int,
      isActive: json['isActive'] as bool,
      questions: (json['questions'] as List)
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
      targetClass: json['targetClass'] as String?,
      targetDivision: json['targetDivision'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convert ExamModel to JSON data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'isActive': isActive,
      'questions': questions.map((q) => q.toJson()).toList(),
      'targetClass': targetClass,
      'targetDivision': targetDivision,
      'metadata': metadata,
    };
  }
}

class QuestionModel {
  final String id;
  final String text;
  final String type; // 'multiple_choice', 'text', 'essay'
  final int marks;
  final List<String>? options; // For multiple choice
  final String? correctAnswer; // For multiple choice (index as string) or text
  final String? imageUrl;
  final int? minWords; // For essay questions
  final Map<String, dynamic>? metadata;

  QuestionModel({
    required this.id,
    required this.text,
    required this.type,
    required this.marks,
    this.options,
    this.correctAnswer,
    this.imageUrl,
    this.minWords,
    this.metadata,
  });

  // Create QuestionModel from JSON data
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      text: json['text'] as String,
      type: json['type'] as String,
      marks: json['marks'] as int,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      correctAnswer: json['correctAnswer'] as String?,
      imageUrl: json['imageUrl'] as String?,
      minWords: json['minWords'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convert QuestionModel to JSON data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'marks': marks,
      'options': options,
      'correctAnswer': correctAnswer,
      'imageUrl': imageUrl,
      'minWords': minWords,
      'metadata': metadata,
    };
  }
}

class OptionModel {
  final String id;
  final String text;
  final bool isCorrect;

  OptionModel({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'],
      text: json['text'],
      isCorrect: json['isCorrect'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCorrect': isCorrect,
    };
  }
} 