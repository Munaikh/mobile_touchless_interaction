import 'package:mobile_touchless_interaction/models/task_question.dart';

const List<String> kButtonLabels = <String>[
  'Call',
  'Music',
  'Map',
  'Camera',
  'Message',
  'Torch',
];

const List<TaskQuestion> kTestQuestions = <TaskQuestion>[
  TaskQuestion(prompt: 'Select the Call button', targetLabel: 'Call'),
  TaskQuestion(prompt: 'Select the Music button', targetLabel: 'Music'),
  TaskQuestion(prompt: 'Select the Map button', targetLabel: 'Map'),
  TaskQuestion(prompt: 'Select the Camera button', targetLabel: 'Camera'),
  TaskQuestion(prompt: 'Select the Message button', targetLabel: 'Message'),
  TaskQuestion(prompt: 'Select the Torch button', targetLabel: 'Torch'),
];

List<TaskQuestion> buildShuffledQuestionSet() {
  final shuffledQuestions = List<TaskQuestion>.of(kTestQuestions)..shuffle();
  return shuffledQuestions;
}
