import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/test_session_result.dart';
import '../widgets/stat_card.dart';

class TestReportPage extends StatefulWidget {
  const TestReportPage({super.key, required this.result});

  final TestSessionResult result;

  @override
  State<TestReportPage> createState() => _TestReportPageState();
}

class _TestReportPageState extends State<TestReportPage> {
  late TestSessionResult _result;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
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
      _result = _result.copyWith(seqEaseRating: rating);
    });
  }

  Future<void> _shareResultsAsJson(BuildContext originContext) async {
    final payload = _result.toPrettyJson();
    final fileNameSafeTimestamp = _result.completedAt
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
        subject: 'Touchless Hover Test Results (JSON)',
        text: 'Touchless Hover test results exported as JSON.',
        sharePositionOrigin: shareOrigin,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share results: $error')),
      );
    }
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.primary,
        elevation: 0,
        title: const Text('Test Report'),
        actions: [
          Builder(
            builder: (buttonContext) {
              return IconButton(
                tooltip: 'Share JSON',
                icon: const Icon(Icons.share),
                onPressed: () async {
                  await _shareResultsAsJson(buttonContext);
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
                  title: 'First-attempt correct',
                  value:
                      '${_result.firstAttemptCorrectCount} / ${_result.totalQuestions}',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Completion time',
                  value: _formatDuration(_result.completionTime),
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Wrong-target activations',
                  value: '${_result.wrongTargetActivations}',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Attempts per trial',
                  value: _result.attemptsPerTrial.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'SEQ (1-7 ease)',
                  value: _result.seqEaseRating?.toString() ?? '-',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'Failed attempts',
                  value: '${_result.failedAttempts}',
                ),
                const SizedBox(height: 10),
                StatCard(
                  title: 'First-try rate',
                  value: '${_result.firstTryRatePercent}%',
                ),
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
                ..._result.questionResults.map((questionResult) {
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
