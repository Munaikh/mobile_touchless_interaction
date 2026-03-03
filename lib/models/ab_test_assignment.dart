enum AbTestAssignment { testOne, testTwo }

extension AbTestAssignmentX on AbTestAssignment {
  String get id {
    switch (this) {
      case AbTestAssignment.testOne:
        return 'test_one';
      case AbTestAssignment.testTwo:
        return 'test_two';
    }
  }

  String get title {
    switch (this) {
      case AbTestAssignment.testOne:
        return 'Test One';
      case AbTestAssignment.testTwo:
        return 'Test Two';
    }
  }

  List<Duration> get dwellSequence {
    switch (this) {
      case AbTestAssignment.testOne:
        return const <Duration>[Duration(seconds: 2), Duration(seconds: 1)];
      case AbTestAssignment.testTwo:
        return const <Duration>[Duration(seconds: 1), Duration(seconds: 2)];
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'dwellSequenceSeconds': dwellSequence
          .map((duration) => duration.inMilliseconds / 1000)
          .toList(growable: false),
    };
  }
}
