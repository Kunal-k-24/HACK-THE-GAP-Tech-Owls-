import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onlineex/models/user_model.dart';

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'https://api.onlineex.com/api';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Add admin credentials for development
  static const String _adminEmail = 'admin@onlineex.com';
  static const String _adminPassword = 'admin123';

  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;

  // Mock data for pending teacher approvals
  final List<Map<String, dynamic>> _pendingTeachers = [];
  final Map<String, String> _approvedTeacherCredentials = {
    // Format: email: specialCode
    'teacher@example.com': 'TEACH001',
  };

  // Getters
  UserModel? get currentUser => _currentUser;
  UserModel? get userModel => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get pendingTeachers => _pendingTeachers;

  AuthService() {
    _loadUserFromStorage();
  }

  // Load user from local storage
  Future<void> _loadUserFromStorage() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_tokenKey);
      final storedUserData = prefs.getString(_userKey);

      if (storedToken != null && storedUserData != null) {
        _token = storedToken;
        final userData = json.decode(storedUserData) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(userData);
      }
    } catch (e) {
      debugPrint('Error loading user from storage: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save user to local storage
  Future<void> _saveUserToStorage(UserModel user, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, json.encode(user.toJson()));
    } catch (e) {
      debugPrint('Error saving user to storage: $e');
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        _token = token;
        _currentUser = user;

        await _saveUserToStorage(user, token);
        notifyListeners();
        return user;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to sign in');
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register with email and password
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'name': displayName,
          'role': role,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        _token = token;
        _currentUser = user;

        await _saveUserToStorage(user, token);
        notifyListeners();
        return user;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to register');
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    if (_currentUser == null) {
      await _loadUserFromStorage();
    }
    return _currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);

      _token = null;
      _currentUser = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<UserModel> updateProfile(UserModel updatedUser) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/users/${updatedUser.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(updatedUser.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        _currentUser = user;
        await _saveUserToStorage(user, _token!);
        notifyListeners();
        return user;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin authentication
  Future<UserModel> adminSignIn({
    required String email,
    required String password,
  }) async {
    if (email != _adminEmail || password != _adminPassword) {
      throw Exception('Invalid admin credentials');
    }

    final user = UserModel(
      id: 'admin_id',
      email: _adminEmail,
      name: 'Admin',
      role: 'admin',
      isActive: true,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    _token = 'admin_token';
    await _saveUserToStorage(user, _token!);
    notifyListeners();
    return user;
  }

  // Teacher registration request
  Future<void> requestTeacherRegistration({
    required String name,
    required String email,
    required String password,
    required String qualifications,
  }) async {
    if (_pendingTeachers.any((teacher) => teacher['email'] == email)) {
      throw Exception('Registration request already pending');
    }

    _pendingTeachers.add({
      'id': 'teacher_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'email': email,
      'password': password,
      'qualifications': qualifications,
      'requestDate': DateTime.now(),
      'status': 'pending'
    });

    notifyListeners();
  }

  // Admin approve teacher
  Future<String> approveTeacher(String teacherId) async {
    final teacherIndex = _pendingTeachers.indexWhere((t) => t['id'] == teacherId);
    if (teacherIndex == -1) {
      throw Exception('Teacher not found');
    }

    final teacher = _pendingTeachers[teacherIndex];
    final specialCode = 'TEACH${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    _approvedTeacherCredentials[teacher['email']] = specialCode;
    _pendingTeachers.removeAt(teacherIndex);
    
    notifyListeners();
    return specialCode;
  }

  // Teacher sign in with special code
  Future<UserModel> teacherSignIn({
    required String email,
    required String specialCode,
  }) async {
    if (!_approvedTeacherCredentials.containsKey(email) || 
        _approvedTeacherCredentials[email] != specialCode) {
      throw Exception('Invalid teacher credentials');
    }

    final user = UserModel(
      id: 'teacher_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: 'Teacher',
      role: 'teacher',
      isActive: true,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    _token = 'teacher_token_${DateTime.now().millisecondsSinceEpoch}';
    await _saveUserToStorage(user, _token!);
    notifyListeners();
    return user;
  }

  // Mock student sign in
  Future<UserModel> mockStudentSignIn({
    required String name,
    required String email,
    required String className,
    required String division,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    final user = UserModel(
      id: 'student_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: 'student',
      className: className,
      division: division,
      isActive: true,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    _token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

    return user;
  }
} 