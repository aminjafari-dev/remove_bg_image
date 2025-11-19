import 'dart:convert';

import 'package:http/http.dart' as http;

import 'background_removal_service.dart';

/// Extremely small helper for hitting the Flask auth endpoints.
class AuthService {
  AuthService({String? customBaseUrl})
      : baseUrl = customBaseUrl ?? BackgroundRemovalService.baseUrl;

  final String baseUrl;

  Future<String> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return payload['message'] as String? ?? 'Registered';
      }

      _logServerError(
        context: 'register',
        message: 'Server returned an error while registering a user.',
        error:
            'Status: ${response.statusCode}, Response: ${response.body.toString()}',
      );
      throw Exception(payload['message'] ?? 'Failed to register');
    } catch (e, stackTrace) {
      _logServerError(
        context: 'register',
        message: 'Unexpected error during registration flow.',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final payload = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return payload['token'] as String;
      }

      _logServerError(
        context: 'login',
        message: 'Server returned an error while logging in a user.',
        error:
            'Status: ${response.statusCode}, Response: ${response.body.toString()}',
      );
      throw Exception(payload['message'] ?? 'Failed to login');
    } catch (e, stackTrace) {
      _logServerError(
        context: 'login',
        message: 'Unexpected error during login flow.',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Helper logger to keep auth-related server errors consistent.
  ///
  /// Example:
  /// ```dart
  /// _logServerError(
  ///   context: 'login',
  ///   message: 'Invalid credentials supplied',
  ///   error: 'Status: 401, body: ...',
  /// );
  /// ```
  void _logServerError({
    required String context,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer()
      ..writeln('--- AuthService Error Log ---')
      ..writeln('Context: $context')
      ..writeln('Message: $message');

    if (error != null) {
      buffer.writeln('Error: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('StackTrace: $stackTrace');
    }

    buffer
      ..writeln('Timestamp: ${DateTime.now().toIso8601String()}')
      ..writeln('---------------------------------------');

    // ignore: avoid_print
    print(buffer.toString());
  }
}

