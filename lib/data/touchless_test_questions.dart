import 'package:mobile_touchless_interaction/models/touchless_task_question.dart';

const List<TouchlessTaskQuestion> kTouchlessTestQuestions = [
  TouchlessTaskQuestion(prompt: 'Select the Call button', targetLabel: 'Call'),
  TouchlessTaskQuestion(
    prompt: 'Select the Camera button',
    targetLabel: 'Camera',
  ),
  TouchlessTaskQuestion(
    prompt: 'Select the Torch button',
    targetLabel: 'Torch',
  ),
];
