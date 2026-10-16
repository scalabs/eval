import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'service.dart';

/// A question about a shared state. The wire names follow the Decisions API.
sealed class DecisionQuestion {
  DecisionQuestion(this.instructions) {
    if (instructions.trim().isEmpty) {
      throw ArgumentError.value(
        instructions,
        'instructions',
        'cannot be empty',
      );
    }
  }
  final String instructions;
  String get type;
  Map<String, Object?> toJson();
}

final class NoulQuestion extends DecisionQuestion {
  NoulQuestion({required String instructions, Map<String, String>? criteria})
    : criteria = criteria == null ? null : Map.unmodifiable(criteria),
      super(instructions) {
    if (criteria != null &&
        (criteria.isEmpty ||
            criteria.keys.any((key) => key != 'true' && key != 'false') ||
            criteria.values.any((value) => value.trim().isEmpty))) {
      throw ArgumentError.value(
        criteria,
        'criteria',
        'use true/false descriptions',
      );
    }
  }
  final Map<String, String>? criteria;
  @override
  String get type => 'noul';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'instructions': instructions,
    if (criteria != null) 'criteria': criteria,
  };
}

final class ChoiceQuestion extends DecisionQuestion {
  ChoiceQuestion({
    required String instructions,
    required Map<String, String> criteria,
  }) : criteria = Map.unmodifiable(criteria),
       super(instructions) {
    if (criteria.length < 2 ||
        criteria.length > 255 ||
        criteria.entries.any(
          (e) => e.key.trim().isEmpty || e.value.trim().isEmpty,
        )) {
      throw ArgumentError.value(
        criteria,
        'criteria',
        'provide 2–255 named options',
      );
    }
  }
  final Map<String, String> criteria;
  @override
  String get type => 'choice';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'instructions': instructions,
    'criteria': criteria,
  };
}

final class ScoreQuestion extends DecisionQuestion {
  ScoreQuestion({required String instructions, required List<String> criteria})
    : criteria = List.unmodifiable(criteria),
      super(instructions) {
    if (criteria.length < 2 ||
        criteria.length > 10 ||
        criteria.any((value) => value.trim().isEmpty)) {
      throw ArgumentError.value(
        criteria,
        'criteria',
        'provide 2–10 ordered levels',
      );
    }
  }
  final List<String> criteria;
  @override
  String get type => 'score';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'instructions': instructions,
    'criteria': criteria,
  };
}

/// Text or JSON state and questions; model selection belongs to the service.
final class DecisionRequest {
  DecisionRequest({
    required Object state,
    required Map<String, DecisionQuestion> questions,
  }) : questions = Map.unmodifiable(questions),
       _stateJson = jsonEncode(state) {
    if (state is! String && state is! Map && state is! List) {
      throw ArgumentError.value(
        state,
        'state',
        'expected text, object, or array',
      );
    }
    if (questions.isEmpty || questions.keys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('Provide at least one question with a nonempty ID');
    }
  }
  final String _stateJson;
  Object get state => jsonDecode(_stateJson) as Object;
  final Map<String, DecisionQuestion> questions;
  Map<String, Object?> toJson({required String model}) => {
    'model': model,
    'state': state,
    'questions': questions.map(
      (key, question) => MapEntry(key, question.toJson()),
    ),
  };
}

sealed class DecisionAnswer {
  const DecisionAnswer();
  String get type;
}

final class NoulAnswer extends DecisionAnswer {
  const NoulAnswer(this.probability);

  /// Probability that the proposition is true, not a boolean decision.
  final double probability;
  @override
  String get type => 'noul';
}

final class ChoiceAnswer extends DecisionAnswer {
  const ChoiceAnswer({
    required this.choice,
    this.probabilities,
    this.confidence,
  });
  final String choice;
  final Map<String, double>? probabilities;

  /// Confidence is not necessarily the selected option's probability.
  final double? confidence;
  @override
  String get type => 'choice';
}

