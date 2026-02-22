import 'package:flutter/material.dart';

import '../models/task_question.dart';

class TestReportPage extends StatelessWidget {
  const TestReportPage({
    super.key,
    required this.totalQuestions,
    required this.completionTime,
    required this.firstAttemptCorrectCount,
    required this.wrongTargetActivations,
    required this.failedAttempts,
    required this.seqEaseRating,
    required this.questions,
    required this.attemptsPerQuestion,
  });

  final int totalQuestions;
  final Duration completionTime;
  final int firstAttemptCorrectCount;
  final int wrongTargetActivations;
  final int failedAttempts;
  final int seqEaseRating;
  final List<TaskQuestion> questions;
  final List<int> attemptsPerQuestion;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final firstTryRate = totalQuestions == 0
        ? 0
        : ((firstAttemptCorrectCount / totalQuestions) * 100).round();
    final totalAttempts = attemptsPerQuestion.fold<int>(
      0,
      (sum, attempts) => sum + attempts,
    );
    final attemptsPerTrial = totalQuestions == 0
        ? 0.0
        : totalAttempts / totalQuestions;
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
                _StatCard(
                  title: 'First-attempt correct',
                  value: '$firstAttemptCorrectCount / $totalQuestions',
                ),
                const SizedBox(height: 10),
                _StatCard(
                  title: 'Completion time',
                  value: _formatDuration(completionTime),
                ),
                const SizedBox(height: 10),
                _StatCard(
                  title: 'Wrong-target activations',
                  value: '$wrongTargetActivations',
                ),
                const SizedBox(height: 10),
                _StatCard(
                  title: 'Attempts per trial',
                  value: attemptsPerTrial.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
                _StatCard(title: 'SEQ (1-7 ease)', value: '$seqEaseRating'),
                const SizedBox(height: 10),
                _StatCard(title: 'Failed attempts', value: '$failedAttempts'),
                const SizedBox(height: 10),
                _StatCard(title: 'First-try rate', value: '$firstTryRate%'),
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
                ...questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  final attempts = attemptsPerQuestion[index];
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD3DEDD)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
