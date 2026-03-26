import 'dart:convert';
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
      // Extract JSON from response if it contains extra text
      final jsonRegex = RegExp(r'\{[^{}]*\}');
      final match = jsonRegex.firstMatch(resp);
      if (match == null) {
        throw FormatException('No JSON object found in response: $resp');
      }
      final jsonStr = match.group(0)!;
      final json = jsonDecode(jsonStr);
      print(json);
      expect(json, isA<Map<String, dynamic>>());
      expect(json['message'], 'Hello, World!');
    },
    apiServices: [
      OpenrouterService(
        defaultModel: OpenrouterModel.haiku45,
        apiKey: apiKey,
      ),
      /* OpenrouterService(
        defaultModel: OpenrouterModel.zai,
        apiKey: apiKey,
      ), */
    ],
    numberOfRunsPerLLM: 3,
    verbose: true,
  );
}
