import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // Save that onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: const [
                  // Welcome Page
                  OnboardingPage(
                    title: 'Welcome to Gessential',
                    description:
                        'Gessential is an AI note-taking app powered by Google Gemini. Create, organize, and enhance your notes with the power of AI.',
                    image: Icons.note_alt,
                    imageSize: 120,
                  ),

                  // API Key Page
                  OnboardingPage(
                    title: 'Gemini API Key',
                    description:
                        'To use Gessential, you\'ll need a Google Gemini API key.\n\n'
                        'The free tier has usage limits but Google may train its AI on your data.\n'
                        'If you use a paid API key, Google states they don\'t use your data for training.\n\n'
                        'The app won\'t work without an API key. You can get your API key from Google AI Studio and add it in the Settings.',
                    image: Icons.key,
                    imageSize: 80,
                 
                  ),
                ],
              ),
            ),

            // Navigation controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (hidden on first page)
                  _currentPage == 0
                      ? const SizedBox(width: 80)
                      : TextButton(
                          onPressed: _onPreviousPage,
                          child: const Text('Back'),
                        ),

                  // Page indicator
                  Row(
                    children: List.generate(
                      _numPages,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentPage
                              ? Colors.grey.shade300
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),

                  // Next/Finish button
                  TextButton(
                    onPressed: _onNextPage,
                    child:
                        Text(_currentPage == _numPages - 1 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
