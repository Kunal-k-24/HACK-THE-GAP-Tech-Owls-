import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/models/exam_model.dart';
import 'package:onlineex/models/user_model.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/services/exam_service.dart';
import 'package:onlineex/services/connectivity_service.dart';
import 'package:intl/intl.dart';
import 'package:onlineex/services/mock_exam_service.dart';

class CreateExamScreen extends StatefulWidget {
  final ExamModel? examToEdit;
  
  const CreateExamScreen({super.key, this.examToEdit});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _targetClassController;
  late TextEditingController _targetDivisionController;
  
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _endTime = TimeOfDay.now();
  
  bool _isActive = true;
  bool _isLoading = false;
  bool _isEditing = false;
  
  List<QuestionModel> _questions = [];
  
  final _examService = MockExamService();
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.examToEdit != null;
    
    _titleController = TextEditingController(
      text: widget.examToEdit?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.examToEdit?.description ?? '',
    );
    _durationController = TextEditingController(
      text: widget.examToEdit?.durationMinutes.toString() ?? '90',
    );
    _targetClassController = TextEditingController(
      text: widget.examToEdit?.targetClass ?? '',
    );
    _targetDivisionController = TextEditingController(
      text: widget.examToEdit?.targetDivision ?? '',
    );
    
    if (_isEditing) {
      final exam = widget.examToEdit!;
      _startDate = exam.startTime;
      _startTime = TimeOfDay.fromDateTime(exam.startTime);
      _endDate = exam.endTime;
      _endTime = TimeOfDay.fromDateTime(exam.endTime);
      _isActive = exam.isActive;
      _questions = List.from(exam.questions);
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _targetClassController.dispose();
    _targetDivisionController.dispose();
    super.dispose();
  }
  
  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _startTime.hour,
          _startTime.minute,
        );
        
        // Ensure end date is after start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
          _endTime = TimeOfDay.fromDateTime(_endDate);
        }
      });
    }
  }
  
  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _startDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          picked.hour,
          picked.minute,
        );
        
        // Ensure end time is after start time
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
          _endTime = TimeOfDay.fromDateTime(_endDate);
        }
      });
    }
  }
  
  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _endTime.hour,
          _endTime.minute,
        );
      });
    }
  }
  
  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _endDate = DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }
  
  Future<void> _saveExam() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    
    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    
    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
      final examService = ExamService(connectivityService);
      
      final currentUser = authService.currentUser!;
      final token = authService.token!;
      
      final durationMinutes = int.tryParse(_durationController.text) ?? 90;
      
      final exam = ExamModel(
        id: _isEditing ? widget.examToEdit!.id : 'exam_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: currentUser.id,
        createdAt: _isEditing ? widget.examToEdit!.createdAt : DateTime.now(),
        startTime: startDateTime,
        endTime: endDateTime,
        durationMinutes: durationMinutes,
        isActive: _isActive,
        questions: _questions,
        targetClass: _targetClassController.text.trim(),
        targetDivision: _targetDivisionController.text.trim(),
      );
      
      if (_isEditing) {
        await examService.updateExam(exam, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exam updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await examService.createExam(exam, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exam created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving exam: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _addQuestion() {
    // Navigate to create question screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateQuestionScreen(
          onQuestionCreated: (question) {
            setState(() {
              _questions.add(question);
            });
          },
        ),
      ),
    );
  }
  
  void _editQuestion(int index) {
    // Navigate to edit question screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateQuestionScreen(
          questionToEdit: _questions[index],
          onQuestionCreated: (question) {
            setState(() {
              _questions[index] = question;
            });
          },
        ),
      ),
    );
  }
  
  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _questions.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClassDivisionFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _targetClassController,
            decoration: const InputDecoration(
              labelText: 'Target Class',
              hintText: 'e.g., 10th',
              prefixIcon: Icon(Icons.class_),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter target class';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _targetDivisionController,
            decoration: const InputDecoration(
              labelText: 'Target Division',
              hintText: 'e.g., A',
              prefixIcon: Icon(Icons.group),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter target division';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
  
  Future<void> _generateExam({required bool useAI}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final exam = await _examService.generateExam(useAI: useAI);
      
      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(useAI ? 'AI Generated Exam' : 'Demo Exam Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: ${exam.title}'),
                const SizedBox(height: 8),
                Text('Questions: ${exam.questions.length}'),
                const SizedBox(height: 8),
                Text('Duration: ${exam.durationMinutes} minutes'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating exam: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Exam' : 'Create New Exam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveExam,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Exam Title',
                        hintText: 'Enter exam title',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter exam title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter exam description',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter exam description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildClassDivisionFields(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration (minutes)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter duration';
                              }
                              final duration = int.tryParse(value);
                              if (duration == null || duration <= 0) {
                                return 'Please enter a valid duration';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Active'),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectStartDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_startDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _selectStartTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _startTime.format(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectEndDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_endDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _selectEndTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Time',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _endTime.format(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Questions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addQuestion,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Question'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _questions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No questions added yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _questions.length,
                            itemBuilder: (context, index) {
                              final question = _questions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(
                                    question.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${question.type} • ${question.marks} mark${question.marks > 1 ? "s" : ""}',
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text('${index + 1}'),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editQuestion(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteQuestion(index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

class CreateQuestionScreen extends StatefulWidget {
  final QuestionModel? questionToEdit;
  final Function(QuestionModel) onQuestionCreated;
  
  const CreateQuestionScreen({
    super.key,
    this.questionToEdit,
    required this.onQuestionCreated,
  });

  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _questionTextController;
  late TextEditingController _marksController;
  late TextEditingController _minWordsController;
  late TextEditingController _correctAnswerController;
  
  String _questionType = 'multiple_choice';
  bool _isEditing = false;
  List<String> _options = ['', '', '', ''];
  String _correctOptionIndex = '0';
  String? _imageUrl;
  int? _minWords;
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.questionToEdit != null;
    
    if (_isEditing) {
      final question = widget.questionToEdit!;
      _questionType = question.type;
      _questionTextController = TextEditingController(text: question.text);
      _marksController = TextEditingController(text: question.marks.toString());
      _minWordsController = TextEditingController(text: question.minWords?.toString() ?? '');
      _correctAnswerController = TextEditingController(text: question.correctAnswer ?? '');
      
      _correctOptionIndex = question.correctAnswer ?? '0';
      _imageUrl = question.imageUrl;
      _minWords = question.minWords;
      
      if (question.options != null && question.options!.isNotEmpty) {
        _options = List.from(question.options!);
        while (_options.length < 4) {
          _options.add('');
        }
      }
    } else {
      _questionTextController = TextEditingController();
      _marksController = TextEditingController(text: '1');
      _minWordsController = TextEditingController(text: '100');
      _correctAnswerController = TextEditingController();
    }
  }
  
  @override
  void dispose() {
    _questionTextController.dispose();
    _marksController.dispose();
    _minWordsController.dispose();
    _correctAnswerController.dispose();
    super.dispose();
  }
  
  void _saveQuestion() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    // Validate options for multiple choice
    if (_questionType == 'multiple_choice') {
      final validOptions = _options.where((option) => option.trim().isNotEmpty).toList();
      if (validOptions.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least 2 options'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Make sure the correct answer is within range
      final correctIndex = int.tryParse(_correctOptionIndex) ?? 0;
      if (correctIndex < 0 || correctIndex >= validOptions.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid correct answer selection'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    List<String>? options;
    String? correctAnswer;
    int? minWords;
    
    if (_questionType == 'multiple_choice') {
      options = _options.where((option) => option.trim().isNotEmpty).toList();
      correctAnswer = _correctOptionIndex;
    } else if (_questionType == 'text') {
      correctAnswer = _correctAnswerController.text.trim();
    } else if (_questionType == 'essay') {
      minWords = int.tryParse(_minWordsController.text) ?? 100;
    }
    
    final question = QuestionModel(
      id: _isEditing ? widget.questionToEdit!.id : 'q_${DateTime.now().millisecondsSinceEpoch}',
      text: _questionTextController.text.trim(),
      type: _questionType,
      marks: int.parse(_marksController.text),
      options: options,
      correctAnswer: correctAnswer,
      imageUrl: _imageUrl,
      minWords: minWords,
    );
    
    widget.onQuestionCreated(question);
    Navigator.pop(context);
  }
  
  Widget _buildMultipleChoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Radio<String>(
                  value: index.toString(),
                  groupValue: _correctOptionIndex,
                  onChanged: (value) {
                    setState(() {
                      _correctOptionIndex = value!;
                    });
                  },
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: _options[index],
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _options[index] = value;
                    },
                    validator: index < 2
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide at least 2 options';
                            }
                            return null;
                          }
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildTextAnswerSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: _correctAnswerController,
        decoration: const InputDecoration(
          labelText: 'Correct Answer',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter the correct answer';
          }
          return null;
        },
      ),
    );
  }
  
  Widget _buildEssaySection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: _minWordsController,
        decoration: const InputDecoration(
          labelText: 'Minimum Words Required',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return null; // Optional
          }
          final wordCount = int.tryParse(value);
          if (wordCount == null || wordCount < 0) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Question' : 'Add Question'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveQuestion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _questionTextController,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _questionType,
                      decoration: const InputDecoration(
                        labelText: 'Question Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text('Multiple Choice'),
                        ),
                        DropdownMenuItem(
                          value: 'text',
                          child: Text('Text Answer'),
                        ),
                        DropdownMenuItem(
                          value: 'essay',
                          child: Text('Essay'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _questionType = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _marksController,
                      decoration: const InputDecoration(
                        labelText: 'Marks',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final marks = int.tryParse(value);
                        if (marks == null || marks <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_questionType == 'multiple_choice') _buildMultipleChoiceSection(),
              if (_questionType == 'text') _buildTextAnswerSection(),
              if (_questionType == 'essay') _buildEssaySection(),
              const SizedBox(height: 16),
              if (_imageUrl != null) ...[
                const Text(
                  'Question Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('Failed to load image'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _imageUrl = null;
                    });
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove Image'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () {
                    // In a real app, this would open image picker or upload dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Image upload would be implemented in a real app'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Image'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 