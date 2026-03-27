import 'dart:convert';
import 'dart:io';

import 'package:eval/eval.dart';

Future<void> main() async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'] ?? '';
  await eval(
    'JSON Generation Test',
    (apiService) async {
      final resp = await apiService.sendRequest(
        'Give me a json object that returns a key value pair with "message" and "Hello, World!"',
        systemPrompt:
            'Your job is to only produce a JSON object. No other description or explanation or anything. And no ```json or ``` blocks. Just the pure JSON object.',
      );
      final json = jsonDecode(resp);
      print(json);
      expect(json, isA<Map<String, dynamic>>());
      expect(json['message'], 'Hello, World!');
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
    numberOfRunsPerLLM: 3,
    verbose: true,
  );
}
