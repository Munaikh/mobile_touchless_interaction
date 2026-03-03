import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/test_questions.dart';
import '../models/ab_test_assignment.dart';
import '../models/ab_test_result.dart';
import '../models/task_question.dart';
import '../models/test_session_result.dart';
import '../widgets/touchless_ring.dart';
import 'test_report_page.dart';

class TestPage extends StatefulWidget {
  const TestPage({
    super.key,
    required this.testAssignment,
    required this.participantId,
  });

  final AbTestAssignment testAssignment;
  final String participantId;

  static const List<String> labels = kButtonLabels;

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late DateTime _abTestStartTime;
  late List<Duration> _phaseDwellDurations;
  late List<List<TaskQuestion>> _phaseQuestions;
  late List<List<int>> _phaseAttempts;
  late List<List<int>> _phaseTargetSwitchCounts;
  late List<List<int>> _phaseCancelCounts;
  late List<int> _phaseWrongTargetActivations;
  late List<DateTime> _phaseStartTimes;
  late List<DateTime?> _phaseCompletedAt;
  late List<List<DateTime?>> _phaseTrialStartedAt;
  late List<List<DateTime?>> _phaseTrialCompletedAt;
  int? _trialHoveredIndex;
  int _currentPhaseIndex = 0;
  int _currentTaskIndex = 0;
  bool _isCompletingSession = false;

  @override
  void initState() {
    super.initState();
    _abTestStartTime = DateTime.now();
    _phaseDwellDurations = widget.testAssignment.dwellSequence;
    _phaseQuestions = List<List<TaskQuestion>>.generate(
      _phaseDwellDurations.length,
      (_) => buildShuffledQuestionSet(),
      growable: false,
    );
    _phaseAttempts = _phaseQuestions
        .map((questions) => List<int>.filled(questions.length, 0))
        .toList(growable: false);
    _phaseTargetSwitchCounts = _phaseQuestions
        .map((questions) => List<int>.filled(questions.length, 0))
        .toList(growable: false);
    _phaseCancelCounts = _phaseQuestions
        .map((questions) => List<int>.filled(questions.length, 0))
        .toList(growable: false);
    _phaseWrongTargetActivations = List<int>.filled(
      _phaseDwellDurations.length,
      0,
      growable: false,
    );
    _phaseStartTimes = List<DateTime>.filled(
      _phaseDwellDurations.length,
      _abTestStartTime,
      growable: false,
    );
    _phaseCompletedAt = List<DateTime?>.filled(
      _phaseDwellDurations.length,
      null,
      growable: false,
    );
    _phaseTrialStartedAt = _phaseQuestions
        .map(
          (questions) =>
              List<DateTime?>.filled(questions.length, null, growable: false),
        )
        .toList(growable: false);
    _phaseTrialCompletedAt = _phaseQuestions
        .map(
          (questions) =>
              List<DateTime?>.filled(questions.length, null, growable: false),
        )
        .toList(growable: false);
    _phaseStartTimes[0] = _abTestStartTime;
    if (_phaseTrialStartedAt.isNotEmpty && _phaseTrialStartedAt[0].isNotEmpty) {
      _phaseTrialStartedAt[0][0] = _abTestStartTime;
    }
  }

  List<TaskQuestion> get _activeQuestions =>
      _phaseQuestions[_currentPhaseIndex];
  Duration get _activeDwellDuration => _phaseDwellDurations[_currentPhaseIndex];

  void _handleHoverChanged(int? hoveredIndex) {
    if (_isCompletingSession || _currentTaskIndex >= _activeQuestions.length) {
      _trialHoveredIndex = hoveredIndex;
      return;
    }

    final previousHoveredIndex = _trialHoveredIndex;
    if (previousHoveredIndex == hoveredIndex) {
      return;
    }

    if (previousHoveredIndex != null && hoveredIndex == null) {
      _phaseCancelCounts[_currentPhaseIndex][_currentTaskIndex] += 1;
    } else if (previousHoveredIndex != null &&
        hoveredIndex != null &&
        previousHoveredIndex != hoveredIndex) {
      _phaseTargetSwitchCounts[_currentPhaseIndex][_currentTaskIndex] += 1;
    }

    _trialHoveredIndex = hoveredIndex;
  }

