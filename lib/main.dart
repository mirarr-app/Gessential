import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Gessential/root_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/env_config.dart';
import 'core/services/settings_service.dart';
import 'core/constants/app_constants.dart';
import 'package:Gessential/presentation/screens/notes_screen.dart';
import 'package:Gessential/presentation/screens/onboarding/onboarding_screen.dart';

// Add this global variable to track onboarding status
bool onboardingCompleted = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  // Initialize app-wide services
  final settingsService = SettingsService.instance;

  int attempts = 0;
  while (!settingsService.isInitialized && attempts < 10) {
    await Future.delayed(const Duration(milliseconds: 100));
    attempts++;
  }


  // Initialize quick actions
  final QuickActions quickActions = QuickActions();
  await quickActions.setShortcutItems([
    const ShortcutItem(
      type: actionNewNote,
      localizedTitle: 'New Note',
      icon: 'ic_note',
    ),
    const ShortcutItem(
      type: actionVoiceNote,
      localizedTitle: 'Voice Note',
      icon: 'ic_mic',
    ),
  ]);

  // Handle quick action taps
  quickActions.initialize((type) {
    if (type == actionNewNote) {
      RootScreen.handleShortcut(type);
    } else if (type == actionVoiceNote) {
      // Navigate to voice note screen
      // This will be handled in the RootScreen
      RootScreen.handleShortcut(type);
    }
  });

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.material(
      navigatorKey: navigatorKey,
      title: 'GemRem',
      initialRoute: onboardingCompleted ? '/' : '/onboarding',
      routes: {
        '/': (context) => const RootScreen(),
        '/notes': (context) => const NotesScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
      theme: ShadThemeData(colorScheme: const ShadZincColorScheme.light(), brightness: Brightness.light, textTheme: ShadTextTheme.fromGoogleFont(
          GoogleFonts.poppins,
        ),),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(

        ),
        
        textTheme: ShadTextTheme.fromGoogleFont(
          GoogleFonts.poppins,
        ),
        
      ),
      
    );
  }
}
