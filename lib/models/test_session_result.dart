import 'dart:convert';

import 'task_question.dart';

class QuestionResult {
  const QuestionResult({
    required this.index,
    required this.prompt,
    required this.targetLabel,
    required this.attempts,
    required this.targetSwitchCount,
    required this.cancelCount,
    this.trialStartedAt,
    this.trialCompletedAt,
  });

  final int index;
  final String prompt;
  final String targetLabel;
  final int attempts;
  final int targetSwitchCount;
  final int cancelCount;
  final DateTime? trialStartedAt;
  final DateTime? trialCompletedAt;

  bool get firstAttemptCorrect => attempts == 1;
  int? get trialDurationMs {
    final start = trialStartedAt;
    final end = trialCompletedAt;
    if (start == null || end == null) {
      return null;
    }
    return end.difference(start).inMilliseconds;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'index': index,
      'prompt': prompt,
      'targetLabel': targetLabel,
      'attempts': attempts,
      'firstAttemptCorrect': firstAttemptCorrect,
      'targetSwitchCount': targetSwitchCount,
      'cancelCount': cancelCount,
      'trialStartedAtIso': trialStartedAt?.toIso8601String(),
      'trialCompletedAtIso': trialCompletedAt?.toIso8601String(),
      'trialDurationMs': trialDurationMs,
    };
  }
}

class TestSessionResult {
  const TestSessionResult({
    required this.completedAt,
    required this.completionTime,
    required this.totalQuestions,
    required this.firstAttemptCorrectCount,
    required this.wrongTargetActivations,
    required this.failedAttempts,
    required this.questionResults,
    this.customMetrics = const <String, Object?>{},
  });

  factory TestSessionResult.fromSession({
    required DateTime completedAt,
    required Duration completionTime,
    required int wrongTargetActivations,
    required int failedAttempts,
    required List<TaskQuestion> questions,
    required List<int> attemptsPerQuestion,
    List<int> targetSwitchesPerQuestion = const <int>[],
    List<int> cancelCountsPerQuestion = const <int>[],
    List<DateTime?> trialStartedAt = const <DateTime?>[],
    List<DateTime?> trialCompletedAt = const <DateTime?>[],
    Map<String, Object?> customMetrics = const <String, Object?>{},
  }) {
    final questionResults = List<QuestionResult>.generate(questions.length, (
      index,
    ) {
      final question = questions[index];
      final attempts = index < attemptsPerQuestion.length
          ? attemptsPerQuestion[index]
          : 0;
      final targetSwitchCount = index < targetSwitchesPerQuestion.length
          ? targetSwitchesPerQuestion[index]
          : 0;
      final cancelCount = index < cancelCountsPerQuestion.length
          ? cancelCountsPerQuestion[index]
          : 0;
      final startedAt = index < trialStartedAt.length
          ? trialStartedAt[index]
          : null;
      final completedAt = index < trialCompletedAt.length
          ? trialCompletedAt[index]
          : null;
      return QuestionResult(
        index: index + 1,
        prompt: question.prompt,
        targetLabel: question.targetLabel,
        attempts: attempts,
        targetSwitchCount: targetSwitchCount,
        cancelCount: cancelCount,
        trialStartedAt: startedAt,
        trialCompletedAt: completedAt,
      );
    }, growable: false);

    final firstAttemptCorrectCount = questionResults
        .where((result) => result.firstAttemptCorrect)
        .length;

    return TestSessionResult(
      completedAt: completedAt,
      completionTime: completionTime,
      totalQuestions: questions.length,
      firstAttemptCorrectCount: firstAttemptCorrectCount,
      wrongTargetActivations: wrongTargetActivations,
      failedAttempts: failedAttempts,
      questionResults: questionResults,
      customMetrics: customMetrics,
    );
  }

  final DateTime completedAt;
  final Duration completionTime;
  final int totalQuestions;
  final int firstAttemptCorrectCount;
  final int wrongTargetActivations;
  final int failedAttempts;
  final List<QuestionResult> questionResults;
  final Map<String, Object?> customMetrics;

  int get firstTryRatePercent {
    if (totalQuestions == 0) {
      return 0;
    }
    return ((firstAttemptCorrectCount / totalQuestions) * 100).round();
  }

  int get totalAttempts {
    return questionResults.fold<int>(
      0,
      (sum, questionResult) => sum + questionResult.attempts,
    );
  }

  double get attemptsPerTrial {
    if (totalQuestions == 0) {
      return 0.0;
    }
    return totalAttempts / totalQuestions;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'completedAtIso': completedAt.toIso8601String(),
      'completionTimeMs': completionTime.inMilliseconds,
      'totalQuestions': totalQuestions,
      'firstAttemptCorrectCount': firstAttemptCorrectCount,
      'firstTryRatePercent': firstTryRatePercent,
      'wrongTargetActivations': wrongTargetActivations,
      'failedAttempts': failedAttempts,
      'totalAttempts': totalAttempts,
      'attemptsPerTrial': attemptsPerTrial,
      'trialDurationsMs': questionResults
          .map((questionResult) => questionResult.trialDurationMs)
          .toList(growable: false),
      'targetSwitchCountsPerTrial': questionResults
          .map((questionResult) => questionResult.targetSwitchCount)
          .toList(growable: false),
      'cancelCountsPerTrial': questionResults
          .map((questionResult) => questionResult.cancelCount)
          .toList(growable: false),
      'customMetrics': customMetrics.map(
        (key, value) => MapEntry(key, _normalizeMetricValue(value)),
      ),
      'questionResults': questionResults
          .map((questionResult) => questionResult.toJson())
          .toList(growable: false),
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  static Object? _normalizeMetricValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeMetricValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value
          .map<Object?>((nestedValue) => _normalizeMetricValue(nestedValue))
          .toList(growable: false);
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Duration) {
      return value.inMilliseconds;
    }
    return value.toString();
  }
}
