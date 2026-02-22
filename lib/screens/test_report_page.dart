import 'package:flutter/material.dart';

import '../models/task_question.dart';

class TestReportPage extends StatelessWidget {
  const TestReportPage({
    super.key,
    required this.totalQuestions,
    required this.firstAttemptCorrectCount,
    required this.failedAttempts,
    required this.questions,
    required this.attemptsPerQuestion,
  });

  final int totalQuestions;
  final int firstAttemptCorrectCount;
  final int failedAttempts;
  final List<TaskQuestion> questions;
  final List<int> attemptsPerQuestion;

  @override
  Widget build(BuildContext context) {
    final firstTryRate = totalQuestions == 0
        ? 0
        : ((firstAttemptCorrectCount / totalQuestions) * 100).round();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.primary,
        elevation: 0,
        title: const Text('Test Report'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Results',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 14),
              _StatCard(
                title: 'First-attempt correct',
                value: '$firstAttemptCorrectCount / $totalQuestions',
              ),
              const SizedBox(height: 10),
              _StatCard(title: 'Failed attempts', value: '$failedAttempts'),
              const SizedBox(height: 10),
              _StatCard(title: 'First-try rate', value: '$firstTryRate%'),
              const SizedBox(height: 18),
              Text(
                'Per Question',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: questions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final attempts = attemptsPerQuestion[index];
                    final statusText = attempts == 1
                        ? 'Correct on first attempt'
                        : 'Solved in $attempts attempts';

                    return Container(
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
                            'Q${index + 1}: ${questions[index].prompt}',
                            style: TextStyle(
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
                    );
                  },
                ),
              ),
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onPrimaryContainer),
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
