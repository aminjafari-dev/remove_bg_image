import 'package:flutter/material.dart';

import 'services/auth_service.dart';

/// Basic login/register screen that talks to the Flask server.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _statusMessage;
  String? _token;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _token = null;
    });
    try {
      if (_isLoginMode) {
        final token = await _authService.login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        setState(() {
          _token = token;
          _statusMessage = 'Logged in successfully.';
        });
      } else {
        final msg = await _authService.register(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        setState(() {
          _statusMessage = msg;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = e.toString();
      });
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
        title: Text(_isLoginMode ? 'Login' : 'Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) =>
                    value == null || value.length < 4 ? 'Min 4 chars' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLoginMode ? 'Login' : 'Register'),
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _statusMessage = null;
                          _token = null;
                        });
                      },
                child: Text(
                  _isLoginMode
                      ? 'Need an account? Register'
                      : 'Have an account? Login instead',
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.toLowerCase().contains('error')
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
              if (_token != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  'Token: $_token',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

