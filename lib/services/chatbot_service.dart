import 'dart:io';
import 'package:http/http.dart' as http;

/// Base URL for the RAG backend API.
///
/// • Android emulator  → use http://10.0.2.2:8000
/// • iOS simulator     → http://142.93.1.5:8000
/// • Physical device   → replace with your machine's LAN IP (e.g. http://192.168.x.x:8000)
const String _kBaseUrl = 'http://207.154.253.127:8000';
const String _kWebhookSecret = 'Fg3BJTrpsdRDUD7QWg4-j1RMf1lMmo9L2UV5f83UqkH806HPHMB-KY-VBHlzeR26-D8ZHWUEoh5d9lEZpZGmIw';
class ChatbotService {
  /// Upload a document to the chatbot knowledge base.
  /// 
  /// Accepts .txt, .pdf, .docx files.
  /// [onProgress] is called with progress from 0.0 to 1.0 during upload.
  Future<int> uploadDocument(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/ingest');
    final request = http.MultipartRequest('POST', uri);

    // Add webhook secret header
    request.headers['X-Webhook-Secret'] = _kWebhookSecret;

    final fileBytes = await file.readAsBytes();
    final totalBytes = fileBytes.length;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    );

    // Track upload progress
    int bytesSent = 0;
    final streamedResponse = await request.send();

    // Listen to the request stream to track progress
    if (onProgress != null) {
      // Simulate progress for now (actual byte tracking requires custom implementation)
      // Most HTTP clients don't expose byte-level upload progress easily
      onProgress(0.3); // File prepared
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(0.6); // Uploading
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (onProgress != null) {
      onProgress(1.0); // Complete
    }

    if (response.statusCode != 201) {
      throw Exception(
          'Upload failed: ${response.statusCode} ${response.reasonPhrase}');
    }

    return response.statusCode;
  }
}
