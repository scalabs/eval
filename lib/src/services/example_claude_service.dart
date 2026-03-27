import 'dart:convert';
import 'dart:typed_data';

import 'package:eval/eval.dart';
import 'package:http/http.dart' as http;

enum ExampleClaudeModel {
  sonnet35('claude-3-5-sonnet-latest'),
  sonnet4('claude-sonnet-4-20250514'),
  sonnet45('claude-sonnet-4-5-20250929'),
  haiku45('claude-haiku-4-5-20251001');

  final String modelId;

  const ExampleClaudeModel(this.modelId);
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

class ExampleClaudeService extends APICallService<ExampleClaudeModel> {
  ExampleClaudeService({
    super.stateful = false,
    super.timeout = Duration.zero,
    super.defaultModel = ExampleClaudeModel.sonnet45,
    required super.apiKey,
  }) : super(baseUrl: 'https://api.anthropic.com/v1/messages');

  @override
  Future<String> apiCallImpl(
    String prompt,
    String? systemPrompt,
    ExampleClaudeModel modelName, {
    Uint8List? imageBytes,
    Uint8List? fileBytes,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    };

    store?.addUserMessage(prompt);

    final requestBody = <String, dynamic>{
      'model': modelName.modelId,
      'max_tokens': maxTokens,
      'messages': [
        ...?store?.messageHistory,
        if (store == null)
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
    };
    if (systemPrompt != null) {
      requestBody['system'] = systemPrompt;
    }

    final body = jsonEncode(requestBody);

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final content = responseData['content'][0]['text'];
      store?.addAssistantMessage(content);
      return content;
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
}
