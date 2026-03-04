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
  DateTime? _abTestStartTime;
  late List<TestCondition> _phaseConditions;
  late List<List<TaskQuestion>> _phaseQuestions;
  late List<List<int>> _phaseAttempts;
  late List<List<String?>> _phaseActivatedLabels;
  late List<List<TrialErrorType>> _phaseErrorTypes;
  late List<List<int>> _phaseTargetSwitchCounts;
  late List<List<int>> _phaseCancelCounts;
  late List<int> _phaseWrongTargetActivations;
  late List<DateTime?> _phaseStartTimes;
  late List<DateTime?> _phaseCompletedAt;
  late List<List<DateTime?>> _phaseTrialStartedAt;
  late List<List<DateTime?>> _phaseTrialCompletedAt;
  int? _trialHoveredIndex;
  int _currentPhaseIndex = 0;
  int _currentTaskIndex = 0;
  bool _showPreparationScreen = true;
  bool _isCompletingSession = false;

  @override
  void initState() {
    super.initState();
    _phaseConditions = widget.testAssignment.phaseSequence;
    _phaseQuestions = List<List<TaskQuestion>>.generate(
      _phaseConditions.length,
      (_) => buildShuffledQuestionSet(),
      growable: false,
    );
    _phaseAttempts = _phaseQuestions
        .map((questions) => List<int>.filled(questions.length, 0))
        .toList(growable: false);
    _phaseActivatedLabels = _phaseQuestions
        .map((questions) => List<String?>.filled(questions.length, null))
        .toList(growable: false);
    _phaseErrorTypes = _phaseQuestions
        .map(
          (questions) => List<TrialErrorType>.filled(
            questions.length,
            TrialErrorType.none,
          ),
        )
        .toList(growable: false);
    _phaseTargetSwitchCounts = _phaseQuestions
        .map((questions) => List<int>.filled(questions.length, 0))
        .toList(growable: false);
    _phaseCancelCounts = _phaseQuestions
        .map((questions) => List<int>.filled(questions.length, 0))
        .toList(growable: false);
    _phaseWrongTargetActivations = List<int>.filled(
      _phaseConditions.length,
      0,
      growable: false,
    );
    _phaseStartTimes = List<DateTime?>.filled(
      _phaseConditions.length,
      null,
      growable: false,
    );
    _phaseCompletedAt = List<DateTime?>.filled(
      _phaseConditions.length,
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
  }

  List<TaskQuestion> get _activeQuestions =>
      _phaseQuestions[_currentPhaseIndex];
  TestCondition get _activeCondition => _phaseConditions[_currentPhaseIndex];
  Duration get _activeDwellDuration => _activeCondition.dwellDuration;

  String _formatDwellDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000;
    final wholeSeconds = seconds.roundToDouble();
    if (seconds == wholeSeconds) {
      return '${seconds.toStringAsFixed(0)}s';
    }
    return '${seconds.toStringAsFixed(1)}s';
  }

  String? _transitionLabel() {
    if (_currentPhaseIndex == 0) {
      return null;
    }
    final previousMobility = _phaseConditions[_currentPhaseIndex - 1].mobility;
    final currentMobility = _activeCondition.mobility;
    if (previousMobility == currentMobility) {
      return null;
    }
    return '${previousMobility.title} -> ${currentMobility.title}';
  }

  void _startCurrentPhase() {
    if (!_showPreparationScreen || _isCompletingSession) {
      return;
    }

    final phaseStartTime = DateTime.now();
    _abTestStartTime ??= phaseStartTime;
    _phaseStartTimes[_currentPhaseIndex] = phaseStartTime;
    if (_phaseTrialStartedAt[_currentPhaseIndex].isNotEmpty) {
      _phaseTrialStartedAt[_currentPhaseIndex][0] = phaseStartTime;
    }

    _trialHoveredIndex = null;
    setState(() {
      _currentTaskIndex = 0;
      _showPreparationScreen = false;
    });
  }

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

  void _setTrialError({
    required String activatedLabel,
    required TrialErrorType errorType,
  }) {
    if (_phaseErrorTypes[_currentPhaseIndex][_currentTaskIndex] ==
        TrialErrorType.none) {
      _phaseErrorTypes[_currentPhaseIndex][_currentTaskIndex] = errorType;
      _phaseActivatedLabels[_currentPhaseIndex][_currentTaskIndex] =
          activatedLabel;
    }
  }

  void _handleActivationWithContext(int index, bool wasHoveredAtActivation) {
    if (_isCompletingSession) {
      return;
    }

    if (_currentTaskIndex >= _activeQuestions.length) {
      return;
    }

    final selectedLabel = TestPage.labels[index];
    _phaseAttempts[_currentPhaseIndex][_currentTaskIndex] += 1;
    final currentTask = _activeQuestions[_currentTaskIndex];
    final isCorrectActivation =
        selectedLabel.toLowerCase() == currentTask.targetLabel.toLowerCase();

    if (!isCorrectActivation) {
      _phaseWrongTargetActivations[_currentPhaseIndex] += 1;
      _setTrialError(
        activatedLabel: selectedLabel,
        errorType: wasHoveredAtActivation
            ? TrialErrorType.wrongTargetActivation
            : TrialErrorType.unintendedActivation,
      );
      return;
    }

    if (!wasHoveredAtActivation) {
      _setTrialError(
        activatedLabel: selectedLabel,
        errorType: TrialErrorType.unintendedActivation,
      );
    } else {
      _phaseActivatedLabels[_currentPhaseIndex][_currentTaskIndex] ??=
          selectedLabel;
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

    final hasNextPhase = _currentPhaseIndex + 1 < _phaseConditions.length;
    if (!hasNextPhase) {
      _completeSessionAndShowReport();
      return;
    }

    final nextPhaseIndex = _currentPhaseIndex + 1;
    setState(() {
      _currentPhaseIndex = nextPhaseIndex;
      _currentTaskIndex = 0;
      _showPreparationScreen = true;
    });
    _trialHoveredIndex = null;
  }

  void _completeSessionAndShowReport() {
    if (_isCompletingSession) {
      return;
    }
    _isCompletingSession = true;

    final completedAt = DateTime.now();
    _phaseCompletedAt[_currentPhaseIndex] ??= completedAt;

    final phaseResults = List<DwellPhaseResult>.generate(
      _phaseConditions.length,
      (index) {
        final phaseCondition = _phaseConditions[index];
        final recordedPhaseStart = _phaseStartTimes[index];
        final phaseCompleted = _phaseCompletedAt[index] ?? completedAt;
        final phaseStart = recordedPhaseStart ?? phaseCompleted;
        final dwellDuration = phaseCondition.dwellDuration;
        final sessionResult = TestSessionResult.fromSession(
          completedAt: phaseCompleted,
          completionTime: phaseCompleted.difference(phaseStart),
          wrongTargetActivations: _phaseWrongTargetActivations[index],
          failedAttempts: _phaseWrongTargetActivations[index],
          questions: _phaseQuestions[index],
          attemptsPerQuestion: List<int>.from(_phaseAttempts[index]),
          activatedLabelsPerQuestion: List<String?>.from(
            _phaseActivatedLabels[index],
          ),
          errorTypesPerQuestion: List<TrialErrorType>.from(
            _phaseErrorTypes[index],
          ),
          targetSwitchesPerQuestion: List<int>.from(
            _phaseTargetSwitchCounts[index],
          ),
          cancelCountsPerQuestion: List<int>.from(_phaseCancelCounts[index]),
          trialStartedAt: List<DateTime?>.from(_phaseTrialStartedAt[index]),
          trialCompletedAt: List<DateTime?>.from(_phaseTrialCompletedAt[index]),
          customMetrics: <String, Object?>{
            'sessionStartIso': recordedPhaseStart?.toIso8601String(),
            'phaseOrder': index + 1,
            'conditionId': phaseCondition.id,
            'mobilityBehavior': phaseCondition.mobility.id,
            'dwellProfile': phaseCondition.dwellProfile.id,
            'dwellDurationMs': dwellDuration.inMilliseconds,
            'dwellDurationSeconds': dwellDuration.inMilliseconds / 1000,
            'testAssignment': widget.testAssignment.id,
            'participantId': widget.participantId,
          },
        );
        return DwellPhaseResult(
          phaseOrder: index + 1,
          dwellDuration: dwellDuration,
          condition: phaseCondition,
          sessionResult: sessionResult,
        );
      },
      growable: false,
    );

    final result = AbTestResult(
      assignment: widget.testAssignment,
      participantId: widget.participantId,
      startedAt: _abTestStartTime ?? completedAt,
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
    final totalPhases = _phaseConditions.length;

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
            '${_activeCondition.mobility.title}  |  '
            '${_activeCondition.dwellProfile.label} '
            '(${_formatDwellDuration(_activeDwellDuration)} dwell)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onPrimaryContainer,
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

  Widget _buildPreparationCard() {
    final colors = Theme.of(context).colorScheme;
    final phaseNumber = _currentPhaseIndex + 1;
    final totalPhases = _phaseConditions.length;
    final transitionLabel = _transitionLabel();
    final previousMobility = _currentPhaseIndex == 0
        ? null
        : _phaseConditions[_currentPhaseIndex - 1].mobility;
    final currentMobility = _activeCondition.mobility;
    final isWalkingToStanding =
        previousMobility == MobilityBehavior.walking &&
        currentMobility == MobilityBehavior.standing;

    final transitionInstruction = transitionLabel == null
        ? null
        : isWalkingToStanding
        ? 'Transition detected. Stop walking and stand still before proceeding.'
        : 'Transition detected. Start walking before proceeding.';

    final actionLabel = _currentPhaseIndex == 0
        ? 'Start Round 1'
        : 'Proceed to Round $phaseNumber';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3DEDD)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.testAssignment.title}  |  Round $phaseNumber/$totalPhases',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Next condition: ${_activeCondition.title}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _activeCondition.mobility.preparationHint,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.onPrimaryContainer,
            ),
          ),
          if (transitionLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mobility transition: $transitionLabel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transitionInstruction!,
                    style: TextStyle(fontSize: 13, color: colors.onSurface),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Take your time to prepare, then press proceed.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _startCurrentPhase,
              child: Text(actionLabel),
            ),
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
    final subtitle = _showPreparationScreen
        ? 'Review the next mobility condition, prepare, then press proceed.'
        : 'Tilt the device to move the cursor. Hold over a button to activate it.';

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
              Text(subtitle, style: TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 12),
              if (_showPreparationScreen)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SingleChildScrollView(
                        child: _buildPreparationCard(),
                      ),
                    ),
                  ),
                )
              else ...[
                _buildTaskCard(),
                const SizedBox(height: 12),
                Expanded(
                  child: TouchlessRing(
                    key: ValueKey<String>('phase_$_currentPhaseIndex'),
                    dwellDuration: _activeDwellDuration,
                    fastDwellDuration: _activeDwellDuration,
                    items: items,
                    showDebugToggle: kDebugMode,
                    onHoverChanged: _handleHoverChanged,
                    onActivateWithContext: _handleActivationWithContext,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
