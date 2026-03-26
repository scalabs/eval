import 'dart:io';
import 'package:eval/eval.dart';
import 'package:eval/src/services/openrouter.dart';

void main() {
  final apiKey = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  eval(
    'JSON Generation Test',
    (apiService) async {
      final resp = await apiService.sendRequest(
        'Give me a json object that returns a key value pair with "message" and "Hello, World!"',
        systemPrompt:
            'Your job is to only produce a JSON object. No other description or explanation or anything. And no ```json or ``` blocks. Just the pure JSON object.',
      );

      expect(resp, isValidJson);
      expect(resp, isJsonObject);
      expect(resp, hasJsonPathValue('message', 'Hello, World!'));
    },
    apiServices: [
      OpenrouterService(defaultModel: OpenrouterModel.grok, apiKey: apiKey),
      OpenrouterService(defaultModel: OpenrouterModel.nemotron, apiKey: apiKey),
      OpenrouterService(defaultModel: OpenrouterModel.minimax, apiKey: apiKey),
      OpenrouterService(defaultModel: OpenrouterModel.qwen3, apiKey: apiKey),
      OpenrouterService(defaultModel: OpenrouterModel.openai, apiKey: apiKey),
    ],
    numberOfRunsPerLLM: 3,
    verbose: true,
  );
}
