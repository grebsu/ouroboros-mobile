import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ouroboros_mobile/models/loading_state.dart'; // Import the new LoadingState

class StudyGuideLoadingScreen extends StatefulWidget {
  final ValueNotifier<LoadingState> loadingStateNotifier;

  const StudyGuideLoadingScreen({
    super.key,
    required this.loadingStateNotifier,
  });

  @override
  State<StudyGuideLoadingScreen> createState() => _StudyGuideLoadingScreenState();
}

class _StudyGuideLoadingScreenState extends State<StudyGuideLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDarkMode ? 'logo/logo-modo-escuro.png' : 'logo/logo.png'; // Changed to .png

    return ValueListenableBuilder<LoadingState>(
      valueListenable: widget.loadingStateNotifier,
      builder: (context, loadingState, child) {
        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    loadingState.currentStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 20), // Spacing after status text

                  Row( // New Row for logo and progress bar
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _controller,
                        child: Image.asset(
                          logoAsset,
                          height: 60, // Smaller logo
                          width: 60,
                        ),
                      ),
                      const SizedBox(width: 20), // Spacing between logo and progress bar
                      Expanded(
                        child: LinearProgressIndicator(
                          value: loadingState.progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Matérias: ${loadingState.currentSubjects}/${loadingState.totalSubjects}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  Text(
                    'Tópicos: ${loadingState.currentTopics}', // Only show currentTopics
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}