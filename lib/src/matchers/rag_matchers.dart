import 'dart:convert';

import 'package:eval/src/services/service.dart';
import 'package:matcher/matcher.dart';

import 'llm_matchers.dart';

/// Detailed result from a RAG evaluation, including individual metric scores.
class RagEvalResult {
  /// The overall combined score.
  final double score;

  /// Context precision score (proportion of relevant contexts).
  final double? contextPrecision;

  /// Context recall score (coverage of ground truth claims).
  final double? contextRecall;

  /// Answer groundedness score (faithfulness to contexts).
  final double? answerGroundedness;

  /// Answer relevancy score (relevance to query).
  final double? answerRelevancy;

  /// Indices of contexts that were deemed relevant (0-indexed).
  final List<int>? relevantContextIndices;

  /// Claims from the answer that are not supported by contexts.
  final List<String>? unsupportedClaims;

  /// Human-readable explanation of the evaluation.
  final String? reason;

  const RagEvalResult({
    required this.score,
    this.contextPrecision,
    this.contextRecall,
    this.answerGroundedness,
    this.answerRelevancy,
    this.relevantContextIndices,
    this.unsupportedClaims,
    this.reason,
  });

  @override
  String toString() {
    final parts = <String>['score: ${score.toStringAsFixed(2)}'];
    if (contextPrecision != null) {
      parts.add('precision: ${contextPrecision!.toStringAsFixed(2)}');
    }
    if (contextRecall != null) {
      parts.add('recall: ${contextRecall!.toStringAsFixed(2)}');
    }
    if (answerGroundedness != null) {
      parts.add('groundedness: ${answerGroundedness!.toStringAsFixed(2)}');
    }
    if (answerRelevancy != null) {
      parts.add('relevancy: ${answerRelevancy!.toStringAsFixed(2)}');
    }
    return 'RagEvalResult(${parts.join(', ')})';
  }
}

/// Evaluates RAG metrics and returns detailed results.
///
/// Unlike the matcher functions which only return pass/fail, this function
/// returns a [RagEvalResult] with individual scores for each metric.
///
/// Example:
/// ```dart
/// final result = await evaluateRag(
///   answer: generatedAnswer,
///   contexts: retrievedDocuments,
///   query: 'What is the capital of France?',
///   groundTruth: 'Paris is the capital of France.',
///   apiService: myApiService,
/// );
/// print('Precision: ${result.contextPrecision}');
/// print('Groundedness: ${result.answerGroundedness}');
/// ```
Future<RagEvalResult> evaluateRag({
  required String answer,
  required List<String> contexts,
  required String query,
  String? groundTruth,
  Map<String, double>? weights,
  required APICallService apiService,
}) async {
  // Default weights
  final w = weights ?? {};
  final precisionWeight = w['precision'] ?? 1.0;
  final recallWeight = w['recall'] ?? 1.0;
  final groundednessWeight = w['groundedness'] ?? 1.0;
  final relevancyWeight = w['relevancy'] ?? 1.0;

  final precisionMatcher = _ContextPrecision(contexts, query, 0, apiService);
  final groundednessMatcher = _AnswerGroundedness(contexts, 0, apiService);
  final relevancyMatcher = _AnswerRelevancy(query, 0, apiService);
  final precisionFuture = precisionMatcher.evaluateDetailed(answer);
  final groundednessFuture = groundednessMatcher.evaluateDetailed(answer);
  final relevancyFuture = relevancyMatcher.evaluateDetailed(answer);
  final recallFuture = groundTruth == null
      ? null
      : _ContextRecall(
          contexts,
          groundTruth,
          0,
          apiService,
        ).evaluateDetailed(answer);

  final precisionResult = await precisionFuture;
  final groundednessResult = await groundednessFuture;
  final relevancyResult = await relevancyFuture;
  final recallResult = recallFuture == null ? null : await recallFuture;

  final precisionScore = precisionResult.score;
  final groundednessScore = groundednessResult.score;
  final relevancyScore = relevancyResult.score;
  final recallScore = recallResult?.score;

  // Calculate weighted average
  var weightedSum =
      precisionScore * precisionWeight +
      groundednessScore * groundednessWeight +
      relevancyScore * relevancyWeight;
  var totalWeight = precisionWeight + groundednessWeight + relevancyWeight;

  if (recallScore != null) {
    weightedSum += recallScore * recallWeight;
    totalWeight += recallWeight;
  }

  final overallScore = totalWeight > 0 ? weightedSum / totalWeight : 0.0;

  return RagEvalResult(
    score: overallScore,
    contextPrecision: precisionScore,
    contextRecall: recallScore,
    answerGroundedness: groundednessScore,
    answerRelevancy: relevancyScore,
    relevantContextIndices: precisionResult.relevantContextIndices,
    unsupportedClaims: groundednessResult.unsupportedClaims,
    reason: _joinReasons({
      'precision': precisionResult.reason,
      'recall': recallResult?.reason,
      'groundedness': groundednessResult.reason,
      'relevancy': relevancyResult.reason,
    }),
  );
}

