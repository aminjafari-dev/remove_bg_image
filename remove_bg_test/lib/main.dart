import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_page.dart';
import 'services/background_removal_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Remover',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BackgroundRemoverPage(),
    );
  }
}

class BackgroundRemoverPage extends StatefulWidget {
  const BackgroundRemoverPage({super.key});

  @override
  State<BackgroundRemoverPage> createState() => _BackgroundRemoverPageState();
}

class _BackgroundRemoverPageState extends State<BackgroundRemoverPage> {
  File? _originalImage;
  File? _processedImage;
  bool _isProcessing = false;
  bool _isCheckingServer = false;
  String? _serverStatusMessage;
  final ImagePicker _picker = ImagePicker();
  final BackgroundRemovalService _service = BackgroundRemovalService();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _originalImage = File(pickedFile.path);
          _processedImage = null;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
    }
  }

  /// Check if the background removal server is accessible.
  ///
  /// This method verifies connectivity to the Python server before
  /// attempting to process images. It's useful for debugging connection issues.
  Future<void> _checkServerConnection() async {
    setState(() {
      _isCheckingServer = true;
      _serverStatusMessage = null;
    });

    try {
      final isHealthy = await _service.checkServerHealth();
      setState(() {
        _isCheckingServer = false;
        _serverStatusMessage = isHealthy
            ? '✅ Server is connected and running'
            : '❌ Server is not accessible. Make sure the Python server is running.';
      });
    } catch (e) {
      setState(() {
        _isCheckingServer = false;
        _serverStatusMessage = '❌ Error checking server: $e';
      });
    }
  }

  /// Remove background from the selected image using the local server.
  ///
  /// This method sends the image to the Python server for processing
  /// and saves the result locally. It handles errors and shows appropriate
  /// messages to the user.
  Future<void> _removeBackground() async {
    if (_originalImage == null) return;

    setState(() {
      _isProcessing = true;
      _processedImage = null;
    });

    try {
      // Check server health first
      final isHealthy = await _service.checkServerHealth();
      if (!isHealthy) {
        setState(() {
          _isProcessing = false;
        });
        _showErrorDialog(
          'Server is not accessible. Please make sure:\n\n'
          '1. The Python server is running (python server.py)\n'
          '2. The server URL is correct in background_removal_service.dart\n'
          '3. Your device/emulator can reach the server\n\n'
          'For Android emulator: http://10.0.2.2:5045\n'
          'For iOS simulator: http://localhost:5045\n'
          'For physical device: Use your computer\'s IP address (port 5045)',
        );
        return;
      }

      // Remove background using the service
      final outputBytes = await _service.removeBackground(_originalImage!);

      if (outputBytes != null && outputBytes.isNotEmpty) {
        // Save the processed image to a temporary file
        final tempDir = await getTemporaryDirectory();
        final outputPath =
            '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.png';
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(outputBytes);

        setState(() {
          _processedImage = outputFile;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
        _showErrorDialog(
          'Failed to remove background: No data received from server',
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Error removing background: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Remover'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AuthPage()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server connection check button
              ElevatedButton.icon(
                onPressed: _isCheckingServer ? null : _checkServerConnection,
                icon: _isCheckingServer
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_done),
                label: Text(
                  _isCheckingServer ? 'Checking...' : 'Check Server Connection',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_serverStatusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _serverStatusMessage!.contains('✅')
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _serverStatusMessage!.contains('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Text(
                    _serverStatusMessage!,
                    style: TextStyle(
                      color: _serverStatusMessage!.contains('✅')
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Image from Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              if (_originalImage != null) ...[
                const Text(
                  'Original Image:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_originalImage!, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _removeBackground,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Remove Background',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                if (_isProcessing)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Removing background...'),
                      ],
                    ),
                  ),
                if (_processedImage != null) ...[
                  const Text(
                    'Processed Image:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_processedImage!, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ] else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 100,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Select an image to get started',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
