import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:onlineex/models/exam_submission_model.dart';
import 'package:onlineex/services/exam_service.dart';

class ProctoringService extends ChangeNotifier {
  final ExamService _examService;
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  Timer? _monitoringTimer;
  String _submissionId = '';
  String _examId = '';
  String _studentId = '';
  bool _isMonitoring = false;
  int _consecutiveWarnings = 0;
  int _lastWarningCount = 0;
  
  final Uuid _uuid = const Uuid();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool get isMonitoring => _isMonitoring;
  CameraController? get cameraController => _cameraController;
  
  ProctoringService(this._examService) {
    _initFaceDetector();
  }

  void _initFaceDetector() {
    _faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> initializeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    // Use front camera if available
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    notifyListeners();
  }

  Future<void> startMonitoring(String submissionId, String examId, String studentId) async {
    if (_isMonitoring) return;
    
    _submissionId = submissionId;
    _examId = examId;
    _studentId = studentId;
    _isMonitoring = true;
    _consecutiveWarnings = 0;
    _lastWarningCount = 0;
    
    // Initialize camera if not done already
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await initializeCamera();
    }
    
    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _monitorFace();
    });
    
    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
    
    notifyListeners();
  }

  Future<void> _monitorFace() async {
    if (!_isMonitoring || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      
      // Process with ML Kit
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector!.processImage(inputImage);
      
      if (faces.isEmpty) {
        // No face detected
        await _recordWarning(
          'face_not_detected', 
          'No face detected during the exam',
          image.path,
        );
      } else if (faces.length > 1) {
        // Multiple faces detected
        await _recordWarning(
          'multiple_faces', 
          'Multiple faces detected during the exam',
          image.path,
        );
      } else {
        // Face detected, check orientation
        final face = faces.first;
        if (face.headEulerAngleY != null && 
            (face.headEulerAngleY! > 30 || face.headEulerAngleY! < -30)) {
          // Face looking away
          await _recordWarning(
            'face_looking_away', 
            'Face detected looking away from screen',
            image.path,
          );
        }
      }
      
      // Clean up temporary image file
      await File(image.path).delete();
    } catch (e) {
      print('Error during face monitoring: $e');
    }
  }

  Future<void> _recordWarning(String type, String description, String imagePath) async {
    try {
      // Only record if this is a new warning (not consecutive of the same type)
      final submission = await _examService.getExamSubmission(_submissionId);
      if (submission == null || submission.status != 'in_progress') {
        return;
      }
      
      // Check if we should increment warnings or just replace the last one
      if (submission.warnings.length > _lastWarningCount) {
        _lastWarningCount = submission.warnings.length;
        _consecutiveWarnings++;
      }
      
      // Upload evidence if connected
      String? evidenceUrl;
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          final ref = _storage.ref().child(
              'warnings/${_examId}_${_studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(file);
          evidenceUrl = await ref.getDownloadURL();
        }
      } catch (e) {
        print('Error uploading evidence: $e');
      }
      
      final warning = WarningModel(
        id: _uuid.v4(),
        type: type,
        description: description,
        timestamp: DateTime.now(),
        evidence: evidenceUrl,
      );
      
      await _examService.recordWarning(_submissionId, warning);
      
      // Check if we've reached 5 warnings and should terminate the exam
      if (submission.warnings.length >= 4) { // Already has 4, this is the 5th
        await stopMonitoring();
        
        // The exam termination is handled in recordWarning in the ExamService
      }
    } catch (e) {
      print('Error recording warning: $e');
    }
  }

  // Method to record a warning when the user changes tabs or minimizes the window
  Future<void> recordTabChange() async {
    if (!_isMonitoring) return;
    
    await _recordWarning(
      'tab_change',
      'User changed tabs or minimized the window during exam',
      '',
    );
  }

  @override
  void dispose() {
    stopMonitoring();
    _faceDetector?.close();
    super.dispose();
  }
} 