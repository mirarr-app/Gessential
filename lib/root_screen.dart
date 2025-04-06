import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Gessential/presentation/screens/home_screen.dart';
import 'package:Gessential/presentation/screens/notes_screen.dart';
import 'package:Gessential/core/constants/app_constants.dart';
import 'package:Gessential/main.dart';
import 'package:Gessential/core/config/env_config.dart';
import 'package:Gessential/presentation/screens/onboarding/onboarding_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  static void handleShortcut(String type) {
    // This will be called from main.dart when a shortcut is tapped
    // The actual navigation will be handled by the RootScreen instance
    if (type == actionNewNote) {
      _navigateToNewNote();
    } else if (type == actionVoiceNote) {
      _navigateToVoiceNote();
    }
  }

  static void _navigateToNewNote() {
    MainApp.navigatorKey.currentState?.pushNamed('/notes');
  }

  static void _navigateToVoiceNote() {
    MainApp.navigatorKey.currentState
        ?.pushReplacementNamed('/notes', arguments: {'startRecording': true});
  }

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;
  static const platform =
      MethodChannel('com.mirarrapp.Gessential/accessibility');

  final List<Widget> _screens = const [
    HomeScreen(),
    NotesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _checkInitialAction();
    _checkApiKey();
  }

  // Check if we have an API key, if not and onboarding was marked as completed,
  // we may need to show onboarding again
  Future<void> _checkApiKey() async {
    if (onboardingCompleted) {
      final hasApiKey = await EnvConfig.hasValidGeminiApiKey();
      if (!hasApiKey) {
        // If we don't have an API key but onboarding was marked completed,
        // we should show onboarding again
        if (mounted) {
          Future.delayed(Duration.zero, () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          });
        }
      }
    }
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'triggerVoiceNote') {
        _handleVoiceNoteAction();
        return null;
      }
    });
  }

  Future<void> _checkInitialAction() async {
    try {
      final String? action = await platform.invokeMethod('getInitialAction');
      if (action == 'action_voice_note') {
        _handleVoiceNoteAction();
      }
    } catch (e) {
      debugPrint('Error checking initial action: $e');
    }
  }

  void _handleVoiceNoteAction() {
    // Switch to notes tab and start recording
    setState(() {
      _selectedIndex = 1; // Notes tab
    });

    // Add a small delay to ensure the screen has loaded
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.pushReplacementNamed(context, '/notes',
          arguments: {'startRecording': true});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _screens[_selectedIndex],
      ),
    );
  }
}
