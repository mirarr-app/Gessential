import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/speech_service.dart';
import '../../core/config/env_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService.instance;
  final SpeechService _speechService = SpeechService();
  final TextEditingController _apiKeyController = TextEditingController();
  static const platform =
      MethodChannel('com.mirarrapp.Gessential/accessibility');
  List<LocaleName> _availableLocales = [];
  String _selectedLocaleId = SpeechService.englishLocaleId;
  bool _isLoading = true;
  bool _isAccessibilityServiceEnabled = false;
  bool _obscureApiKey = true;
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Get the current locale from settings
    _selectedLocaleId = _settingsService.selectedLocaleId;

    // Load available languages
    final locales = await _speechService.getAvailableLocales();

    // Check accessibility service status
    final isEnabled =
        await platform.invokeMethod<bool>('isAccessibilityServiceEnabled') ??
            false;

    // Load saved API key
    final apiKey = await EnvConfig.getGeminiApiKey();
    _apiKeyController.text = apiKey;
    final hasKey = await EnvConfig.hasValidGeminiApiKey();

    if (mounted) {
      setState(() {
        _availableLocales = locales;
        _isAccessibilityServiceEnabled = isEnabled;
        _hasApiKey = hasKey;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();

    // Show a loading indicator
    setState(() => _isLoading = true);

    try {
      // Save the API key
      await EnvConfig.setGeminiApiKey(apiKey);
      final hasKey = await EnvConfig.hasValidGeminiApiKey();

      // Display different messages based on whether the key is cleared or set
      String message;
      if (apiKey.isEmpty) {
        message = 'API key cleared';
      } else {
        message = 'API key saved successfully';
      }

      if (mounted) {
        setState(() {
          _hasApiKey = hasKey;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving API key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving API key: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAccessibilitySettings() async {
    await platform.invokeMethod('openAccessibilitySettings');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // API Key Section
                  const SectionHeader(title: 'API Key Settings'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Google Gemini API Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your Google Gemini API key to enable AI features. Without a valid API key, AI features like tag generation and chat will not work.',
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse(
                                  'https://aistudio.google.com/app/apikey');
                              if (!await launchUrl(url)) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Could not open URL. Please visit aistudio.google.com/app/apikey manually'),
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'Get an API key from Google AI Studio',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // API Key status indicator
                          Row(
                            children: [
                              Icon(
                                _hasApiKey
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color:
                                    _hasApiKey ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _hasApiKey
                                    ? 'API key is set and ready to use'
                                    : 'No API key set - AI features unavailable',
                                style: TextStyle(
                                  color:
                                      _hasApiKey ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _apiKeyController,
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              hintText: 'Enter your Gemini API key here',
                              border: const OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _obscureApiKey
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    tooltip: _obscureApiKey
                                        ? 'Show API key'
                                        : 'Hide API key',
                                    onPressed: () {
                                      setState(() {
                                        _obscureApiKey = !_obscureApiKey;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.save),
                                    tooltip: 'Save API key',
                                    onPressed: _saveApiKey,
                                  ),
                                ],
                              ),
                            ),
                            obscureText: _obscureApiKey,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Your API key is stored locally on your device for security.',
                                  style: TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Accessibility Section
                  const SectionHeader(title: 'Accessibility'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Voice Note Quick Launch',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enable quick launch of voice notes by holding the volume up button. This works even when the app is not open.',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                _isAccessibilityServiceEnabled
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: _isAccessibilityServiceEnabled
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isAccessibilityServiceEnabled
                                      ? 'Quick launch is enabled'
                                      : 'Quick launch is not enabled',
                                  style: TextStyle(
                                    color: _isAccessibilityServiceEnabled
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openAccessibilitySettings,
                            icon: const Icon(Icons.settings_accessibility),
                            label: Text(
                              _isAccessibilityServiceEnabled
                                  ? 'Manage Quick Launch'
                                  : 'Enable Quick Launch',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Language Section
                  const SectionHeader(title: 'Language Settings'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Speech Recognition Language',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select the language to use for speech recognition throughout the app.',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Language',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedLocaleId,
                            items: _availableLocales.map((locale) {
                              return DropdownMenuItem(
                                value: locale.localeId,
                                child: Text(locale.name),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
                              if (newValue != null) {
                                setState(() {
                                  _selectedLocaleId = newValue;
                                });

                                // Show saving indicator
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Saving language preference...'),
                                    duration: Duration(milliseconds: 500),
                                  ),
                                );

                                // Save to settings service
                                await _settingsService
                                    .setSelectedLocaleId(newValue);

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Language preference saved'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info Section
                  const SectionHeader(title: 'App Information'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: const Text('GitHub Repository'),
                            subtitle:
                                const Text('github.com/mirarr-app/Gessential'),
                            leading: const Icon(Icons.code),
                            onTap: () {
                              // Add link to GitHub repo if needed
                              launchUrl(Uri.parse(
                                  'https://github.com/mirarr-app/Gessential'));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
