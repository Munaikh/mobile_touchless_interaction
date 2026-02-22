import 'package:flutter/material.dart';

import '../data/test_questions.dart';
import '../models/task_question.dart';
import '../widgets/touchless_ring.dart';
import 'test_report_page.dart';

class TestPage extends StatefulWidget {
  TestPage({super.key, required List<TaskQuestion> testQuestions})
    : testQuestions = testQuestions.isEmpty ? kTestQuestions : testQuestions;

  final List<TaskQuestion> testQuestions;

  static const List<String> labels = [
    'Call',
    'Music',
    'Map',
    'Camera',
    'Message',
    'Torch',
  ];

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late int _currentTaskIndex;
  late List<int> _questionAttempts;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _currentTaskIndex = 0;
    _questionAttempts = List<int>.filled(widget.testQuestions.length, 0);
  }

  bool get _isFinished => _currentTaskIndex >= widget.testQuestions.length;

  void _handleActivation(int index) {
    final selectedLabel = TestPage.labels[index];
    if (_isFinished) {
      _showMessage('Activated $selectedLabel');
      return;
    }

    _questionAttempts[_currentTaskIndex] += 1;
    final currentTask = widget.testQuestions[_currentTaskIndex];
    if (selectedLabel.toLowerCase() != currentTask.targetLabel.toLowerCase()) {
      _failedAttempts += 1;
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
      _showReportPage();
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

  void _showReportPage() {
    final firstAttemptCorrectCount = _questionAttempts
        .where((attemptCount) => attemptCount == 1)
        .length;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestReportPage(
          totalQuestions: widget.testQuestions.length,
          firstAttemptCorrectCount: firstAttemptCorrectCount,
          failedAttempts: _failedAttempts,
          questions: widget.testQuestions,
          attemptsPerQuestion: _questionAttempts,
        ),
      ),
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
    final items = TestPage.labels
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
