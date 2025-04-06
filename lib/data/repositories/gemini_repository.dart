import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/config/env_config.dart';
import '../../domain/repositories/chat_repository.dart';

class GeminiRepository implements ChatRepository {
  late GenerativeModel _model;
  ChatSession? _chat;
  String _currentApiKey = '';
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    // Get API key asynchronously
    final apiKey = await EnvConfig.getGeminiApiKey();

    // Only reinitialize if the API key has changed or not initialized yet
    if (apiKey != _currentApiKey || !_isInitialized) {
      print(
          'GeminiRepository: Initializing with API key: ${apiKey.isNotEmpty ? "[KEY SET]" : "[EMPTY KEY]"}');
      _currentApiKey = apiKey;

      if (apiKey.isEmpty) {
        print('GeminiRepository: Warning - Empty API key provided');
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
      );
      _chat = _model.startChat();
      _isInitialized = true;
    }
  }

  @override
  Future<String> sendMessage(String message) async {
    try {
      // Ensure we're initialized with the latest API key
      await initialize();

      if (_currentApiKey.isEmpty) {
        return 'API key not set. Please add your Gemini API key in Settings.';
      }

      final response = await _chat!.sendMessage(Content.text(message));

      // Check if response text is not null or empty
      if (response.text == null || response.text!.isEmpty) {
        print('Warning: Received empty response from Gemini API');
        return 'No response content';
      }

      return response.text!;
    } catch (e) {
      print('Error in Gemini API call: $e');

      if (e.toString().contains('unregistered callers') ||
          e.toString().contains('API Key')) {
        return 'Error: Invalid API key. Please check your Gemini API key in Settings.';
      }

      return 'Error communicating with the AI service: $e';
    }
  }
}