final class ScoreAnswer extends DecisionAnswer {
  const ScoreAnswer({
    required this.score,
    this.probabilities,
    this.confidence,
    this.legend,
  });
  final double score;
  final Map<String, double>? probabilities;
  final double? confidence;
  final Map<String, String>? legend;
  @override
  String get type => 'score';
}

final class DecisionUsage {
  const DecisionUsage({this.inputTokens, this.outputTokens, this.cost});
  final int? inputTokens;
  final int? outputTokens;

  /// Missing usage cost is unknown, never assumed to be free.
  final double? cost;
}

class ApiInvalidDecisionResponseException extends ApiException {
  ApiInvalidDecisionResponseException(super.message, {super.context});
}

final class DecisionResponse {
  DecisionResponse._({
    required this.answers,
    required this.model,
    required this.usage,
    required this.raw,
    this.id,
    this.provider,
  });
  final Map<String, DecisionAnswer> answers;
  final String model;
  final String? id;
  final String? provider;
  final DecisionUsage usage;
  final Map<String, dynamic> raw;

  factory DecisionResponse.fromJson(
    Map<String, dynamic> json, {
    required DecisionRequest request,
  }) {
    try {
      final model = _string(json['model']);
      final answerJson = _object(json['answers']);
      if (!_sameKeys(answerJson.keys, request.questions.keys)) {
        throw const FormatException(
          'Answer IDs do not match requested questions',
        );
      }
      final answers = <String, DecisionAnswer>{};
      for (final entry in request.questions.entries) {
        final answer = _object(answerJson[entry.key]);
        final question = entry.value;
        if (answer['type'] != question.type) {
          throw FormatException('Wrong answer type for ${entry.key}');
        }
        final confidence = answer['confidence'] == null
            ? null
            : _probability(answer['confidence']);
        switch (question) {
          case NoulQuestion():
            answers[entry.key] = NoulAnswer(_probability(answer['noul']));
          case ChoiceQuestion():
            final choice = _string(answer['choice']);
            if (!question.criteria.containsKey(choice)) {
              throw const FormatException('Unknown choice');
            }
            answers[entry.key] = ChoiceAnswer(
              choice: choice,
              confidence: confidence,
              probabilities: _probabilities(
                answer['probabilities'],
                question.criteria.keys,
              ),
            );
          case ScoreQuestion():
            final score = _number(answer['score']);
            if (score < 0 || score > question.criteria.length - 1) {
              throw const FormatException('Score outside rubric');
            }
            final keys = List.generate(question.criteria.length, (i) => '$i');
            Map<String, String>? legend;
            if (answer['legend'] != null) {
              legend = _object(
                answer['legend'],
              ).map((k, v) => MapEntry(k, _string(v)));
              if (!_sameKeys(legend.keys, keys) ||
                  keys.any(
                    (k) => legend![k] != question.criteria[int.parse(k)],
                  )) {
                throw const FormatException('Legend does not match rubric');
              }
            }
            answers[entry.key] = ScoreAnswer(
              score: score,
              confidence: confidence,
              probabilities: _probabilities(answer['probabilities'], keys),
              legend: legend == null ? null : Map.unmodifiable(legend),
            );
        }
      }
      final usage = _object(json['usage']);
      final cost = usage['cost'] == null ? null : _number(usage['cost']);
      if (cost != null && cost < 0) {
        throw const FormatException('Negative cost');
      }
      return DecisionResponse._(
        answers: Map.unmodifiable(answers),
        model: model,
        id: json['id'] == null ? null : _string(json['id']),
        provider: json['provider'] == null ? null : _string(json['provider']),
        usage: DecisionUsage(
          inputTokens: _tokens(usage['input_tokens']),
          outputTokens: _tokens(usage['output_tokens']),
          cost: cost,
        ),
        raw: Map.unmodifiable(json),
      );
    } on FormatException catch (error) {
      throw ApiInvalidDecisionResponseException(
        error.message,
        context: {'response': json},
      );
    }
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

String _string(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Expected nonempty string');
  }
  return value;
}

double _number(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Expected finite number');
  }
  return value.toDouble();
}

