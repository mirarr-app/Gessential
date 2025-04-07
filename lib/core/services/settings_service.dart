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
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Load saved locale or use default
      final savedLocale = _prefs!.getString(_localeKey);

      if (savedLocale != null) {
        _selectedLocaleId = savedLocale;
        _localeController.add(savedLocale);
      } else {
        debugPrint(
            'SettingsService: No saved locale found, using default: $_selectedLocaleId');
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsService: Error initializing preferences: $e');
    }
  }

  // Language settings
  String _selectedLocaleId = SpeechService.englishLocaleId;
  final _localeController = StreamController<String>.broadcast();

  String get selectedLocaleId => _selectedLocaleId;
  Stream<String> get localeStream => _localeController.stream;
  bool get isInitialized => _initialized;

  Future<void> setSelectedLocaleId(String localeId) async {
    if (_selectedLocaleId != localeId) {
      _selectedLocaleId = localeId;
      _localeController.add(localeId);

      // Save to SharedPreferences
      if (_prefs != null) {
        try {
          final success = await _prefs!.setString(_localeKey, localeId);
          debugPrint('SettingsService: Saved locale to preferences: $success');
        } catch (e) {
          debugPrint('SettingsService: Error saving locale: $e');
        }
      } else {
        debugPrint(
            'SettingsService: SharedPreferences not initialized, cannot save locale');
      }

      notifyListeners();
    } else {
      debugPrint('SettingsService: Locale unchanged (already $localeId)');
    }
  }

  Future<void> clearSettings() async {
    if (_prefs != null) {
      try {
        await _prefs!.clear();
        _selectedLocaleId = SpeechService.englishLocaleId;
        _localeController.add(_selectedLocaleId);
        notifyListeners();
      } catch (e) {
        debugPrint('SettingsService: Error clearing settings: $e');
      }
    }
  }

  @override
  void dispose() {
    _localeController.close();
    super.dispose();
  }
}