/// Measures the precision of retrieved contexts - what proportion are relevant.
///
/// This evaluates whether the retrieved contexts are actually useful for
/// answering the query. Higher precision means less irrelevant context.
///
/// Example:
/// ```dart
/// // Inside eval(...):
/// await expectAsync(answer, contextPrecision(
///   contexts: retrievedDocuments,
///   query: 'What is the capital of France?',
///   apiService: apiService,
/// ));
/// ```
AsyncLlmMatcher contextPrecision({
  required List<String> contexts,
  required String query,
  double threshold = 0.7,
  APICallService? apiService,
}) => _ContextPrecision(contexts, query, threshold, apiService);

/// Measures the recall of retrieved contexts - whether all relevant info was retrieved.
///
/// This evaluates whether the contexts contain all the information needed
/// to answer the query based on ground truth. Higher recall means less missed info.
///
/// Example:
/// ```dart
/// // Inside eval(...):
/// await expectAsync(answer, contextRecall(
///   contexts: retrievedDocuments,
///   groundTruth: 'Paris is the capital of France.',
///   apiService: apiService,
/// ));
/// ```
AsyncLlmMatcher contextRecall({
  required List<String> contexts,
  required String groundTruth,
  double threshold = 0.7,
  APICallService? apiService,
}) => _ContextRecall(contexts, groundTruth, threshold, apiService);

/// Measures whether the answer is grounded in the provided contexts.
///
/// This evaluates faithfulness - whether the answer is derived from the
/// contexts without hallucination. Low groundedness indicates the answer
/// contains information not supported by the contexts.
///
/// Example:
/// ```dart
/// // Inside eval(...):
/// await expectAsync(answer, answerGroundedness(
///   contexts: retrievedDocuments,
///   apiService: apiService,
/// ));
/// ```
AsyncLlmMatcher answerGroundedness({
  required List<String> contexts,
  double threshold = 0.8,
  APICallService? apiService,
}) => _AnswerGroundedness(contexts, threshold, apiService);

/// Measures whether the answer is relevant to the query.
///
/// This evaluates whether the generated answer actually addresses
/// the user's question, regardless of correctness.
///
/// Example:
/// ```dart
/// // Inside eval(...):
/// await expectAsync(answer, answerRelevancy(
///   query: 'What is the capital of France?',
///   apiService: apiService,
/// ));
/// ```
AsyncLlmMatcher answerRelevancy({
  required String query,
  double threshold = 0.7,
  APICallService? apiService,
}) => _AnswerRelevancy(query, threshold, apiService);

/// Measures the factual correctness of an answer against ground truth.
///
/// This evaluates whether the answer contains the same facts as the
/// ground truth, regardless of phrasing. Unlike groundedness which checks
/// if the answer is supported by contexts, correctness checks if the
/// answer matches the expected facts.
///
/// Example:
/// ```dart
/// // Inside eval(...):
/// await expectAsync(answer, answerCorrectness(
///   groundTruth: 'Paris is the capital of France.',
///   apiService: apiService,
/// ));
/// ```
AsyncLlmMatcher answerCorrectness({
  required String groundTruth,
  double threshold = 0.7,
  APICallService? apiService,
}) => _AnswerCorrectness(groundTruth, threshold, apiService);

/// Computes a combined RAG score from multiple metrics.
///
/// This provides a single score that combines:
/// - Context precision (are retrieved contexts relevant?)
/// - Context recall (is all needed info retrieved?)
/// - Answer groundedness (is answer faithful to contexts?)
/// - Answer relevancy (does answer address the query?)
///
/// Optionally, you can provide custom [weights] to adjust the importance
/// of each metric. Keys are: 'precision', 'recall', 'groundedness', 'relevancy'.
/// Default weights are all 1.0 (equal weighting).
///
/// Example:
/// ```dart
/// // Inside eval(...):
/// await expectAsync(answer, ragScore(
///   contexts: retrievedDocuments,
///   query: 'What is the capital of France?',
///   groundTruth: 'Paris is the capital of France.',
///   weights: {'groundedness': 2.0, 'precision': 1.0}, // prioritize groundedness
///   apiService: apiService,
/// ));
/// ```
AsyncLlmMatcher ragScore({
  required List<String> contexts,
  required String query,
  String? groundTruth,
  double threshold = 0.7,
  Map<String, double>? weights,
  APICallService? apiService,
}) => _RagScore(contexts, query, groundTruth, threshold, weights, apiService);

