import 'dart:convert';

import 'ab_test_assignment.dart';
import 'test_session_result.dart';

class DwellPhaseResult {
  const DwellPhaseResult({
    required this.phaseOrder,
    required this.dwellDuration,
    required this.sessionResult,
  });

  final int phaseOrder;
  final Duration dwellDuration;
  final TestSessionResult sessionResult;

  String get dwellKey => '${dwellDuration.inSeconds}s';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'phaseOrder': phaseOrder,
      'dwellDurationMs': dwellDuration.inMilliseconds,
      'dwellDurationSeconds': dwellDuration.inMilliseconds / 1000,
      'firstTryRatePercent': sessionResult.firstTryRatePercent,
      'attemptsPerTrial': sessionResult.attemptsPerTrial,
      'wrongTargetActivations': sessionResult.wrongTargetActivations,
      'failedAttempts': sessionResult.failedAttempts,
      'completionTimeMs': sessionResult.completionTime.inMilliseconds,
      'sessionResult': sessionResult.toJson(),
    };
  }
}

class AbTestResult {
  const AbTestResult({
    required this.assignment,
    required this.participantId,
    required this.startedAt,
    required this.completedAt,
    required this.phaseResults,
  });

  final AbTestAssignment assignment;
  final String participantId;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<DwellPhaseResult> phaseResults;

  Duration get totalCompletionTime => completedAt.difference(startedAt);

  Map<String, Object?> _ratesByDwellConfig() {
    final rates = <String, Object?>{};
    for (final phase in phaseResults) {
      rates[phase.dwellKey] = <String, Object?>{
        'firstTryRatePercent': phase.sessionResult.firstTryRatePercent,
        'attemptsPerTrial': phase.sessionResult.attemptsPerTrial,
        'wrongTargetActivations': phase.sessionResult.wrongTargetActivations,
        'failedAttempts': phase.sessionResult.failedAttempts,
        'completionTimeMs': phase.sessionResult.completionTime.inMilliseconds,
      };
    }
    return rates;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'testAssignment': assignment.toJson(),
      'participantId': participantId,
      'startedAtIso': startedAt.toIso8601String(),
      'completedAtIso': completedAt.toIso8601String(),
      'totalCompletionTimeMs': totalCompletionTime.inMilliseconds,
      'ratesByDwellConfig': _ratesByDwellConfig(),
      'phaseResults': phaseResults
          .map((phaseResult) => phaseResult.toJson())
          .toList(growable: false),
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
