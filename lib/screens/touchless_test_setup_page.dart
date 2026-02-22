import 'package:flutter/material.dart';

import '../data/touchless_test_questions.dart';
import '../models/touchless_task_question.dart';
import 'touchless_home.dart';

class TouchlessTestSetupPage extends StatelessWidget {
  const TouchlessTestSetupPage({super.key});

  void _startTest(BuildContext context) {
    final shuffledQuestions = List<TouchlessTaskQuestion>.of(
      kTouchlessTestQuestions,
    )..shuffle();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TouchlessHome(testQuestions: shuffledQuestions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5ECEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Touchless Hover Test',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Press Start Test to run a randomized 3-question task set.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 22),
              const Text(
                'Task Instructions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'You will be asked to select a specific button on the screen by hovering over it for ~2 seconds.',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Try to be as accurate as possible. If you select the wrong button, you can try again until you get it right.',
                style: const TextStyle(fontSize: 15),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startTest(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF256B6A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Test'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
