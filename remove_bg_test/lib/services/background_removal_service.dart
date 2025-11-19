import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service class for communicating with the background removal server.
///
/// This service handles HTTP requests to the local Python server
/// that processes images to remove backgrounds.
///
/// Usage example:
/// ```dart
/// final service = BackgroundRemovalService();
/// final result = await service.removeBackground(imageFile);
/// if (result != null) {
///   // Use the processed image bytes
/// }
/// ```
class BackgroundRemovalService {
  /// Base URL for the background removal server.
  ///
  /// Default values:
  /// - Android Emulator: http://10.0.2.2:5045
  /// - iOS Simulator: http://localhost:5045
  /// - Physical Device: http://<your-computer-ip>:5045
  ///
  /// Note: Port 5045 is used to avoid conflict with macOS AirPlay Receiver on port 5000.
  /// For physical devices, use your computer's IP address (found in server startup message).
  /// You can change this to match your server configuration.
  static const String baseUrl = 'http://192.168.161.33:5045';

  /// Health check endpoint to verify server is running.
  ///
  /// Returns true if server is accessible, false otherwise.
  /// This is useful to check server connectivity before processing images.
  Future<bool> checkServerHealth() async {
    try {
      print('Checking server health at: $baseUrl/health');
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 15));

      print('Server health response: ${response.statusCode}');
      return response.statusCode == 200;
    } on SocketException catch (e) {
      // Network error - server might not be running
      print('SocketException: $e');
      print('Make sure:');
      print('1. Server is running on $baseUrl');
      print('2. Device and computer are on the same Wi-Fi network');
      print('3. Firewall allows connections on port 5045');
      return false;
    } on TimeoutException catch (e) {
      // Server didn't respond in time
      print('TimeoutException: $e');
      print('Server at $baseUrl did not respond within 15 seconds');
      print('Check if server is running and accessible');
      return false;
    } catch (e) {
      _logServerError(
        context: 'checkServerHealth',
        message: 'Unexpected error while checking server health.',
        error: e,
      );
      // Other errors
      return false;
    }
  }

  /// Remove background from an image file.
  ///
  /// Takes an image file and sends it to the server for processing.
  /// Returns the processed image bytes if successful, null otherwise.
  ///
  /// Parameters:
  /// - [imageFile]: The image file to process
  ///
  /// Returns:
  /// - Uint8List: Processed image bytes (PNG format)
  /// - null: If processing failed
  ///
  /// Throws:
  /// - Exception: If network error or server error occurs
  Future<Uint8List?> removeBackground(File imageFile) async {
    try {
      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/remove-background'),
      );

      // Add image file to request
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFile.path.split('/').last,
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120), // Increased timeout for image processing
      );

      // Check response status
      if (streamedResponse.statusCode == 200) {
        // Read response bytes
        final responseBytes = await streamedResponse.stream.toBytes();
        return responseBytes;
      } else {
        // Read error message from response
        final errorResponse = await streamedResponse.stream.bytesToString();
        _logServerError(
          context: 'removeBackground',
          message:
              'Server responded with a non-success status code during stream upload.',
          error: 'Status: ${streamedResponse.statusCode}, Body: $errorResponse',
        );
        throw Exception(
          'Server error: ${streamedResponse.statusCode} - $errorResponse',
        );
      }
    } catch (e, stackTrace) {
      _logServerError(
        context: 'removeBackground',
        message:
            'Failed to complete background removal request. Verify server logs for more details.',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to remove background: $e');
    }
  }

  /// Remove background from an image using base64 encoding.
  ///
  /// Alternative method that uses base64 encoding for image transfer.
  /// This can be useful if you need to send image data as JSON.
  ///
  /// Parameters:
  /// - [imageBytes]: The image bytes to process
  ///
  /// Returns:
  /// - Uint8List: Processed image bytes (PNG format)
  /// - null: If processing failed
  Future<Uint8List?> removeBackgroundBase64(Uint8List imageBytes) async {
    try {
      // Convert image bytes to base64
      final base64Image = base64Encode(imageBytes);

      // Create request body
      final requestBody = jsonEncode({
        'image': 'data:image/jpeg;base64,$base64Image',
      });

      // Send POST request
      final response = await http
          .post(
            Uri.parse('$baseUrl/remove-background-base64'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 120));

      // Check response status
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          // Extract base64 image data
          final base64Result = responseData['image'] as String;
          final base64Data = base64Result.split(',')[1];

          // Decode base64 to bytes
          return base64Decode(base64Data);
        } else {
          _logServerError(
            context: 'removeBackgroundBase64',
            message:
                'Server returned a success HTTP status but indicated a failure in payload.',
            error: responseData['error'],
          );
          throw Exception('Server returned error: ${responseData['error']}');
        }
      } else {
        _logServerError(
          context: 'removeBackgroundBase64',
          message: 'Server responded with non-success HTTP status code.',
          error:
              'Status: ${response.statusCode}, Body: ${response.body.toString()}',
        );
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _logServerError(
        context: 'removeBackgroundBase64',
        message:
            'Failed to complete base64 background removal request. Inspect server logs.',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to remove background: $e');
    }
  }

  /// Helper logger to standardize error outputs from server interactions.
  ///
  /// Example:
  /// ```dart
  /// _logServerError(
  ///   context: 'removeBackground',
  ///   message: 'Server responded with 500',
  ///   error: responseBody,
  /// );
  /// ```
  void _logServerError({
    required String context,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer()
      ..writeln('--- BackgroundRemovalService Error Log ---')
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
      ..writeln('--------------------------------------------');

    // ignore: avoid_print
    print(buffer.toString());
  }
}
