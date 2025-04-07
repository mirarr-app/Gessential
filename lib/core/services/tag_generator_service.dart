import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/env_config.dart';

class TagGeneratorService {
  static final TagGeneratorService instance = TagGeneratorService._init();
  late GenerativeModel _model;
  String _currentApiKey = '';
  bool _isInitialized = false;

  TagGeneratorService._init();

  Future<void> _ensureInitialized() async {
    final apiKey = await EnvConfig.getGeminiApiKey();

    // Only reinitialize if the API key has changed or not initialized yet
    if (apiKey != _currentApiKey || !_isInitialized) {
      _currentApiKey = apiKey;

      if (apiKey.isEmpty) {
        _isInitialized = false;
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
      );
      _isInitialized = true;
    }
  }

  Future<List<String>> generateTags(String noteContent) async {
    try {
      await _ensureInitialized();

      if (!_isInitialized || _currentApiKey.isEmpty) {
        return ['note'];
      }


      final prompt =
          'Generate 3-5 relevant single-word tags for the following text. '
          'The tags should always be in english. '
          'Return only the tags separated by commas, without any other text: $noteContent';

      final content = Content.text(prompt);
      final response = await _model.generateContent([content]);

      // Check for null or empty response
      final tagsText = response.text;
      if (tagsText == null || tagsText.isEmpty) {
        return ['note'];
      }


      // Split the response into individual tags and clean them
      final tags = tagsText
          .split(',')
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // If no valid tags were extracted, return a default tag
      if (tags.isEmpty) {
        return ['note', _getCurrentDateTimeTag()];
      }

      // Add date-time tag to the list
      tags.add(_getCurrentDateTimeTag());

      return tags;
    } catch (e) {

      if (e.toString().contains('unregistered callers') ||
          e.toString().contains('API Key')) {
      }

      // Return a default tag if generation fails
      return ['note', _getCurrentDateTimeTag()];
    }
  }

  /// Returns a tag with the current date and time in the format "yyyy/MM/dd-HH:mm"
  String _getCurrentDateTimeTag() {
    final now = DateTime.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
