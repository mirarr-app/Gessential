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
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving API key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving API key: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).colorScheme.error,
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
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // API Key Section
                  const SectionHeader(title: 'API Key Settings'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Gemini API Key',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your Google Gemini API key to enable AI features. Without a valid API key, AI features like tag generation and chat will not work.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final Uri url = Uri.parse(
                                  'https://aistudio.google.com/app/apikey');
                              if (!await launchUrl(url)) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Could not open URL. Please visit aistudio.google.com/app/apikey manually'),
                                      duration: const Duration(seconds: 4),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Get an API key from Google AI Studio',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // API Key status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _hasApiKey 
                                ? Theme.of(context).colorScheme.secondaryContainer 
                                : Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _hasApiKey ? Icons.check_circle : Icons.error_outline,
                                  color: _hasApiKey 
                                    ? Theme.of(context).colorScheme.onSecondaryContainer 
                                    : Theme.of(context).colorScheme.onErrorContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _hasApiKey
                                      ? 'API key is set and ready to use'
                                      : 'No API key set - AI features unavailable',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _hasApiKey 
                                      ? Theme.of(context).colorScheme.onSecondaryContainer 
                                      : Theme.of(context).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _apiKeyController,
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              hintText: 'Enter your Gemini API key here',
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1,
                                ),
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                                      size: 20,
                                    ),
                                    tooltip: _obscureApiKey ? 'Show API key' : 'Hide API key',
                                    style: IconButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureApiKey = !_obscureApiKey;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.save_outlined, size: 20),
                                    tooltip: 'Save API key',
                                    style: IconButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _saveApiKey,
                                  ),
                                ],
                              ),
                            ),
                            obscureText: _obscureApiKey,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your API key is stored locally on your device for security.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Note Quick Launch',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enable quick launch of voice notes by holding the volume up button. This works even when the app is not open.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isAccessibilityServiceEnabled 
                                ? Theme.of(context).colorScheme.secondaryContainer 
                                : Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isAccessibilityServiceEnabled ? Icons.check_circle : Icons.error_outline,
                                  color: _isAccessibilityServiceEnabled 
                                    ? Theme.of(context).colorScheme.onSecondaryContainer 
                                    : Theme.of(context).colorScheme.onErrorContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isAccessibilityServiceEnabled
                                        ? 'Quick launch is enabled'
                                        : 'Quick launch is not enabled',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: _isAccessibilityServiceEnabled 
                                        ? Theme.of(context).colorScheme.onSecondaryContainer 
                                        : Theme.of(context).colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openAccessibilitySettings,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.settings_accessibility, size: 20),
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speech Recognition Language',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select the language to use for speech recognition throughout the app.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Language',
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1,
                                ),
                              ),
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
                                  SnackBar(
                                    content: const Text('Saving language preference...'),
                                    duration: const Duration(milliseconds: 500),
                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                  ),
                                );

                                // Save to settings service
                                await _settingsService.setSelectedLocaleId(newValue);

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Language preference saved'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Theme.of(context).colorScheme.secondary,
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'GitHub Repository',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'github.com/mirarr-app/Gessential',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            leading: Icon(
                              Icons.code_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onTap: () {
                              launchUrl(Uri.parse('https://github.com/mirarr-app/Gessential'));
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
