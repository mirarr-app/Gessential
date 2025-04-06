import 'package:shared_preferences/shared_preferences.dart';

class EnvConfig {
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _firstRunKey = 'first_run_completed';

  static Future<String> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKeyKey) ?? '';
  }

  static Future<void> setGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKeyKey, apiKey);
  }

  /// Checks if a Gemini API key is available
  static Future<bool> hasValidGeminiApiKey() async {
    final apiKey = await getGeminiApiKey();
    return apiKey.isNotEmpty;
  }

  /// Checks if this is the first run of the app
  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstRunKey) ?? false);
  }

  /// Marks the first run as completed
  static Future<void> markFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRunKey, true);
  }

  // We'll keep the init method for backward compatibility but it won't do anything with the .env file
  static Future<void> init() async {
    // No need to load .env anymore as we're using SharedPreferences

    // Check if this is first run and mark it as completed if it is
    if (await isFirstRun()) {
      await markFirstRunCompleted();
    }
  }
}
