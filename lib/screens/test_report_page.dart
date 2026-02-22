import 'package:flutter/material.dart';
import 'package:mobile_touchless_interaction/widgets/stat_card.dart';

import '../models/task_question.dart';

class TestReportPage extends StatefulWidget {
  const TestReportPage({
    super.key,
    required this.totalQuestions,
    required this.completionTime,
    required this.firstAttemptCorrectCount,
    required this.wrongTargetActivations,
    required this.failedAttempts,
    required this.questions,
    required this.attemptsPerQuestion,
  });

  final int totalQuestions;
  final Duration completionTime;
  final int firstAttemptCorrectCount;
  final int wrongTargetActivations;
  final int failedAttempts;
  final List<TaskQuestion> questions;
  final List<int> attemptsPerQuestion;

  @override
  State<TestReportPage> createState() => _TestReportPageState();
}

class _TestReportPageState extends State<TestReportPage> {
  int? _seqEaseRating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSeqRatingDialog();
    });
  }

  Future<void> _showSeqRatingDialog() async {
    final rating = await _promptSeqEaseRating();
    if (!mounted) {
      return;
    }

    setState(() {
      _seqEaseRating = rating;
    });
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final firstTryRate = widget.totalQuestions == 0
        ? 0
        : ((widget.firstAttemptCorrectCount / widget.totalQuestions) * 100)
              .round();
    final totalAttempts = widget.attemptsPerQuestion.fold<int>(
      0,
      (sum, attempts) => sum + attempts,
    );
    final attemptsPerTrial = widget.totalQuestions == 0
        ? 0.0
        : totalAttempts / widget.totalQuestions;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.primary,
        elevation: 0,
        title: const Text('Test Report'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 14),
                StatCard(
                  title: 'First-attempt correct',
                  value:
                      '${widget.firstAttemptCorrectCount} / ${widget.totalQuestions}',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Completion time',
                  value: _formatDuration(widget.completionTime),
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Wrong-target activations',
                  value: '${widget.wrongTargetActivations}',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Attempts per trial',
                  value: attemptsPerTrial.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'SEQ (1-7 ease)',
                  value: _seqEaseRating?.toString() ?? '-',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Failed attempts',
                  value: '${widget.failedAttempts}',
                ),
                const SizedBox(height: 10),
                StatCard(title: 'First-try rate', value: '$firstTryRate%'),
                const SizedBox(height: 18),
                Text(
                  'Per Question',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                ...widget.questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  final attempts = widget.attemptsPerQuestion[index];
                  final statusText = attempts == 1
                      ? 'Correct on first attempt'
                      : 'Solved in $attempts attempts';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD3DEDD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${index + 1}: ${question.prompt}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Back to Start'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}