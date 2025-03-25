import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onlineex/services/auth_service.dart';
import 'package:onlineex/screens/auth/register_screen.dart';
import 'package:onlineex/screens/student/student_dashboard.dart';
import 'package:onlineex/screens/teacher/teacher_dashboard.dart';
import 'package:onlineex/screens/admin/admin_dashboard.dart';
import 'package:onlineex/models/user_model.dart';
import 'package:onlineex/widgets/custom_button.dart';
import 'package:onlineex/widgets/custom_text_field.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specialCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTeacherLogin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _specialCodeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      UserModel? user;

      if (_emailController.text.trim() == 'admin@onlineex.com') {
        user = await authService.adminSignIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else if (_isTeacherLogin) {
        user = await authService.teacherSignIn(
          email: _emailController.text.trim(),
          specialCode: _specialCodeController.text.trim(),
        );
      } else {
        user = await authService.mockStudentSignIn(
          name: _emailController.text.split('@')[0],
          email: _emailController.text.trim(),
          className: "10th",
          division: "A",
        );
      }

      if (!mounted) return;

      if (user.role == 'student') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StudentDashboard()),
        );
      } else if (user.role == 'teacher') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeacherDashboard()),
        );
      } else if (user.role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleTeacherLogin() {
    setState(() {
      _isTeacherLogin = !_isTeacherLogin;
      _errorMessage = null;
    });
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No user found with this email';
    } else if (error.contains('wrong-password')) {
      return 'Incorrect password';
    } else if (error.contains('invalid-email')) {
      return 'Email is invalid';
    } else if (error.contains('user-disabled')) {
      return 'User has been disabled';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Try again later';
    } else if (error.contains('operation-not-allowed')) {
      return 'Operation not allowed';
    }
    return 'An error occurred during login';
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 64,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isTeacherLogin ? 'Teacher Login' : 'Welcome Back',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isTeacherLogin 
                                ? 'Enter your credentials and special code'
                                : 'Login to continue',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          CustomTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isTeacherLogin) ...[
                            CustomTextField(
                              controller: _specialCodeController,
                              hintText: 'Special Code',
                              prefixIcon: Icons.vpn_key_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your special code';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            CustomTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          _isLoading
                              ? const Center(
                                  child: SpinKitDoubleBounce(
                                    color: Colors.deepPurple,
                                    size: 40.0,
                                  ),
                                )
                              : CustomButton(
                                  text: _isTeacherLogin ? 'Teacher Login' : 'Login',
                                  onPressed: _login,
                                ),
                          const SizedBox(height: 16),
                          if (!_isTeacherLogin) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Don\'t have an account?'),
                                TextButton(
                                  onPressed: _navigateToRegister,
                                  child: const Text('Register'),
                                ),
                              ],
                            ),
                          ],
                          TextButton(
                            onPressed: _toggleTeacherLogin,
                            child: Text(
                              _isTeacherLogin
                                  ? 'Switch to Student/Admin Login'
                                  : 'Teacher Login',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 