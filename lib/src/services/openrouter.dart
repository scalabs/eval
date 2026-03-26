import 'dart:convert';
import 'dart:typed_data';

import 'package:eval/eval.dart';
import 'package:http/http.dart' as http;

enum OpenrouterModel {
  haiku45('anthropic/claude-haiku-4.5'),
  zai('z-ai/glm-4.5-20240919'),
  grok('x-ai/grok-4.20-multi-agent-beta'),
  nemotron('nvidia/nemotron-3-super-120b-a12b:free'),
  minimax('minimax/minimax-m2.5:free'),
  qwen3('qwen/qwen3-embedding-4b'),
  openai('openai/gpt-4.1');
  
  final String modelId;

  const OpenrouterModel(this.modelId);
}

const maxTokens = 4096;

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => 'RateLimitException: $message';
}

class ServerOverloadException implements Exception {
  final String message;
  ServerOverloadException(this.message);

  @override
  String toString() => 'ServerOverloadException: $message';
}

class OpenrouterService extends APICallService<OpenrouterModel> {
  OpenrouterService({
    super.stateful = false,
    super.timeout = Duration.zero,
    super.defaultModel = OpenrouterModel.haiku45,
    required super.apiKey,
  }) : super(baseUrl: 'https://openrouter.ai/api/v1/chat/completions');

  @override
  Future<String> apiCallImpl(
    String prompt,
    String? systemPrompt,
    OpenrouterModel modelName, {
    Uint8List? imageBytes,
    Uint8List? fileBytes,
  }) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
    };

    store?.addUserMessage(prompt);

    final body = jsonEncode({
      'model': modelName.modelId,
      'max_tokens': maxTokens,
      if (systemPrompt != null) 'system': systemPrompt,
      'messages': store?.messageHistory ??
          [
            {
              'role': 'user',
              'content': [
                if (imageBytes != null)
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': 'image/png',
                      'data': base64Encode(imageBytes),
                    },
                  },
                {'type': 'text', 'text': prompt},
              ],
            },
          ],
    });

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final rawContent = jsonResponse['choices'][0]['message']['content'] as String;
      return _stripMarkdown(rawContent);

      //return jsonResponse['choices'][0]['message']['content'];
    } else if (response.statusCode == 429) {
      throw RateLimitException('Claude API rate limit hit: ${response.body}');
    } else if (response.statusCode == 529) {
      throw ServerOverloadException(response.body);
    } else {
      throw Exception(
        'Request failed with status: ${response.statusCode} ${response.body}',
      );
    }
  }

  String _stripMarkdown(String text) {
    final exp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
    final match = exp.firstMatch(text);
  
    if (match != null) {
      return match.group(1)!.trim();
    }
    return text.trim();
  }
}