double _probability(Object? value) {
  final result = _number(value);
  if (result < 0 || result > 1) {
    throw const FormatException('Probability outside [0, 1]');
  }
  return result;
}

int? _tokens(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0) {
    throw const FormatException('Invalid token count');
  }
  return value;
}

bool _sameKeys(Iterable<String> a, Iterable<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);
Map<String, double>? _probabilities(Object? value, Iterable<String> keys) {
  if (value == null) return null;
  final result = _object(value).map((k, v) => MapEntry(k, _probability(v)));
  if (!_sameKeys(result.keys, keys) ||
      (result.values.fold(0.0, (a, b) => a + b) - 1).abs() > 0.001) {
    throw const FormatException('Invalid probability distribution');
  }
  return Map.unmodifiable(result);
}

/// Reusable Decisions transport. Subclasses own provider/model choices.
///
/// Requests are stateless. No chat messages, retries, fallback models, or
/// application-specific probability thresholds are added by this service.
abstract class DecisionModelService<E extends Enum> {
  DecisionModelService({
    required this.baseUrl,
    required this.apiKey,
    required this.defaultModel,
    this.rateLimitDelay = Duration.zero,
    this.requestTimeout = const Duration(seconds: 60),
    http.Client? client,
  }) : _client = client {
    if (requestTimeout <= Duration.zero || rateLimitDelay < Duration.zero) {
      throw ArgumentError(
        'Timeout must be positive and rate limit delay nonnegative',
      );
    }
    queue.registerCallQueue<E>();
  }
  final String baseUrl;
  final String apiKey;
  final E defaultModel;
  final Duration rateLimitDelay;
  final Duration requestTimeout;

  /// An injected client remains owned by its caller.
  final http.Client? _client;
  String modelId(E model);

  Future<DecisionResponse> decide(DecisionRequest request, {E? modelName}) {
    final selected = modelName ?? defaultModel;
    final id = modelId(selected);
    if (id.trim().isEmpty) throw ArgumentError('Model ID cannot be empty');
    final body = jsonEncode(request.toJson(model: id));
    Future<DecisionResponse> call() => _send(body, request);
    return rateLimitDelay == Duration.zero
        ? call()
        : queue.addTypedCallByType<E, DecisionResponse>(call, rateLimitDelay);
  }

  Future<DecisionResponse> _send(String body, DecisionRequest request) async {
    final client = _client ?? http.Client();
    final abort = Completer<void>();
    final message =
        http.AbortableRequest(
            'POST',
            Uri.parse(baseUrl),
            abortTrigger: abort.future,
          )
          ..headers.addAll({
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          })
          ..body = body;
    try {
      final response = await client
          .send(message)
          .then(http.Response.fromStream)
          .timeout(
            requestTimeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException(
                'Decision request timed out',
                requestTimeout,
              );
            },
          );
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode != 200) {
        final context = <String, dynamic>{'body': responseBody};
        switch (response.statusCode) {
          case 429:
            throw ApiRateLimitException(
              'Decision API rate limited',
              context: context,
            );
          case 529:
            throw ApiServerOverloadException(
              'Decision API overloaded',
              context: context,
            );
          case 401:
            throw ApiUnauthorizedException(
              'Decision API authentication failed',
              context: context,
            );
          default:
            throw ApiHttpException(
              'Decision API request failed',
              response.statusCode,
              context: context,
            );
        }
      }
      try {
        return DecisionResponse.fromJson(
          _object(jsonDecode(responseBody)),
          request: request,
        );
      } on FormatException catch (error) {
        throw ApiInvalidDecisionResponseException(
          error.message,
          context: {'body': responseBody},
        );
      }
    } finally {
      if (_client == null) client.close();
    }
  }
}