class _ContextPrecision extends AsyncLlmMatcher {
  final List<String> contexts;
  final String query;
  @override
  final double threshold;

  const _ContextPrecision(
    this.contexts,
    this.query,
    this.threshold,
    super.apiService,
  );

  Future<_RagJudgeResponse> evaluateDetailed(String item) async {
    if (contexts.isEmpty) return const _RagJudgeResponse(score: 0.0);

    final contextList = contexts
        .asMap()
        .entries
        .map((e) => 'Context ${e.key + 1}: "${e.value}"')
        .join('\n\n');

    final prompt =
        '''
Evaluate the precision of the retrieved contexts for answering the query.
Precision measures what proportion of the contexts are actually relevant and useful.

Query: "$query"

Retrieved Contexts:
$contextList

For each context, determine if it is relevant to answering the query.
Then calculate precision as: (number of relevant contexts) / (total contexts)

Return ONLY a JSON object with the format:
{
  "score": 0.X,
  "relevant_contexts": [1, 3],
  "reason": "brief explanation"
}
''';

    final response = await service.sendRequest(
      prompt,
      systemPrompt:
          'You are a RAG evaluation expert. Evaluate context precision. Return only valid JSON.',
    );

    return _parseRagJudgeResponse(response);
  }

  @override
  Future<double> evaluateAsync(String item) async {
    return (await evaluateDetailed(item)).score;
  }

  @override
  Description describe(Description description) =>
      description.add('context precision >= $threshold for query "$query"');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    return mismatchDescription.add(
      'must be evaluated asynchronously; use await expectAsync(actual, matcher)',
    );
  }
}

class _ContextRecall extends AsyncLlmMatcher {
  final List<String> contexts;
  final String groundTruth;
  @override
  final double threshold;

  const _ContextRecall(
    this.contexts,
    this.groundTruth,
    this.threshold,
    super.apiService,
  );

  Future<_RagJudgeResponse> evaluateDetailed(String item) async {
    if (contexts.isEmpty) return const _RagJudgeResponse(score: 0.0);

    final contextList = contexts
        .asMap()
        .entries
        .map((e) => 'Context ${e.key + 1}: "${e.value}"')
        .join('\n\n');

    final prompt =
        '''
Evaluate the recall of the retrieved contexts against the ground truth.
Recall measures whether all information needed to produce the ground truth answer is present in the contexts.

Ground Truth Answer: "$groundTruth"

Retrieved Contexts:
$contextList

Break down the ground truth into key claims/facts and check if each is supported by the contexts.
Calculate recall as: (number of supported claims) / (total claims in ground truth)

Return ONLY a JSON object with the format:
{
  "score": 0.X,
  "claims": ["claim1", "claim2"],
  "supported_claims": ["claim1"],
  "reason": "brief explanation"
}
''';

    final response = await service.sendRequest(
      prompt,
      systemPrompt:
          'You are a RAG evaluation expert. Evaluate context recall. Return only valid JSON.',
    );

    return _parseRagJudgeResponse(response);
  }

  @override
  Future<double> evaluateAsync(String item) async {
    return (await evaluateDetailed(item)).score;
  }

  @override
  Description describe(Description description) =>
      description.add('context recall >= $threshold');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    return mismatchDescription.add(
      'must be evaluated asynchronously; use await expectAsync(actual, matcher)',
    );
  }
}

class _AnswerGroundedness extends AsyncLlmMatcher {
  final List<String> contexts;
  @override
  final double threshold;

  const _AnswerGroundedness(this.contexts, this.threshold, super.apiService);

