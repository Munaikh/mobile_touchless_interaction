enum MobilityBehavior { standing, walking }

extension MobilityBehaviorX on MobilityBehavior {
  String get id {
    switch (this) {
      case MobilityBehavior.standing:
        return 'standing';
      case MobilityBehavior.walking:
        return 'walking';
    }
  }

  String get title {
    switch (this) {
      case MobilityBehavior.standing:
        return 'Standing';
      case MobilityBehavior.walking:
        return 'Walking';
    }
  }

  String get preparationHint {
    switch (this) {
      case MobilityBehavior.standing:
        return 'Stand still before you proceed.';
      case MobilityBehavior.walking:
        return 'Begin walking before you proceed.';
    }
  }
}

enum DwellProfile { d1, d2 }

extension DwellProfileX on DwellProfile {
  String get id {
    switch (this) {
      case DwellProfile.d1:
        return 'd1';
      case DwellProfile.d2:
        return 'd2';
    }
  }

  String get label => id.toUpperCase();

  Duration get duration {
    switch (this) {
      case DwellProfile.d1:
        return const Duration(seconds: 2);
      case DwellProfile.d2:
        return const Duration(seconds: 1);
    }
  }
}

class TestCondition {
  const TestCondition({required this.mobility, required this.dwellProfile});

  final MobilityBehavior mobility;
  final DwellProfile dwellProfile;

  Duration get dwellDuration => dwellProfile.duration;
  String get id => '${mobility.id}_${dwellProfile.id}';
  String get title => mobility.title;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'mobilityBehavior': mobility.id,
      'dwellProfile': dwellProfile.id,
      'dwellDurationMs': dwellDuration.inMilliseconds,
      'dwellDurationSeconds': dwellDuration.inMilliseconds / 1000,
    };
  }
}

const TestCondition kStandingD1 = TestCondition(
  mobility: MobilityBehavior.standing,
  dwellProfile: DwellProfile.d1,
);
const TestCondition kStandingD2 = TestCondition(
  mobility: MobilityBehavior.standing,
  dwellProfile: DwellProfile.d2,
);
const TestCondition kWalkingD1 = TestCondition(
  mobility: MobilityBehavior.walking,
  dwellProfile: DwellProfile.d1,
);
const TestCondition kWalkingD2 = TestCondition(
  mobility: MobilityBehavior.walking,
  dwellProfile: DwellProfile.d2,
);

enum AbTestAssignment { testOne, testTwo, testThree, testFour }

extension AbTestAssignmentX on AbTestAssignment {
  String get id {
    switch (this) {
      case AbTestAssignment.testOne:
        return 'test_1';
      case AbTestAssignment.testTwo:
        return 'test_2';
      case AbTestAssignment.testThree:
        return 'test_3';
      case AbTestAssignment.testFour:
        return 'test_4';
    }
  }

  String get title {
    switch (this) {
      case AbTestAssignment.testOne:
        return 'Test 1';
      case AbTestAssignment.testTwo:
        return 'Test 2';
      case AbTestAssignment.testThree:
        return 'Test 3';
      case AbTestAssignment.testFour:
        return 'Test 4';
    }
  }

  List<TestCondition> get phaseSequence {
    switch (this) {
      case AbTestAssignment.testOne:
        return const <TestCondition>[
          kStandingD1,
          kStandingD2,
          kWalkingD1,
          kWalkingD2,
        ];
      case AbTestAssignment.testTwo:
        return const <TestCondition>[
          kStandingD2,
          kWalkingD1,
          kWalkingD2,
          kStandingD1,
        ];
      case AbTestAssignment.testThree:
        return const <TestCondition>[
          kWalkingD1,
          kWalkingD2,
          kStandingD1,
          kStandingD2,
        ];
      case AbTestAssignment.testFour:
        return const <TestCondition>[
          kWalkingD2,
          kStandingD1,
          kStandingD2,
          kWalkingD1,
        ];
    }
  }

  List<Duration> get dwellSequence {
    return phaseSequence
        .map((condition) => condition.dwellDuration)
        .toList(growable: false);
  }

  String get summary {
    return phaseSequence
        .map(
          (condition) =>
              '${condition.mobility.title} ${condition.dwellProfile.label}',
        )
        .join(' -> ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'conditionSequence': phaseSequence
          .map((condition) => condition.toJson())
          .toList(growable: false),
    };
  }
}
