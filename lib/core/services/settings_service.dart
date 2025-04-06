import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/speech_service.dart';

/// Service to manage app-wide settings
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();
  static const String _localeKey = 'selected_locale_id';
  SharedPreferences? _prefs;
  bool _initialized = false;

  SettingsService._internal() {
    print('SettingsService: Initializing...');
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      print('SettingsService: Loading SharedPreferences...');
      _prefs = await SharedPreferences.getInstance();

      // Load saved locale or use default
      final savedLocale = _prefs!.getString(_localeKey);

      if (savedLocale != null) {
        print('SettingsService: Found saved locale: $savedLocale');
        _selectedLocaleId = savedLocale;
        _localeController.add(savedLocale);
      } else {
        print(
            'SettingsService: No saved locale found, using default: $_selectedLocaleId');
      }

      _initialized = true;
      print('SettingsService: Initialization complete');
      notifyListeners();
    } catch (e) {
      print('SettingsService: Error initializing preferences: $e');
    }
  }

  // Language settings
  String _selectedLocaleId = SpeechService.englishLocaleId;
  final _localeController = StreamController<String>.broadcast();

  String get selectedLocaleId => _selectedLocaleId;
  Stream<String> get localeStream => _localeController.stream;
  bool get isInitialized => _initialized;

  Future<void> setSelectedLocaleId(String localeId) async {
    print('SettingsService: Setting locale to: $localeId');
    if (_selectedLocaleId != localeId) {
      _selectedLocaleId = localeId;
      _localeController.add(localeId);

      // Save to SharedPreferences
      if (_prefs != null) {
        try {
          final success = await _prefs!.setString(_localeKey, localeId);
          print('SettingsService: Saved locale to preferences: $success');
        } catch (e) {
          print('SettingsService: Error saving locale: $e');
        }
      } else {
        print(
            'SettingsService: SharedPreferences not initialized, cannot save locale');
      }

      notifyListeners();
    } else {
      print('SettingsService: Locale unchanged (already $localeId)');
    }
  }

  Future<void> clearSettings() async {
    if (_prefs != null) {
      try {
        await _prefs!.clear();
        print('SettingsService: All settings cleared');
        _selectedLocaleId = SpeechService.englishLocaleId;
        _localeController.add(_selectedLocaleId);
        notifyListeners();
      } catch (e) {
        print('SettingsService: Error clearing settings: $e');
      }
    }
  }

  @override
  void dispose() {
    _localeController.close();
    super.dispose();
  }
}
