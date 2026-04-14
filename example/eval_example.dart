import 'dart:io';

import 'package:eval/eval.dart';

Future<void> main() async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw StateError('Set ANTHROPIC_API_KEY before running this example.');
  }

  await eval(
    'answers geography questions',
    (apiService) async {
      final answer = await apiService.sendRequest(
        'Answer in one short sentence: What is the capital of France?',
      );

      expect(answer, containsIgnoreCase('paris'));
      expect(answer, sentenceCountBetween(1, 2));

      await expectAsync(
        answer,
        answersQuestion(
          'What is the capital of France?',
          apiService: apiService,
        ),
      );

      await expectAsync(answer, isNotToxic(apiService: apiService));
    },
    apiServices: [
      ExampleClaudeService(
        defaultModel: ExampleClaudeModel.haiku45,
        apiKey: apiKey,
      ),
      ExampleClaudeService(
        defaultModel: ExampleClaudeModel.sonnet45,
        apiKey: apiKey,
      ),
    ],
    numberOfRunsPerLLM: 2,
    verbose: true,
  );
}