  Future<_RagJudgeResponse> evaluateDetailed(String item) async {
    if (contexts.isEmpty) return const _RagJudgeResponse(score: 0.0);

    final contextList = contexts
        .asMap()
        .entries
        .map((e) => 'Context ${e.key + 1}: "${e.value}"')
        .join('\n\n');

    final prompt =
        '''
Evaluate the groundedness of the answer in the provided contexts.
Groundedness measures whether every claim in the answer is supported by the contexts.
Low groundedness indicates hallucination - claims not supported by the contexts.

Answer: "$item"

Contexts:
$contextList

Break down the answer into individual claims and check if each is supported by the contexts.
Calculate groundedness as: (number of supported claims) / (total claims in answer)

Return ONLY a JSON object with the format:
{
  "score": 0.X,
  "claims": ["claim1", "claim2"],
  "unsupported_claims": ["claim2"],
  "reason": "brief explanation"
}
''';

    final response = await service.sendRequest(
      prompt,
      systemPrompt:
          'You are a RAG evaluation expert. Evaluate answer groundedness and detect hallucinations. Return only valid JSON.',
    );

    return _parseRagJudgeResponse(response);
  }

  @override
  Future<double> evaluateAsync(String item) async {
    return (await evaluateDetailed(item)).score;
  }

  @override
  Description describe(Description description) =>
      description.add('answer groundedness >= $threshold');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    return mismatchDescription.add(
      'must be evaluated asynchronously; use await expectAsync(actual, matcher)',
    );
  }
}

class _AnswerCorrectness extends AsyncLlmMatcher {
  final String groundTruth;
  @override
  final double threshold;

  const _AnswerCorrectness(this.groundTruth, this.threshold, super.apiService);

  Future<_RagJudgeResponse> evaluateDetailed(String item) async {
    final prompt =
        '''
Evaluate the factual correctness of the answer against the ground truth.
Correctness measures whether the answer contains the same facts as the ground truth.
Focus on factual accuracy, not phrasing or style.

Ground Truth: "$groundTruth"

Answer: "$item"

Break down both into key facts and compare:
- Does the answer contain the same key facts as the ground truth?
- Are there any factual errors or contradictions?
- Are there any missing key facts?

Score from 0.0 (completely incorrect, contradicts ground truth)
to 1.0 (fully correct, contains all key facts from ground truth).

Return ONLY a JSON object with the format:
{
  "score": 0.X,
  "matching_facts": ["fact1", "fact2"],
  "missing_facts": ["fact3"],
  "incorrect_facts": ["fact4"],
  "reason": "brief explanation"
}
''';

    final response = await service.sendRequest(
      prompt,
      systemPrompt:
          'You are a RAG evaluation expert. Evaluate answer correctness against ground truth. Return only valid JSON.',
    );

    return _parseRagJudgeResponse(response);
  }

  @override
  Future<double> evaluateAsync(String item) async {
    return (await evaluateDetailed(item)).score;
  }

  @override
  Description describe(Description description) =>
      description.add('answer correctness >= $threshold');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    return mismatchDescription.add(
      'must be evaluated asynchronously; use await expectAsync(actual, matcher)',
    );
  }
}

class _AnswerRelevancy extends AsyncLlmMatcher {
  final String query;
  @override
  final double threshold;

  const _AnswerRelevancy(this.query, this.threshold, super.apiService);

  Future<_RagJudgeResponse> evaluateDetailed(String item) async {
    final prompt =
        '''
Evaluate the relevancy of the answer to the query.
Relevancy measures whether the answer actually addresses what was asked.
An answer can be relevant even if incorrect, as long as it attempts to answer the question.

Query: "$query"

Answer: "$item"

Score from 0.0 (completely irrelevant, doesn't address the question at all)
to 1.0 (highly relevant, directly addresses the question).

Return ONLY a JSON object with the format:
{
  "score": 0.X,
  "reason": "brief explanation"
}
''';

    final response = await service.sendRequest(
      prompt,
      systemPrompt:
          'You are a RAG evaluation expert. Evaluate answer relevancy. Return only valid JSON.',
    );

    return _parseRagJudgeResponse(response);
  }

  @override
  Future<double> evaluateAsync(String item) async {
    return (await evaluateDetailed(item)).score;
  }

  @override
  Description describe(Description description) =>
      description.add('answer relevancy >= $threshold for query "$query"');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    return mismatchDescription.add(
      'must be evaluated asynchronously; use await expectAsync(actual, matcher)',
    );
  }
}

class _RagScore extends AsyncLlmMatcher {
  final List<String> contexts;
  final String query;
  final String? groundTruth;
  @override
  final double threshold;
  final Map<String, double>? weights;

  const _RagScore(
    this.contexts,
    this.query,
    this.groundTruth,
    this.threshold,
    this.weights,
    super.apiService,
  );

