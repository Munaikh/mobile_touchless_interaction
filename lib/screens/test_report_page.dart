import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ab_test_assignment.dart';
import '../models/ab_test_result.dart';
import '../models/test_session_result.dart';
import '../widgets/stat_card.dart';

class TestReportPage extends StatelessWidget {
  const TestReportPage({super.key, required this.result});

  final AbTestResult result;

  Future<void> _shareResultsAsJson(
    BuildContext pageContext,
    BuildContext originContext,
  ) async {
    final payload = result.toPrettyJson();
    final fileNameSafeTimestamp = result.completedAt
        .toIso8601String()
        .replaceAll(':', '-');
    final fileName = 'touchless_results_$fileNameSafeTimestamp.json';
    final fileBytes = Uint8List.fromList(utf8.encode(payload));
    final renderBox = originContext.findRenderObject() as RenderBox?;
    final shareOrigin =
        renderBox != null &&
            renderBox.hasSize &&
            renderBox.size.width > 0 &&
            renderBox.size.height > 0
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : const Rect.fromLTWH(0, 0, 1, 1);

    try {
      await Share.shareXFiles(
        <XFile>[
          XFile.fromData(
            fileBytes,
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        subject: 'Touchless Hover A/B Test Results (JSON)',
        text: 'Touchless Hover A/B test results exported as JSON.',
        sharePositionOrigin: shareOrigin,
      );
    } catch (error) {
      if (!pageContext.mounted) {
        return;
      }
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text('Unable to share results: $error')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Widget _buildQuestionCard({
    required QuestionResult questionResult,
    required ColorScheme colors,
  }) {
    final statusText = questionResult.firstAttemptCorrect
        ? 'Correct on first attempt'
        : 'Solved in ${questionResult.attempts} attempts';

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
              'Q${questionResult.index}: ${questionResult.prompt}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: TextStyle(fontSize: 13, color: colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseSection({
    required DwellPhaseResult phaseResult,
    required ColorScheme colors,
  }) {
    final session = phaseResult.sessionResult;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3DEDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${phaseResult.phaseOrder}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          StatCard(
            title: 'First-attempt correct',
            value:
                '${session.firstAttemptCorrectCount} / ${session.totalQuestions}',
          ),
          const SizedBox(height: 10),
          StatCard(
            title: 'First-try rate',
            value: '${session.firstTryRatePercent}%',
          ),
          const SizedBox(height: 10),
          StatCard(
            title: 'Completion time',
            value: _formatDuration(session.completionTime),
          ),
          const SizedBox(height: 10),
          StatCard(
            title: 'Wrong-target activations',
            value: '${session.wrongTargetActivations}',
          ),
          const SizedBox(height: 10),
          StatCard(
            title: 'Attempts per trial',
            value: session.attemptsPerTrial.toStringAsFixed(2),
          ),
          const SizedBox(height: 10),
          Text(
            'Per Question',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...session.questionResults.map((questionResult) {
            return _buildQuestionCard(
              questionResult: questionResult,
              colors: colors,
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.primary,
        elevation: 0,
        title: const Text('A/B Test Report'),
        actions: [
          Builder(
            builder: (buttonContext) {
              return IconButton(
                tooltip: 'Share JSON',
                icon: const Icon(Icons.share),
                onPressed: () async {
                  await _shareResultsAsJson(context, buttonContext);
                },
              );
            },
          ),
        ],
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
                  title: 'Test Assignment',
                  value: result.assignment.title,
                ),
                const SizedBox(height: 10),
                StatCard(title: 'Participant ID', value: result.participantId),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Total completion time',
                  value: _formatDuration(result.totalCompletionTime),
                ),
                ...result.phaseResults.map((phaseResult) {
                  return _buildPhaseSection(
                    phaseResult: phaseResult,
                    colors: colors,
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
