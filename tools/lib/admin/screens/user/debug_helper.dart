// Fungsi ini untuk membantu debugging level yang sudah dijawab
import 'package:tools/admin/services/answer_service.dart';

Future<void> debugLevelAnswers(String userId, String levelId) async {
  try {
    final answerService = AnswerService();
    final answers = await answerService.getAllAnswers(userId, levelId);

    print('===== DEBUG LEVEL ANSWERS =====');
    print('Level ID: $levelId');
    print('Total jawaban: ${answers.length}');

    for (var answer in answers) {
      print(
        'Question ID: ${answer.questionId}, Answer: ${answer.answer}, Time: ${answer.timestamp}',
      );
    }

    final isCompleted = await answerService.isLevelCompleted(userId, levelId);
    print('Level completed? $isCompleted');
    print('==============================');
  } catch (e) {
    print('Error debugging level answers: $e');
  }
}