  void _handleActivation(int index) {
    if (_isCompletingSession) {
      return;
    }

    if (_currentTaskIndex >= _activeQuestions.length) {
      return;
    }

    final selectedLabel = TestPage.labels[index];
    _phaseAttempts[_currentPhaseIndex][_currentTaskIndex] += 1;
    final currentTask = _activeQuestions[_currentTaskIndex];
    if (selectedLabel.toLowerCase() != currentTask.targetLabel.toLowerCase()) {
      _phaseWrongTargetActivations[_currentPhaseIndex] += 1;
      return;
    }

    final solvedAt = DateTime.now();
    _phaseTrialCompletedAt[_currentPhaseIndex][_currentTaskIndex] = solvedAt;
    _trialHoveredIndex = index;
    final nextTask = _currentTaskIndex + 1;
    if (nextTask < _activeQuestions.length) {
      _phaseTrialStartedAt[_currentPhaseIndex][nextTask] ??= solvedAt;
      setState(() {
        _currentTaskIndex = nextTask;
      });
      return;
    }

    final phaseCompletedAt = solvedAt;
    _phaseCompletedAt[_currentPhaseIndex] = phaseCompletedAt;

    final hasNextPhase = _currentPhaseIndex + 1 < _phaseDwellDurations.length;
    if (!hasNextPhase) {
      _completeSessionAndShowReport();
      return;
    }

    final completedPhaseNumber = _currentPhaseIndex + 1;
    final nextPhaseIndex = _currentPhaseIndex + 1;
    setState(() {
      _currentPhaseIndex = nextPhaseIndex;
      _currentTaskIndex = 0;
      _phaseStartTimes[nextPhaseIndex] = phaseCompletedAt;
      if (_phaseTrialStartedAt[nextPhaseIndex].isNotEmpty) {
        _phaseTrialStartedAt[nextPhaseIndex][0] = phaseCompletedAt;
      }
    });
    _trialHoveredIndex = null;

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Round $completedPhaseNumber complete. '
          'Starting Round ${nextPhaseIndex + 1}.',
        ),
      ),
    );
  }

  void _completeSessionAndShowReport() {
    if (_isCompletingSession) {
      return;
    }
    _isCompletingSession = true;

    final completedAt = DateTime.now();
    _phaseCompletedAt[_currentPhaseIndex] ??= completedAt;

    final phaseResults = List<DwellPhaseResult>.generate(
      _phaseDwellDurations.length,
      (index) {
        final phaseStart = _phaseStartTimes[index];
        final phaseCompleted = _phaseCompletedAt[index] ?? completedAt;
        final dwellDuration = _phaseDwellDurations[index];
        final sessionResult = TestSessionResult.fromSession(
          completedAt: phaseCompleted,
          completionTime: phaseCompleted.difference(phaseStart),
          wrongTargetActivations: _phaseWrongTargetActivations[index],
          failedAttempts: _phaseWrongTargetActivations[index],
          questions: _phaseQuestions[index],
          attemptsPerQuestion: List<int>.from(_phaseAttempts[index]),
          targetSwitchesPerQuestion: List<int>.from(
            _phaseTargetSwitchCounts[index],
          ),
          cancelCountsPerQuestion: List<int>.from(_phaseCancelCounts[index]),
          trialStartedAt: List<DateTime?>.from(_phaseTrialStartedAt[index]),
          trialCompletedAt: List<DateTime?>.from(_phaseTrialCompletedAt[index]),
          customMetrics: <String, Object?>{
            'sessionStartIso': phaseStart.toIso8601String(),
            'phaseOrder': index + 1,
            'dwellDurationMs': dwellDuration.inMilliseconds,
            'dwellDurationSeconds': dwellDuration.inMilliseconds / 1000,
            'testAssignment': widget.testAssignment.id,
            'participantId': widget.participantId,
          },
        );
        return DwellPhaseResult(
          phaseOrder: index + 1,
          dwellDuration: dwellDuration,
          sessionResult: sessionResult,
        );
      },
      growable: false,
    );

    final result = AbTestResult(
      assignment: widget.testAssignment,
      participantId: widget.participantId,
      startedAt: _abTestStartTime,
      completedAt: completedAt,
      phaseResults: phaseResults,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestReportPage(result: result)),
    );
  }

  Widget _buildTaskCard() {
    final currentTask = _activeQuestions[_currentTaskIndex];
    final colors = Theme.of(context).colorScheme;
    final phaseNumber = _currentPhaseIndex + 1;
    final totalPhases = _phaseDwellDurations.length;

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
            '${widget.testAssignment.title}  |  '
            'Round $phaseNumber/$totalPhases',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Question ${_currentTaskIndex + 1}/${_activeQuestions.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Select ${currentTask.targetLabel}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
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
                'Tilt the device to move the cursor. Hold over a button to activate it.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildTaskCard(),
              const SizedBox(height: 12),
              Expanded(
                child: TouchlessRing(
                  dwellDuration: _activeDwellDuration,
                  fastDwellDuration: _activeDwellDuration,
                  items: items,
                  showDebugToggle: kDebugMode,
                  onHoverChanged: _handleHoverChanged,
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
