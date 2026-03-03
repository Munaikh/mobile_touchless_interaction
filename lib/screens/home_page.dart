import 'package:flutter/material.dart';

import '../models/ab_test_assignment.dart';
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
    return showDialog<AbTestAssignment>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose Test Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTestChoice(
                context: dialogContext,
                assignment: AbTestAssignment.testOne,
              ),
              const SizedBox(height: 8),
              _buildTestChoice(
                context: dialogContext,
                assignment: AbTestAssignment.testTwo,
              ),
            ],
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
                'Press Start Test, then choose Test One or Test Two.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 22),
              const Text(
                'Task Instructions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'Each phase has 6 questions (all buttons once) in random order.',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Try to be as accurate as possible. Wrong selections are counted and you can retry until correct.',
                style: const TextStyle(fontSize: 15),
              ),
              const Spacer(),
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