  @override
  Future<double> evaluateAsync(String item) async {
    // Default weights (all equal at 1.0)
    final w = weights ?? {};
    final precisionWeight = w['precision'] ?? 1.0;
    final recallWeight = w['recall'] ?? 1.0;
    final groundednessWeight = w['groundedness'] ?? 1.0;
    final relevancyWeight = w['relevancy'] ?? 1.0;

    // Run all evaluations in parallel for better performance
    final futures = <Future<double>>[];
    final futureWeights = <double>[];

    // Context precision
    futures.add(
      _ContextPrecision(contexts, query, 0, apiService).evaluateAsync(item),
    );
    futureWeights.add(precisionWeight);

    // Context recall (if ground truth provided)
    if (groundTruth != null) {
      futures.add(
        _ContextRecall(
          contexts,
          groundTruth!,
          0,
          apiService,
        ).evaluateAsync(item),
      );
      futureWeights.add(recallWeight);
    }

    // Answer groundedness
    futures.add(
      _AnswerGroundedness(contexts, 0, apiService).evaluateAsync(item),
    );
    futureWeights.add(groundednessWeight);

    // Answer relevancy
    futures.add(_AnswerRelevancy(query, 0, apiService).evaluateAsync(item));
    futureWeights.add(relevancyWeight);

    // Wait for all evaluations to complete
    final scores = await Future.wait(futures);

    // Return weighted average of all scores
    if (scores.isEmpty) return 0.0;

    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (var i = 0; i < scores.length; i++) {
      weightedSum += scores[i] * futureWeights[i];
      totalWeight += futureWeights[i];
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  @override
  Description describe(Description description) =>
      description.add('combined RAG score >= $threshold');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    return mismatchDescription.add(
      'must be evaluated asynchronously; use await expectAsync(actual, matcher)',
    );
  }
}

class _RagJudgeResponse {
  final double score;
  final String? reason;
  final List<int>? relevantContextIndices;
  final List<String>? unsupportedClaims;

  const _RagJudgeResponse({
    required this.score,
    this.reason,
    this.relevantContextIndices,
    this.unsupportedClaims,
  });
}

_RagJudgeResponse _parseRagJudgeResponse(String response) {
  try {
    final json = _decodeJudgeJson(response);
    final score = json['score'];
    if (score is num) {
      return _RagJudgeResponse(
        score: score.toDouble().clamp(0.0, 1.0),
        reason: json['reason'] as String?,
        relevantContextIndices: _coerceRelevantContextIndices(
          json['relevant_contexts'],
        ),
        unsupportedClaims: _coerceStringList(json['unsupported_claims']),
      );
    }
    throw FormatException('Score not found in response');
  } catch (e) {
    final numberMatch = RegExp(r'0?\.\d+|\d+\.?\d*').firstMatch(response);
    if (numberMatch != null) {
      final value = double.tryParse(numberMatch.group(0)!);
      if (value != null) {
        return _RagJudgeResponse(score: value.clamp(0.0, 1.0));
      }
    }
    throw FormatException('Could not parse score from LLM response: $response');
  }
}

Map<String, dynamic> _decodeJudgeJson(String response) {
  var jsonStr = response.trim();

  final jsonMatch = RegExp(
    r'```(?:json)?\s*([\s\S]*?)```',
  ).firstMatch(response);
  if (jsonMatch != null) {
    jsonStr = jsonMatch.group(1)!.trim();
  }

  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
    if (objectMatch != null) {
      final decoded = jsonDecode(objectMatch.group(0)!);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
  }

  throw FormatException('Could not decode judge JSON.');
}

List<int>? _coerceRelevantContextIndices(Object? value) {
  if (value is! List) return null;

  return value
      .map((entry) {
        if (entry is int) return entry > 0 ? entry - 1 : entry;
        if (entry is num) {
          final normalized = entry.toInt();
          return normalized > 0 ? normalized - 1 : normalized;
        }
        if (entry is String) {
          final parsed = int.tryParse(entry);
          if (parsed != null) {
            return parsed > 0 ? parsed - 1 : parsed;
          }
        }
        return null;
      })
      .whereType<int>()
      .toList();
}

List<String>? _coerceStringList(Object? value) {
  if (value is! List) return null;
  return value.map((entry) => entry.toString()).toList();
}

String? _joinReasons(Map<String, String?> reasons) {
  final parts = [
    for (final entry in reasons.entries)
      if (entry.value != null && entry.value!.trim().isNotEmpty)
        '${entry.key}: ${entry.value!.trim()}',
  ];

  return parts.isEmpty ? null : parts.join(' | ');
}
