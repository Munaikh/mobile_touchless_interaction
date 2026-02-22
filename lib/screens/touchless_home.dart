import 'package:flutter/material.dart';

import '../data/touchless_test_questions.dart';
import '../models/touchless_task_question.dart';
import '../widgets/touchless_ring.dart';

class TouchlessHome extends StatefulWidget {
  TouchlessHome({super.key, required List<TouchlessTaskQuestion> testQuestions})
    : testQuestions = testQuestions.isEmpty
          ? kTouchlessTestQuestions
          : testQuestions;

  final List<TouchlessTaskQuestion> testQuestions;

  static const List<String> labels = [
    'Call',
    'Music',
    'Map',
    'Camera',
    'Message',
    'Torch',
  ];

  @override
  State<TouchlessHome> createState() => _TouchlessHomeState();
}

class _TouchlessHomeState extends State<TouchlessHome> {
  late int _currentTaskIndex;

  @override
  void initState() {
    super.initState();
    _currentTaskIndex = 0;
  }

  bool get _isFinished => _currentTaskIndex >= widget.testQuestions.length;

  void _handleActivation(int index) {
    final selectedLabel = TouchlessHome.labels[index];
    if (_isFinished) {
      _showMessage('Activated $selectedLabel');
      return;
    }

    final currentTask = widget.testQuestions[_currentTaskIndex];
    if (selectedLabel.toLowerCase() != currentTask.targetLabel.toLowerCase()) {
      _showMessage(
        'Selected $selectedLabel. Current task: ${currentTask.targetLabel}.',
      );
      return;
    }

    final nextTask = _currentTaskIndex + 1;
    setState(() {
      _currentTaskIndex = nextTask;
    });
    _showMessage('Correct: $selectedLabel');

    if (nextTask >= widget.testQuestions.length) {
      _showCompletionDialog();
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Test Completed'),
          content: const Text('You completed all randomized tasks.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop();
              },
              child: const Text('Back to Start'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard() {
    if (_isFinished) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFD6EEEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8FC9C1)),
        ),
        child: const Text(
          'All tasks done. You can keep interacting or go back.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
    }

    final currentTask = widget.testQuestions[_currentTaskIndex];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3DEDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_currentTaskIndex + 1}/${widget.testQuestions.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF256B6A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            currentTask.prompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = TouchlessHome.labels
        .map((label) => Text(label))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFE5ECEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Touchless Hover',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tilt the device to move the cursor. Hold over a button\nfor a moment to activate it with haptics.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildTaskCard(),
              const SizedBox(height: 12),
              Expanded(
                child: TouchlessRing(
                  fastDwellDuration: const Duration(seconds: 2),
                  items: items,
                  onActivate: _handleActivation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
