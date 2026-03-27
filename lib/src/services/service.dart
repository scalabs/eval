import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Base exception for API call errors.
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? context;

  ApiException(this.message, {this.statusCode, this.context});

  @override
  String toString() => '${runtimeType.toString()}: $message';
}

/// Thrown when hitting API rate limits (HTTP 429).
class ApiRateLimitException extends ApiException {
  ApiRateLimitException(super.message, {super.context})
    : super(statusCode: 429);
}

/// Thrown when the server is overloaded (HTTP 529).
class ApiServerOverloadException extends ApiException {
  ApiServerOverloadException(super.message, {super.context})
    : super(statusCode: 529);
}

/// Thrown when authentication fails (HTTP 401).
class ApiUnauthorizedException extends ApiException {
  ApiUnauthorizedException(super.message, {super.context})
    : super(statusCode: 401);
}

/// Thrown for general HTTP errors.
class ApiHttpException extends ApiException {
  ApiHttpException(super.message, int statusCode, {super.context})
    : super(statusCode: statusCode);
}

typedef LLMCallback = Future<String> Function();
typedef DelayedLLMCallbackRecord = ({Duration delay, LLMCallback callback});

class APICallQueue {
  final Map<String, Future<void>> queues = {};

  Future<String> addCallByType<E>(
    LLMCallback callback,
    Duration timeout,
  ) async {
    final key = E.toString();
    final previous = queues[key];
    if (previous == null) {
      throw Exception('No call queue was registered for service $key');
    }
    final result = previous
        .then((_) => Future<void>.delayed(timeout))
        .then((_) => callback());

    // Swallow errors in the internal chain so one failed request does not
    // poison the queue for all future requests of the same service type.
    queues[key] = result.then<void>((_) {}).catchError((_) {});
    return result;
  }

  Future<void> registerCallQueue<E>() async {
    final key = E.toString();
    if (queues[key] != null) return;
    queues[key] = Future.value();
  }
}

final queue = APICallQueue();

abstract class APICallService<E extends Enum> {
  final String baseUrl;
  final String apiKey;
  final E defaultModel;
  final Duration timeout;
  MessageHistoryStore? store;

  APICallService({
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModel,

    /// timeout to respect api call limit
    required this.timeout,
    required bool stateful,
  }) {
    if (timeout != Duration.zero) {
      queue.registerCallQueue<E>();
    }
    if (stateful) {
      store = MessageHistoryStore();
    }
  }

  Future<String> sendRequest(
    String prompt, {
    String? systemPrompt,
    E? modelName,
  }) async {
    callback() => apiCallImpl(prompt, systemPrompt, modelName ?? defaultModel);

    if (timeout != Duration.zero) {
      return queue.addCallByType<E>(callback, timeout);
    }

    return callback();
  }

  Future<String> sendRequestWithImage(
    String prompt,
    Uint8List imageBytes, {
    String? systemPrompt,
    E? modelName,
  }) async {
    callback() => apiCallImpl(
      prompt,
      systemPrompt,
      modelName ?? defaultModel,
      imageBytes: imageBytes,
    );

    if (timeout != Duration.zero) {
      return queue.addCallByType<E>(callback, timeout);
    }

    return callback();
  }

  Future<String> sendRequestWithFile(
    String prompt,
    Uint8List fileBytes, {
    String? systemPrompt,
    E? modelName,
  }) async {
    callback() => apiCallImpl(
      prompt,
      systemPrompt,
      modelName ?? defaultModel,
      fileBytes: fileBytes,
    );

    if (timeout != Duration.zero) {
      return queue.addCallByType<E>(callback, timeout);
    }

    return callback();
  }

  Future<String> apiCallImpl(
    String prompt,
    String? systemPrompt,
    E modelName, {
    Uint8List? imageBytes,
    Uint8List? fileBytes,
  }) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final modelId = (modelName as dynamic).modelId;

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode({
        'model': modelId,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt ?? 'You are a helpful assistant.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['choices'][0]['message']['content'];
    } else if (response.statusCode == 429) {
      throw ApiRateLimitException('API rate limit exceeded: ${response.body}');
    } else if (response.statusCode == 529) {
      throw ApiServerOverloadException(
        'API server overloaded: ${response.body}',
      );
    } else if (response.statusCode == 401) {
      throw ApiUnauthorizedException(
        'API authentication failed: ${response.body}',
      );
    } else {
      print('Request failed: ${response.body}');
      throw ApiHttpException(
        'Request failed: ${response.body}',
        response.statusCode,
      );
    }
  }
}

class Message {
  final bool user;
  final String content;

  Message({required this.user, required this.content});
}

class MessageHistoryStore {
  final List<Message> messages = [];
  void addUserMessage(String message) {
    messages.add(Message(user: true, content: message));
  }

  void addAssistantMessage(String message) {
    messages.add(Message(user: false, content: message));
  }

  List<Map<String, dynamic>> get messageHistory => messages
      .map(
        (message) => {
          'role': message.user ? 'user' : 'assistant',
          'content': message.content,
        },
      )
      .toList();
}
