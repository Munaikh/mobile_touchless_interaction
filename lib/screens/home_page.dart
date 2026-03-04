import 'package:flutter/material.dart';

import '../data/test_questions.dart';
import '../models/ab_test_assignment.dart';
import '../widgets/touchless_ring.dart';
import 'test_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<String?> _showParticipantIdDialog(BuildContext context) async {
    final controller = TextEditingController(text: 'P01');
    var currentValue = controller.text.trim();

    final participantId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Participant ID'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Enter ID (e.g., P01)',
                ),
                onChanged: (value) {
                  setDialogState(() {
                    currentValue = value.trim();
                  });
                },
                onSubmitted: (_) {
                  if (currentValue.isNotEmpty) {
                    Navigator.of(dialogContext).pop(currentValue);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: currentValue.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(currentValue),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return participantId;
  }

  Future<AbTestAssignment?> _showTestSelectionDialog(
    BuildContext context,
  ) async {
    final assignments = AbTestAssignment.values;

    return showDialog<AbTestAssignment>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose Latin-Square Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < assignments.length; index++) ...[
                  _buildTestChoice(
                    context: dialogContext,
                    assignment: assignments[index],
                  ),
                  if (index != assignments.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestChoice({
    required BuildContext context,
    required AbTestAssignment assignment,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => Navigator.of(context).pop(assignment),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD3DEDD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignment.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              assignment.summary,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to start',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTest(BuildContext context) async {
    final participantId = await _showParticipantIdDialog(context);
    if (participantId == null || participantId.trim().isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final assignment = await _showTestSelectionDialog(context);
    if (assignment == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestPage(
          testAssignment: assignment,
          participantId: participantId.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final practiceItems = kButtonLabels
        .map((label) => Text(label))
        .toList(growable: false);

    return Scaffold(
      // backgroundColor: const Color(0xFFE5ECEB),
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
                'Complete a 4x4 Latin-square touchless test with standing and walking rounds.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Practice Ring (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Practice hovering and selecting buttons here. Practice is not logged.',
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TouchlessRing(
                  items: practiceItems,
                  dwellDuration: const Duration(milliseconds: 1500),
                  fastDwellDuration: const Duration(milliseconds: 1500),
                  showDebugToggle: false,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _startTest(context);
                  },
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
