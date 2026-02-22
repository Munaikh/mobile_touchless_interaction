import 'dart:async';

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
  late DateTime _sessionStartTime;
  int _wrongTargetActivations = 0;
  bool _isCompletingSession = false;

  @override
  void initState() {
    super.initState();
    _currentTaskIndex = 0;
    _questionAttempts = List<int>.filled(widget.testQuestions.length, 0);
    _sessionStartTime = DateTime.now();
  }

  bool get _isFinished => _currentTaskIndex >= widget.testQuestions.length;

  void _handleActivation(int index) {
    if (_isCompletingSession) {
      return;
    }

    final selectedLabel = TestPage.labels[index];
    if (_isFinished) {
      return;
    }

    _questionAttempts[_currentTaskIndex] += 1;
    final currentTask = widget.testQuestions[_currentTaskIndex];
    if (selectedLabel.toLowerCase() != currentTask.targetLabel.toLowerCase()) {
      _wrongTargetActivations += 1;
      return;
    }

    final nextTask = _currentTaskIndex + 1;
    setState(() {
      _currentTaskIndex = nextTask;
    });

    if (nextTask >= widget.testQuestions.length) {
      unawaited(_completeSessionAndShowReport());
    }
  }

  Future<void> _completeSessionAndShowReport() async {
    if (_isCompletingSession) {
      return;
    }
    _isCompletingSession = true;

    final seqEaseRating = await _promptSeqEaseRating();
    final firstAttemptCorrectCount = _questionAttempts
        .where((attemptCount) => attemptCount == 1)
        .length;
    final completionTime = DateTime.now().difference(_sessionStartTime);
    final failedAttempts = _wrongTargetActivations;

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestReportPage(
          totalQuestions: widget.testQuestions.length,
          completionTime: completionTime,
          firstAttemptCorrectCount: firstAttemptCorrectCount,
          wrongTargetActivations: _wrongTargetActivations,
          failedAttempts: failedAttempts,
          seqEaseRating: seqEaseRating,
          questions: widget.testQuestions,
          attemptsPerQuestion: _questionAttempts,
        ),
      ),
    );
  }

  Future<int> _promptSeqEaseRating() async {
    var selectedRating = 4;
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('SEQ Rating'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall, how easy was this test? (1 = hard, 7 = easy)',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final value = index + 1;
                      return ChoiceChip(
                        label: Text('$value'),
                        selected: selectedRating == value,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedRating = value;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedRating),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? selectedRating;
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3DEDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_currentTaskIndex + 1}/${widget.testQuestions.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onPrimaryContainer,
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
                  showDebugToggle: false,
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
