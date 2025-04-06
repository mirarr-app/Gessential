import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData image;
  final double imageSize;
  final Widget? actionButton;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.image,
    this.imageSize = 200,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image or icon
          Icon(
            image,
            size: imageSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Description
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.justify,
            ),
          ),

          if (actionButton != null) const SizedBox(height: 32),

          // Optional action button
          if (actionButton != null) actionButton!,
        ],
      ),
    );
  }
}
