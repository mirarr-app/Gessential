import 'dart:io';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  String _currentLocale = ''; // Keep track of current locale

  // Available language codes
  static const String englishLocaleId = 'en_US';
  static const String persianLocaleId = 'fa_IR';

  Future<bool> initialize() async {
    try {
      _isInitialized = await _speechToText.initialize(
        options: [if (Platform.isAndroid) SpeechToText.androidIntentLookup],
        onError: (error) => debugPrint('Speech recognition error: $error'),
      );
      if (_isInitialized) {
        // await printAvailableLocales();
        debugPrint('Speech recognition initialized successfully');
      } else {}
      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Get available locales
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();
    final locales = await _speechToText.locales();

    // Add Persian if not in the list (since we know it works)
    final hasPersian =
        locales.any((locale) => locale.localeId == persianLocaleId);
    if (!hasPersian) {
      locales.add(LocaleName(persianLocaleId, 'Persian'));
    }

    return locales;
  }

  /// Check if a specific locale is available
  Future<bool> isLocaleAvailable(String localeId) async {
    final locales = await getAvailableLocales();
    final isAvailable = locales.any((locale) => locale.localeId == localeId);
    return isAvailable;
  }

  Future<bool> startListening(
    void Function(String) onResult, {
    String localeId = englishLocaleId,
  }) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      if (!_isListening) {
        // Verify locale is available
        final isAvailable = await isLocaleAvailable(localeId);
        if (!isAvailable) {
          // Use default if selected is not available
          localeId = englishLocaleId;
        }

        _currentLocale = localeId;

        final started = await _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              onResult(result.recognizedWords);
              _isListening = false;
            }
          },
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          partialResults: false,
          onSoundLevelChange: (level) {
            // Uncomment for sound level debugging
            // print('Sound level: $level');
          },
        );
        _isListening = started;
      }
      return _isListening;
    } catch (e) {
      _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _speechToText.stop();
      } catch (e) {
        debugPrint('Error stopping speech recognition: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get currentLocale => _currentLocale;

  void dispose() {
    stopListening();
  }

  /// Print all available locales
  Future<void> printAvailableLocales() async {
    final locales = await getAvailableLocales();
    for (var locale in locales) {
      print('${locale.name} (${locale.localeId})');
    }
  }
}
